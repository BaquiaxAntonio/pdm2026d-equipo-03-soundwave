import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/models/playlist.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/playlists/add_to_playlist_sheet.dart';
import 'package:soundwave/features/playlists/playlist_providers.dart';

void main() {
  late _MemoryPlaylistRepository repository;

  setUp(() {
    repository = _MemoryPlaylistRepository([
      const PlaylistEntry(
        playlist: Playlist(id: 'list-0', name: 'Viaje'),
        songCount: 0,
      ),
    ]);
  });

  const song = Song(
    id: 'demo:song',
    title: 'Canción',
    artist: 'Artista',
    provider: 'demo',
    sourceId: 'song',
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showAddToPlaylistSheet(context, song),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds the song to an existing list and closes the sheet', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Añadir a lista'), findsOneWidget);
    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();

    expect(repository.entries.single.songCount, 1);
    expect(repository.songs['list-0']!.single.id, song.id);
    expect(find.textContaining('añadida a «Viaje»'), findsOneWidget);
  });

  testWidgets('adds the song to favorites from the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(favoritesPlaylistName));
    await tester.pumpAndSettle();

    expect(repository.songs[favoritesPlaylistId]!.single.id, song.id);
    expect(
      find.textContaining('Guardada en «Música que me gusta»'),
      findsOneWidget,
    );
  });
}

class _MemoryPlaylistRepository implements PlaylistRepository {
  _MemoryPlaylistRepository(Iterable<PlaylistEntry> seed) : entries = [...seed];

  final List<PlaylistEntry> entries;
  final Map<String, List<Song>> songs = {};

  @override
  Future<List<PlaylistEntry>> loadPlaylists() async =>
      List.unmodifiable(entries);

  @override
  Future<List<Song>> loadSongs(String playlistId) async =>
      List.unmodifiable(songs[playlistId] ?? const <Song>[]);

  @override
  Future<bool> addSong({required String playlistId, required Song song}) async {
    final list = songs.putIfAbsent(playlistId, () => []);
    if (list.any((item) => item.id == song.id)) return false;
    list.add(song);
    final index = entries.indexWhere(
      (entry) => entry.playlist.id == playlistId,
    );
    entries[index] = PlaylistEntry(
      playlist: entries[index].playlist,
      songCount: list.length,
    );
    return true;
  }

  @override
  Future<void> setFavorite({required Song song, required bool favorite}) async {
    if (!entries.any((entry) => entry.playlist.id == favoritesPlaylistId)) {
      entries.add(
        const PlaylistEntry(playlist: favoritesPlaylist, songCount: 0),
      );
    }
    if (favorite) {
      await addSong(playlistId: favoritesPlaylistId, song: song);
      return;
    }
    final list = songs[favoritesPlaylistId];
    list?.removeWhere((item) => item.id == song.id);
    final index = entries.indexWhere(
      (entry) => entry.playlist.id == favoritesPlaylistId,
    );
    entries[index] = PlaylistEntry(
      playlist: entries[index].playlist,
      songCount: list?.length ?? 0,
    );
  }

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
  Future<void> removeSong({
    required String playlistId,
    required String songId,
  }) => throw UnimplementedError();
}
