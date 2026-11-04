import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/blocked_song_dao.dart';
import 'package:soundwave/core/database/playlist_dao.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/database/song_dao.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/player/providers/player_from_downloads_provider.dart';
import 'package:soundwave/features/search/data/commons_catalog_repository.dart';
import 'package:soundwave/features/player/data/playback_preferences_repository_impl.dart';
import 'package:soundwave/features/player/providers/player_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fake_repositories.dart';
import 'fake_playback_controller.dart';

class CompletedLibrary extends FakeDownloadRepository {
  @override
  Future<DownloadRecord?> findBySongId(String songId) async =>
      completedRecord(songId);
}

void main() {
  late FakePlaybackController engine;
  late FakePlaybackPreferencesRepository preferences;
  late ProviderContainer container;
  late PlayerControllerNotifier controller;

  setUp(() {
    engine = FakePlaybackController();
    preferences = FakePlaybackPreferencesRepository();
    container = ProviderContainer(
      overrides: [
        playbackEngineProvider.overrideWithValue(engine),
        playbackPreferencesProvider.overrideWith((_) async => preferences),
        playbackSourceProvider.overrideWithValue(
          (track) async =>
              Uri.file('/private/${track.localPath}', windows: false),
        ),
      ],
    );
    controller = container.read(playerControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  test(
    'abrir por ID prefiere archivo local antes del primer evento de descargas',
    () async {
      final offline = ProviderContainer(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          playbackEngineProvider.overrideWithValue(engine),
          playbackPreferencesProvider.overrideWith((_) async => preferences),
          commonsApiClientProvider.overrideWith(
            (_) => throw StateError('Sin red'),
          ),
          downloadSessionProvider.overrideWith(
            (_) async => DownloadSession(
              CompletedLibrary(),
              (_) async => testTracks.first.song,
              localAudioUri: (path) async =>
                  Uri.file('/private/$path', windows: false),
            ),
          ),
        ],
      );
      try {
        await offline
            .read(playerControllerProvider.notifier)
            .openById(testTracks.first.id);
        expect(
          offline.read(playerControllerProvider).currentTrack?.id,
          testTracks.first.id,
        );
        expect(offline.read(playerControllerProvider).error, isNull);
        expect(
          engine.loaded.single,
          Uri.file('/private/${testTracks.first.id}.audio', windows: false),
        );
        expect(engine.playing, isTrue);
      } finally {
        offline.dispose();
      }
    },
  );

  test(
    'la cola usa descargas completadas y libera una pista retirada',
    () async {
      final entries = StreamController<List<DownloadEntry>>();
      final library = ProviderContainer(
        overrides: [
          playbackEngineProvider.overrideWithValue(engine),
          playbackPreferencesProvider.overrideWith((_) async => preferences),
          playbackSourceProvider.overrideWithValue(
            (track) async =>
                Uri.file('/private/${track.localPath}', windows: false),
          ),
          downloadEntriesProvider.overrideWith((_) => entries.stream),
        ],
      );
      try {
        library.listen(playerFromDownloadsProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);
        final first = completedRecord(testTracks.first.id);
        final second = DownloadRecord.fromMap({
          ...completedRecord(testTracks.last.id).toMap(),
          'state': DownloadState.failed.name,
        });
        entries.add([
          DownloadEntry(first, testTracks.first.song),
          DownloadEntry(second, testTracks.last.song),
        ]);
        await library.read(downloadEntriesProvider.future);
        await Future<void>.delayed(Duration.zero);
        final notifier = library.read(playerControllerProvider.notifier);
        await notifier.play();
        expect(library.read(playerControllerProvider).tracks.map((t) => t.id), [
          testTracks.first.id,
        ]);
        entries.add([]);
        await Future<void>.delayed(Duration.zero);
        expect(library.read(playerControllerProvider).tracks, isEmpty);
        expect(engine.playing, isFalse);
      } finally {
        library.dispose();
        await entries.close();
      }
    },
  );

  test(
    'posición, duración y pausa vienen del motor; recargar no reinicia',
    () async {
      await controller.load(testTracks);
      await controller.play();
      engine.position = const Duration(seconds: 32);
      engine.emit();
      await controller.load(testTracks);
      final state = container.read(playerControllerProvider);
      expect(state.duration, const Duration(minutes: 4));
      expect(state.position, const Duration(seconds: 32));
      expect(state.isPlaying, isTrue);
      expect(engine.loaded, hasLength(1));
      await controller.pause();
      expect(container.read(playerControllerProvider).isPlaying, isFalse);
      await controller.seek(const Duration(hours: 1));
      expect(engine.position, const Duration(minutes: 4));
    },
  );

  test(
    'siguiente, anterior y fin real de pista mantienen el mismo estado',
    () async {
      await controller.load(testTracks);
      await controller.play();
      await controller.next();
      expect(controller.currentTrack?.id, testTracks[1].id);
      expect(engine.playing, isTrue);
      await controller.previous();
      expect(controller.currentTrack?.id, testTracks[0].id);
      engine.emit(completed: true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.currentTrack?.id, testTracks[1].id);
      engine.emit(completed: true);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(playerControllerProvider).isPlaying, isFalse);
    },
  );

  test('archivo ausente muestra error y permite reintentar', () async {
    await controller.load(testTracks);
    engine.failLoad = true;
    await controller.play();
    expect(
      container.read(playerControllerProvider).error,
      contains('ya no existe'),
    );
    expect(container.read(playerControllerProvider).isPlaying, isFalse);
    engine.failLoad = false;
    await controller.play();
    expect(container.read(playerControllerProvider).error, isNull);
    expect(engine.playing, isTrue);
  });

  test(
    'bloqueo avanza, desbloqueo persiste y última bloqueada detiene',
    () async {
      await controller.load(testTracks);
      await controller.play();
      await controller.setBlocked(testTracks.first.id, true);
      expect(controller.currentTrack?.id, testTracks.last.id);
      expect(await preferences.blockedSongIds('offline'), {
        testTracks.first.id,
      });
      await controller.setBlocked(testTracks.last.id, true);
      expect(engine.playing, isFalse);
      expect(container.read(playerControllerProvider).playableTracks, isEmpty);
      await controller.setBlocked(testTracks.first.id, false);
      await controller.select(testTracks.first.id);
      expect(engine.playing, isTrue);
      expect(await preferences.blockedSongIds('offline'), {testTracks.last.id});
    },
  );

  test('guarda espera liberación incluso si la pista está pausada', () async {
    await controller.load(testTracks);
    await controller.play();
    await controller.pause();
    engine.stopGate = Completer<void>();
    var released = false;
    final guard = controller
        .releaseForDeletion(testTracks.first.id)
        .then((value) => released = value);
    await Future<void>.delayed(Duration.zero);
    expect(released, isFalse);
    engine.stopGate!.complete();
    await guard;
    expect(released, isTrue);
    expect(container.read(playerControllerProvider).tracks.map((t) => t.id), [
      testTracks.last.id,
    ]);
  });

  test(
    'carga en curso no puede reabrir una pista después de liberarla',
    () async {
      await controller.load(testTracks);
      engine.loadGate = Completer<void>();
      final play = controller.play();
      await Future<void>.delayed(Duration.zero);
      final deletion = controller.releaseForDeletion(testTracks.first.id);
      engine.loadGate!.complete();
      await play;
      expect(await deletion, isTrue);
      expect(engine.playing, isFalse);
      expect(controller.currentTrack?.id, testTracks.last.id);
    },
  );

  test('SQLite y controlador recuperan bloqueos al reabrir la base', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'soundwave-blocks-',
    );
    final path = '${directory.path}/test.db';
    Future<Database> open() => databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createDatabaseSchema(db),
      ),
    );
    var db = await open();
    try {
      await PlaylistDao(db).ensureOfflineCollection();
      for (var i = 0; i < testTracks.length; i++) {
        await SongDao(db).upsert(testTracks[i].song);
        await PlaylistDao(
          db,
        ).addSong(playlistId: 'offline', songId: testTracks[i].id, position: i);
      }
      await SqlitePlaybackPreferencesRepository(BlockedSongDao(db)).setBlocked(
        collectionId: 'offline',
        songId: testTracks.first.id,
        blocked: true,
      );
      await db.close();
      db = await open();
      final repository = SqlitePlaybackPreferencesRepository(
        BlockedSongDao(db),
      );
      final restarted = ProviderContainer(
        overrides: [
          playbackPreferencesProvider.overrideWith((_) async => repository),
        ],
      );
      try {
        await restarted
            .read(playerControllerProvider.notifier)
            .load(testTracks);
        expect(restarted.read(playerControllerProvider).blockedIds, {
          testTracks.first.id,
        });
        expect(
          restarted.read(playerControllerProvider).currentTrack?.id,
          testTracks.last.id,
        );
        await restarted
            .read(playerControllerProvider.notifier)
            .setBlocked(testTracks.first.id, false);
        expect(await repository.blockedSongIds('offline'), isEmpty);
      } finally {
        restarted.dispose();
      }
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
