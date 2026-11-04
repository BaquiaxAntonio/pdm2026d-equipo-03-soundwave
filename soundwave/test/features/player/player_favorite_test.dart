import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/playlist.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/player/player_screen.dart';
import 'package:soundwave/features/player/providers/player_provider.dart';
import 'package:soundwave/features/playlists/playlist_providers.dart';

import '../../support/fake_repositories.dart';

const song = Song(
  id: 'demo:song',
  title: 'Primera',
  artist: 'Artista A',
  provider: 'demo',
  sourceId: 'song',
);

class _SingleDownloadLibrary extends FakeDownloadRepository {
  _SingleDownloadLibrary(this.song) : record = completedRecord(song.id);

  final Song song;
  final DownloadRecord record;

  @override
  Future<List<DownloadRecord>> loadDownloads() async => [record];

  @override
  Stream<List<DownloadRecord>> watchDownloads() async* {
    yield [record];
  }

  @override
  Future<DownloadRecord?> findBySongId(String songId) async =>
      songId == song.id ? record : null;
}

class _FavoritesRepository implements PlaylistRepository {
  final Map<String, List<Song>> songs = {};

  @override
  Future<List<Song>> loadSongs(String playlistId) async =>
      List.unmodifiable(songs[playlistId] ?? const <Song>[]);

  @override
  Future<void> setFavorite({required Song song, required bool favorite}) async {
    final list = songs.putIfAbsent(favoritesPlaylistId, () => []);
    if (favorite) {
      if (!list.any((item) => item.id == song.id)) list.add(song);
    } else {
      list.removeWhere((item) => item.id == song.id);
    }
  }

  @override
  Future<List<PlaylistEntry>> loadPlaylists() async => const [];

  @override
  Future<Playlist> create(String name) => throw UnimplementedError();

  @override
  Future<void> rename({required String id, required String name}) =>
      throw UnimplementedError();

  @override
  Future<void> setArchived({required String id, required bool archived}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  @override
  Future<bool> addSong({required String playlistId, required Song song}) =>
      throw UnimplementedError();

  @override
  Future<void> removeSong({
    required String playlistId,
    required String songId,
  }) => throw UnimplementedError();
}

void main() {
  late _FavoritesRepository repository;

  setUp(() {
    repository = _FavoritesRepository();
  });

  Future<void> showPlayer(
    WidgetTester tester, {
    DataMode mode = DataMode.localSqlite,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(mode),
          playbackPreferencesProvider.overrideWith(
            (ref) async => FakePlaybackPreferencesRepository(),
          ),
          playlistRepositoryProvider.overrideWith((ref) async => repository),
          downloadSessionProvider.overrideWith(
            (ref) async => DownloadSession(
              _SingleDownloadLibrary(song),
              (_) async => song,
            ),
          ),
        ],
        child: const MaterialApp(home: PlayerScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('el corazón guarda la canción en favoritos', (tester) async {
    await showPlayer(tester);

    expect(find.byTooltip('Me gusta'), findsOneWidget);
    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();

    expect(repository.songs[favoritesPlaylistId]!.single.id, song.id);
    expect(find.byTooltip('Quitar de Música que me gusta'), findsOneWidget);
    expect(find.text('Guardada en «Música que me gusta».'), findsOneWidget);
  });

  testWidgets('el corazón quita la canción de favoritos', (tester) async {
    repository.songs[favoritesPlaylistId] = [song];
    await showPlayer(tester);

    expect(find.byTooltip('Quitar de Música que me gusta'), findsOneWidget);
    await tester.tap(find.byTooltip('Quitar de Música que me gusta'));
    await tester.pumpAndSettle();

    expect(repository.songs[favoritesPlaylistId], isEmpty);
    expect(find.byTooltip('Me gusta'), findsOneWidget);
    expect(find.text('Quitada de «Música que me gusta».'), findsOneWidget);
  });

  testWidgets('en modo demo el corazón queda deshabilitado', (tester) async {
    await showPlayer(tester, mode: DataMode.demo);

    expect(find.byTooltip('Me gusta'), findsOneWidget);
    await tester.tap(find.byTooltip('Me gusta'));
    await tester.pumpAndSettle();

    expect(repository.songs[favoritesPlaylistId], isNull);
    expect(find.byTooltip('Quitar de Música que me gusta'), findsNothing);
  });
}
