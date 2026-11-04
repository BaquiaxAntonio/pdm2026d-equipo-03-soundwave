import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/download_dao.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/data/local_audio_file_store.dart';
import 'package:soundwave/features/downloads/data/sqlite_download_repository.dart';
import 'package:soundwave/features/downloads/data/http_audio_downloader.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/search/search_controller.dart';
import 'package:soundwave/features/search/data/commons_song_adapter.dart';
import 'package:soundwave/features/player/providers/player_provider.dart';
import 'package:soundwave/features/player/providers/player_can_delete.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'audio_fixture.dart';
import '../player/fake_playback_controller.dart';

void main() {
  const song = Song(
    id: 'fixture:audio',
    title: 'Audio',
    artist: 'Test',
    provider: 'fixture',
    sourceId: 'audio',
  );
  late Database database;
  late LocalAudioFileStore files;
  late SqliteDownloadRepository repository;
  late OpenDownload source;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createDatabaseSchema(db),
      ),
    );
    files = LocalAudioFileStore(
      await Directory.systemTemp.createTemp('soundwave-mvp06-'),
    );
    source = (_) async =>
        DownloadInput(Stream.value(wavFixture()), totalBytes: 48);
    repository = SqliteDownloadRepository(
      database: database,
      files: files,
      openDownload: (song) => source(song),
    );
  });
  tearDown(() async {
    await repository.dispose();
    await database.close();
  });

  test(
    'downloaded audio opens offline and deletion awaits decoder release',
    () async {
      var time = DateTime.now();
      late ProviderContainer container;
      final engine = FakePlaybackController();
      final managed = SqliteDownloadRepository(
        database: database,
        files: files,
        openDownload: source,
        clock: () => time,
        canDelete: (id) =>
            container.read(playerDeletionGuardProvider).canDelete(id),
      );
      container = ProviderContainer(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          playbackEngineProvider.overrideWithValue(engine),
          playbackPreferencesProvider.overrideWith((_) async => null),
          downloadSessionProvider.overrideWith(
            (_) async => DownloadSession(
              managed,
              managed.songs.findById,
              localAudioUri: (path) async => File(files.resolve(path)).uri,
            ),
          ),
        ],
      );
      try {
        await managed.enqueue(song);
        final path = (await managed.findBySongId(song.id))!.localPath!;
        final player = container.read(playerControllerProvider.notifier);
        await player.openById(song.id);
        expect(engine.loaded.single, File(files.resolve(path)).uri);
        expect(engine.playing, isTrue);
        expect(container.read(playerControllerProvider).error, isNull);
        await managed.requestRemoval(
          song.id,
          undoUntil: time.add(const Duration(seconds: 4)),
        );
        await managed.undoRemoval(song.id);
        expect(
          (await managed.findBySongId(song.id))!.state,
          DownloadState.completed,
        );
        expect(await files.exists(path), isTrue);
        await player.pause();
        await managed.requestRemoval(
          song.id,
          undoUntil: time.add(const Duration(seconds: 4)),
        );
        time = time.add(const Duration(seconds: 5));
        engine.stopGate = Completer<void>();
        final removal = managed.finalizeExpiredRemovals();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(await files.exists(path), isTrue);
        expect(
          (await managed.findBySongId(song.id))!.state,
          DownloadState.pendingDeletion,
        );
        engine.stopGate!.complete();
        await removal;
        expect(await managed.findBySongId(song.id), isNull);
        expect(await files.exists(path), isFalse);
        expect(container.read(playerControllerProvider).tracks, isEmpty);
      } finally {
        if (engine.stopGate != null && !engine.stopGate!.isCompleted) {
          engine.stopGate!.complete();
        }
        container.dispose();
        await managed.dispose();
      }
    },
  );

  test(
    'Commons catalog to Search action downloads HTTP bytes and keeps credits',
    () async {
      final fixture = jsonDecode(
        await File(
          'test/features/search/fixtures/welcome_to_noxville_response.json',
        ).readAsString(),
      );
      final catalogSong = parseCommonsCatalogResponse(fixture).single.song;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.contentLength = 48;
        request.response.add(wavFixture());
        await request.response.close();
      });
      final downloader = HttpAudioDownloader((requested) async {
        expect(requested.id, catalogSong.id);
        return PermittedAudio(
          Uri.parse('http://127.0.0.1:${server.port}/audio'),
          downloadAllowed: true,
          size: 48,
          sha1: sha1.convert(wavFixture()).toString(),
        );
      }, allowLocalHttp: true);
      source = downloader.open;
      final container = ProviderContainer(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          downloadSessionProvider.overrideWith(
            (ref) async =>
                DownloadSession(repository, repository.songs.findById),
          ),
        ],
      );
      try {
        final result = await container
            .read(searchDownloadControllerProvider.notifier)
            .request(catalogSong);
        expect(result.outcome, SearchDownloadRequestOutcome.requested);
        final saved = (await repository.findBySongId(catalogSong.id))!;
        expect(saved.state, DownloadState.completed);
        expect(await files.exists(saved.localPath!), isTrue);
        final persisted = (await repository.songs.findById(catalogSong.id))!;
        expect(persisted.license, catalogSong.license);
        expect(persisted.attribution, catalogSong.attribution);
        expect(persisted.sourceUrl, catalogSong.sourceUrl);
        expect(
          (await container
                  .read(searchDownloadControllerProvider.notifier)
                  .request(catalogSong))
              .outcome,
          SearchDownloadRequestOutcome.alreadyPresent,
        );
      } finally {
        container.dispose();
        await server.close(force: true);
      }
    },
  );

  test('duplicate request cannot replace persisted credits', () async {
    final credited = Song.fromMap({...song.toMap(), 'license': 'CC BY 4.0'});
    await repository.enqueue(credited);
    await expectLater(
      repository.enqueue(song),
      throwsA(isA<RepositoryException>()),
    );
    expect((await repository.songs.findById(song.id))!.license, 'CC BY 4.0');
  });

  test('checksum mismatch fails and removes partial before retry', () async {
    source = (_) async => DownloadInput(
      Stream.value(wavFixture()),
      totalBytes: 48,
      expectedSha1: '0' * 40,
    );
    await expectLater(
      repository.enqueue(song),
      throwsA(isA<RepositoryException>()),
    );
    expect(
      (await repository.findBySongId(song.id))!.state,
      DownloadState.failed,
    );
    final partials = await Directory(
      files.resolve('.part'),
    ).list(recursive: true).where((e) => e is File).toList();
    expect(partials, isEmpty);
    source = (_) async => DownloadInput(
      Stream.value(wavFixture()),
      totalBytes: 48,
      expectedSha1: sha1.convert(wavFixture()).toString(),
    );
    await repository.retry(song.id);
    expect(
      (await repository.findBySongId(song.id))!.state,
      DownloadState.completed,
    );
  });

  test(
    'commits bytes before completion and persists across repository recreation',
    () async {
      await repository.enqueue(song);
      final record = (await repository.findBySongId(song.id))!;
      expect(record.state, DownloadState.completed);
      expect(record.progress, 1);
      expect(
        await File(files.resolve(record.localPath!)).readAsBytes(),
        wavFixture(),
      );
      final reopened = SqliteDownloadRepository(
        database: database,
        files: files,
        openDownload: source,
      );
      expect(
        (await reopened.findBySongId(song.id))!.localPath,
        record.localPath,
      );
      await reopened.dispose();
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test(
    'rechaza contenido alterado aunque longitud y contenedor sean válidos',
    () async {
      source = (_) async => DownloadInput(
        Stream.value(wavFixture()),
        totalBytes: 48,
        expectedSha1: '0000000000000000000000000000000000000000',
      );
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
      final record = await repository.findBySongId(song.id);
      expect(record?.state, DownloadState.failed);
      expect(record?.localPath, isNull);
    },
  );

  test(
    'prevents simultaneous duplicate transfers and emits real progress',
    () async {
      final bytes = StreamController<List<int>>();
      final opened = Completer<void>();
      source = (_) async {
        opened.complete();
        return DownloadInput(bytes.stream, totalBytes: 48);
      };
      final seen = <DownloadRecord>[];
      final half = Completer<void>();
      final subscription = repository.watchDownloads().listen((records) {
        seen.addAll(records);
        if (records.any((r) => r.bytesReceived == 24) && !half.isCompleted) {
          half.complete();
        }
      });
      final task = repository.enqueue(song);
      await opened.future;
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
      bytes.add(wavFixture().sublist(0, 24));
      await half.future.timeout(const Duration(seconds: 5));
      expect(seen.any((r) => r.progress == 0.5), isTrue);
      bytes.add(wavFixture().sublist(24));
      await bytes.close();
      await task;
      await subscription.cancel();
    },
  );

  test('unknown length stays indeterminate', () async {
    source = (_) async => DownloadInput(Stream.value(wavFixture()));
    await repository.enqueue(song);
    expect((await repository.findBySongId(song.id))!.progress, isNull);
  });

  test(
    'incomplete audio fails without final path and can retry from zero',
    () async {
      source = (_) async => DownloadInput(Stream.value([1]), totalBytes: 3);
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
      final failed = (await repository.findBySongId(song.id))!;
      expect(failed.state, DownloadState.failed);
      expect(failed.localPath, isNull);
      source = (_) async =>
          DownloadInput(Stream.value(wavFixture()), totalBytes: 48);
      await repository.retry(song.id);
      final retried = (await repository.findBySongId(song.id))!;
      expect(retried.state, DownloadState.completed);
      expect(retried.bytesReceived, 48);
    },
  );

  test('network error and empty response never become available', () async {
    source = (_) async =>
        DownloadInput(Stream.error(const SocketException('offline')));
    await expectLater(
      repository.enqueue(song),
      throwsA(isA<SocketException>()),
    );
    expect(
      (await repository.findBySongId(song.id))!.state,
      DownloadState.failed,
    );
    source = (_) async => const DownloadInput(Stream.empty());
    await expectLater(
      repository.retry(song.id),
      throwsA(isA<RepositoryException>()),
    );
    expect((await repository.findBySongId(song.id))!.localPath, isNull);
  });

  test(
    'recovers interrupted records and reports missing completed files',
    () async {
      await repository.enqueue(song);
      final original = (await repository.findBySongId(song.id))!;
      await DownloadDao(database).upsert(
        DownloadRecord.fromMap({
          ...original.toMap(),
          'state': 'downloading',
          'local_path': null,
        }),
      );
      await repository.recoverInterrupted();
      expect(
        (await repository.findBySongId(song.id))!.state,
        DownloadState.failed,
      );
      await DownloadDao(database).upsert(
        DownloadRecord.fromMap({
          ...original.toMap(),
          'local_path': 'audio/absent.audio',
        }),
      );
      await repository.recoverInterrupted();
      expect(
        (await repository.findBySongId(song.id))!.errorMessage,
        'Audio missing.',
      );
    },
  );

  test(
    'pending removal survives recreation and undo retains the file',
    () async {
      await repository.enqueue(song);
      await repository.requestRemoval(
        song.id,
        undoUntil: DateTime.now().add(const Duration(minutes: 1)),
      );
      final reopened = SqliteDownloadRepository(
        database: database,
        files: files,
        openDownload: source,
      );
      final pending = (await reopened.findBySongId(song.id))!;
      expect(pending.state, DownloadState.pendingDeletion);
      expect(await files.exists(pending.localPath!), isTrue);
      await reopened.undoRemoval(song.id);
      expect(
        (await repository.findBySongId(song.id))!.state,
        DownloadState.completed,
      );
      await reopened.dispose();
    },
  );

  test(
    'file store rejects traversal and empty or unrelated temporary files',
    () async {
      expect(
        () => files.resolve('../outside'),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => files.resolve(files.root.path),
        throwsA(isA<RepositoryException>()),
      );
      final temporary = await files.createTemporaryPath(song.id);
      await expectLater(
        files.commit(temporary, song.id),
        throwsA(isA<RepositoryException>()),
      );
      await File(temporary).writeAsBytes([1]);
      await expectLater(
        files.commit(temporary, 'different'),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test(
    'rejects non-audio bytes and truncated WAV even with matching length',
    () async {
      source = (_) async =>
          DownloadInput(Stream.value(List.filled(48, 65)), totalBytes: 48);
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        (await repository.findBySongId(song.id))!.state,
        DownloadState.failed,
      );
      source = (_) async => DownloadInput(
        Stream.value(wavFixture().sublist(0, 46)),
        totalBytes: 46,
      );
      await expectLater(
        repository.retry(song.id),
        throwsA(isA<RepositoryException>()),
      );
      expect((await repository.findBySongId(song.id))!.localPath, isNull);
    },
  );

  test(
    'startup removes partials and orphan files, retains valid downloads',
    () async {
      await repository.enqueue(song);
      final record = (await repository.findBySongId(song.id))!;
      final partial = await files.createTemporaryPath('orphan');
      await File(partial).writeAsBytes([1, 2]);
      final orphan = File(files.resolve('audio/orphan.audio'));
      await orphan.writeAsBytes(wavFixture());
      await repository.recoverInterrupted();
      expect(await File(partial).exists(), isFalse);
      expect(await orphan.exists(), isFalse);
      expect(await files.exists(record.localPath!), isTrue);
    },
  );

  test('finalizes expired deletion only after playback release', () async {
    var time = DateTime.now();
    var released = false;
    final managed = SqliteDownloadRepository(
      database: database,
      files: files,
      openDownload: (song) => source(song),
      clock: () => time,
      canDelete: (_) async => released,
    );
    await managed.enqueue(song);
    final path = (await managed.findBySongId(song.id))!.localPath!;
    await managed.requestRemoval(
      song.id,
      undoUntil: time.add(const Duration(seconds: 4)),
    );
    time = time.add(const Duration(seconds: 5));
    await managed.finalizeExpiredRemovals();
    expect(await files.exists(path), isTrue);
    expect(
      (await managed.findBySongId(song.id))!.state,
      DownloadState.pendingDeletion,
    );
    released = true;
    await managed.finalizeExpiredRemovals();
    expect(await managed.findBySongId(song.id), isNull);
    expect(await files.exists(path), isFalse);
    expect(await database.query('playlist_songs'), isEmpty);
    await managed.dispose();
  });

  test('undo of a failed download never marks it completed', () async {
    source = (_) async => const DownloadInput(Stream.empty());
    await expectLater(
      repository.enqueue(song),
      throwsA(isA<RepositoryException>()),
    );
    await repository.requestRemoval(
      song.id,
      undoUntil: DateTime.now().add(const Duration(minutes: 1)),
    );
    await repository.undoRemoval(song.id);
    expect(
      (await repository.findBySongId(song.id))!.state,
      DownloadState.failed,
    );
  });

  test(
    'storage failure retains failed state without available audio',
    () async {
      final managed = SqliteDownloadRepository(
        database: database,
        files: FullFileStore(files.root),
        openDownload: source,
      );
      await expectLater(
        managed.enqueue(song),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        (await managed.findBySongId(song.id))!.state,
        DownloadState.failed,
      );
      expect((await managed.findBySongId(song.id))!.localPath, isNull);
      await managed.dispose();
    },
  );

  test('file deletion failure retains record for safe retry', () async {
    await repository.enqueue(song);
    var time = DateTime.now();
    final managed = SqliteDownloadRepository(
      database: database,
      files: DeleteFailingFileStore(files.root),
      openDownload: source,
      clock: () => time,
      canDelete: (_) async => true,
    );
    await managed.requestRemoval(
      song.id,
      undoUntil: time.add(const Duration(seconds: 1)),
    );
    time = time.add(const Duration(seconds: 2));
    await expectLater(
      managed.finalizeExpiredRemovals(),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      (await managed.findBySongId(song.id))!.state,
      DownloadState.pendingDeletion,
    );
    await managed.dispose();
  });

  test(
    'full SQLite reopen preserves audio and finishes expired deletion at startup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'soundwave-reopen-',
      );
      final path = '${directory.path}/metadata.db';
      Future<Database> open() => databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => createDatabaseSchema(db),
        ),
      );
      var db = await open();
      var time = DateTime.now();
      var managed = SqliteDownloadRepository(
        database: db,
        files: files,
        openDownload: source,
        clock: () => time,
        canDelete: (_) async => true,
      );
      await managed.enqueue(song);
      final original = (await managed.findBySongId(song.id))!.toMap();
      final audioPath = (await managed.findBySongId(song.id))!.localPath!;
      await managed.dispose();
      await db.close();
      db = await open();
      managed = SqliteDownloadRepository(
        database: db,
        files: files,
        openDownload: source,
        clock: () => time,
        canDelete: (_) async => true,
      );
      await managed.recoverInterrupted();
      expect(
        (await managed.findBySongId(song.id))!.state,
        DownloadState.completed,
      );
      expect(await files.exists(audioPath), isTrue);
      await managed.requestRemoval(
        song.id,
        undoUntil: time.add(const Duration(minutes: 1)),
      );
      await managed.dispose();
      await db.close();
      db = await open();
      managed = SqliteDownloadRepository(
        database: db,
        files: files,
        openDownload: source,
        clock: () => time,
        canDelete: (_) async => true,
      );
      await managed.recoverInterrupted();
      expect(
        (await managed.findBySongId(song.id))!.state,
        DownloadState.pendingDeletion,
      );
      await managed.undoRemoval(song.id);
      await managed.dispose();
      await db.close();
      db = await open();
      managed = SqliteDownloadRepository(
        database: db,
        files: files,
        openDownload: source,
        clock: () => time,
        canDelete: (_) async => true,
      );
      await managed.recoverInterrupted();
      expect((await managed.findBySongId(song.id))!.toMap(), original);
      expect(await managed.downloads.all(), hasLength(1));
      expect(await File(files.resolve(audioPath)).readAsBytes(), wavFixture());
      await managed.requestRemoval(
        song.id,
        undoUntil: time.add(const Duration(seconds: 1)),
      );
      await managed.dispose();
      await db.close();
      time = time.add(const Duration(seconds: 2));
      db = await open();
      managed = SqliteDownloadRepository(
        database: db,
        files: files,
        openDownload: source,
        clock: () => time,
        canDelete: (_) async => true,
      );
      await managed.recoverInterrupted();
      expect(await managed.findBySongId(song.id), isNull);
      expect(await files.exists(audioPath), isFalse);
      await managed.dispose();
      await db.close();
    },
  );
}

class FullFileStore extends LocalAudioFileStore {
  FullFileStore(super.directory);
  @override
  Future<String> createTemporaryPath(String songId) async =>
      throw const FileSystemException('No space left');
}

class DeleteFailingFileStore extends LocalAudioFileStore {
  DeleteFailingFileStore(super.directory);
  @override
  Future<void> delete(String relativePath) async =>
      throw const FileSystemException('Audio busy');
}
