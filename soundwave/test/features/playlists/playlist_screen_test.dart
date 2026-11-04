import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/playlist.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/playlists/playlist_providers.dart';
import 'package:soundwave/features/playlists/playlist_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    _FakePlaylistRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          playlistRepositoryProvider.overrideWith((ref) async => repository),
          catalogSongsProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: PlaylistScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editar una lista abre el formulario lleno y guarda cambios con el mismo id',
    (tester) async {
      final repository = _FakePlaylistRepository([
        const PlaylistEntry(
          playlist: Playlist(id: 'pl-1', name: 'Transporte'),
          songCount: 3,
        ),
      ]);
      await pumpScreen(tester, repository);

      await tester.tap(find.byTooltip('Opciones de la lista Transporte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar lista'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Transporte',
      );

      await tester.enterText(find.byType(TextField), 'Viajes');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(find.text('Viajes'), findsOneWidget);
      expect(find.text('Transporte'), findsNothing);
      expect(repository.entries.single.playlist.id, 'pl-1');
      expect(repository.entries.single.songCount, 3);
    },
  );

  testWidgets('el menú de la lista abre la hoja para agregar canciones', (
    tester,
  ) async {
    final repository = _FakePlaylistRepository([
      const PlaylistEntry(
        playlist: Playlist(id: 'pl-1', name: 'Transporte'),
        songCount: 0,
      ),
    ]);
    await pumpScreen(tester, repository);

    await tester.tap(find.byTooltip('Opciones de la lista Transporte'));
    await tester.pumpAndSettle();
    expect(find.text('Agregar'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Agregar a «Transporte»'), findsOneWidget);
    expect(find.text('Aún no tienes canciones guardadas.'), findsOneWidget);
  });

  testWidgets('crear una lista la muestra sin recargar a mano', (tester) async {
    final repository = _FakePlaylistRepository([
      const PlaylistEntry(
        playlist: Playlist(id: 'pl-1', name: 'Transporte'),
        songCount: 0,
      ),
    ]);
    await pumpScreen(tester, repository);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Para el viaje');
    await tester.tap(find.text('Crear lista'));
    await tester.pumpAndSettle();

    expect(find.text('Para el viaje'), findsOneWidget);
    expect(repository.entries, hasLength(2));
  });

  testWidgets('un nombre repetido muestra un mensaje humano', (tester) async {
    final repository = _FakePlaylistRepository([
      const PlaylistEntry(
        playlist: Playlist(id: 'pl-1', name: 'Transporte'),
        songCount: 0,
      ),
    ]);
    await pumpScreen(tester, repository);

    await tester.tap(find.text('Nueva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' transporte ');
    await tester.tap(find.text('Crear lista'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe una lista con ese nombre. Elige otro.'),
      findsOneWidget,
    );
    expect(repository.entries, hasLength(1));
    expect(find.text('Nueva lista'), findsOneWidget);
  });

  testWidgets('borrar una lista en uso no la borra y ofrece archivarla', (
    tester,
  ) async {
    final repository = _FakePlaylistRepository([
      const PlaylistEntry(
        playlist: Playlist(id: 'pl-1', name: 'Transporte'),
        songCount: 3,
      ),
    ]);
    await pumpScreen(tester, repository);

    await tester.tap(find.byTooltip('Opciones de la lista Transporte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('No se puede eliminar'), findsOneWidget);
    expect(
      find.textContaining('Archívala para dejar de verla'),
      findsOneWidget,
    );
    expect(repository.entries.single.playlist.archived, isFalse);

    await tester.tap(find.text('Archivar'));
    await tester.pumpAndSettle();

    expect(repository.entries.single.playlist.archived, isTrue);
    expect(repository.entries, hasLength(1));
    expect(find.text('Archivadas'), findsOneWidget);
    expect(find.text('Transporte'), findsOneWidget);
  });

  testWidgets(
    'abrir una lista muestra sus canciones y permite quitarlas con deshacer',
    (tester) async {
      const song = Song(
        id: 'song-1',
        title: 'Canción',
        artist: 'Artista',
        provider: 'local',
        sourceId: 'song-1',
        durationMs: 63000,
      );
      final repository = _FakePlaylistRepository(
        [
          const PlaylistEntry(
            playlist: Playlist(id: 'pl-1', name: 'Transporte'),
            songCount: 1,
          ),
        ],
        {
          'pl-1': [song],
        },
      );
      await pumpScreen(tester, repository);

      await tester.tap(find.text('Transporte'));
      await tester.pumpAndSettle();
      expect(find.text('Canción'), findsOneWidget);
      expect(find.text('Toca una canción para reproducirla.'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar Canción de la lista'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar «Canción»?'), findsOneWidget);
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      expect(find.text('Esta lista aún no tiene canciones'), findsOneWidget);
      expect(repository.entries.single.songCount, 0);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(find.text('Canción'), findsOneWidget);
      expect(repository.entries.single.songCount, 1);
    },
  );

  testWidgets(
    'los favoritos aparecen como lista automática y abren su detalle',
    (tester) async {
      final repository = _FakePlaylistRepository([
        const PlaylistEntry(
          playlist: Playlist(id: 'pl-1', name: 'Transporte'),
          songCount: 0,
        ),
      ]);
      await pumpScreen(tester, repository);

      expect(find.text(favoritesPlaylistName), findsOneWidget);
      await tester.tap(find.text(favoritesPlaylistName));
      await tester.pumpAndSettle();
      expect(find.text('Aún no tienes canciones favoritas'), findsOneWidget);
    },
  );
}

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository([
    Iterable<PlaylistEntry> seed = const [],
    Map<String, List<Song>> songs = const {},
  ]) : _entries = [...seed],
       _songs = {
         for (final entry in songs.entries) entry.key: [...entry.value],
       };

  final List<PlaylistEntry> _entries;
  final Map<String, List<Song>> _songs;
  var _nextId = 0;

  List<PlaylistEntry> get entries => List.unmodifiable(_entries);

  @override
  Future<List<PlaylistEntry>> loadPlaylists() async => entries;

  @override
  Future<Playlist> create(String name) async {
    _ensureUnique(name);
    final playlist = Playlist(id: 'list-${_nextId++}', name: name.trim());
    _entries.add(PlaylistEntry(playlist: playlist, songCount: 0));
    return playlist;
  }

  @override
  Future<void> rename({required String id, required String name}) async {
    _ensureUnique(name, exceptId: id);
    final index = _indexOf(id);
    _entries[index] = PlaylistEntry(
      playlist: _entries[index].playlist.copyWith(name: name.trim()),
      songCount: _entries[index].songCount,
    );
  }

  @override
  Future<void> setArchived({required String id, required bool archived}) async {
    final index = _indexOf(id);
    _entries[index] = PlaylistEntry(
      playlist: _entries[index].playlist.copyWith(archived: archived),
      songCount: _entries[index].songCount,
    );
  }

  @override
  Future<void> delete(String id) async {
    final index = _indexOf(id);
    final entry = _entries[index];
    if (entry.songCount > 0) {
      throw RepositoryException(
        RepositoryErrorCode.inUse,
        'La lista «${entry.playlist.name}» tiene ${entry.songCount} canciones. '
        'Archívala para dejar de verla.',
      );
    }
    _entries.removeAt(index);
  }

  @override
  Future<List<Song>> loadSongs(String playlistId) async =>
      List.unmodifiable(_songs[playlistId] ?? const <Song>[]);

  @override
  Future<bool> addSong({required String playlistId, required Song song}) async {
    final songs = _songs.putIfAbsent(playlistId, () => []);
    if (songs.any((item) => item.id == song.id)) return false;
    songs.add(song);
    _syncCount(playlistId);
    return true;
  }

  @override
  Future<void> removeSong({
    required String playlistId,
    required String songId,
  }) async {
    _songs[playlistId]?.removeWhere((song) => song.id == songId);
    _syncCount(playlistId);
  }

  @override
  Future<void> setFavorite({required Song song, required bool favorite}) async {
    if (_indexOf(favoritesPlaylistId) == -1) {
      _entries.add(
        const PlaylistEntry(playlist: favoritesPlaylist, songCount: 0),
      );
    }
    if (favorite) {
      await addSong(playlistId: favoritesPlaylistId, song: song);
    } else {
      await removeSong(playlistId: favoritesPlaylistId, songId: song.id);
    }
  }

  void _syncCount(String playlistId) {
    final index = _indexOf(playlistId);
    if (index == -1) return;
    _entries[index] = PlaylistEntry(
      playlist: _entries[index].playlist,
      songCount: _songs[playlistId]?.length ?? 0,
    );
  }

  int _indexOf(String id) =>
      _entries.indexWhere((entry) => entry.playlist.id == id);

  void _ensureUnique(String name, {String? exceptId}) {
    final normalized = name.trim().toLowerCase();
    final repeated = _entries.any(
      (entry) =>
          entry.playlist.id != exceptId &&
          entry.playlist.name.toLowerCase() == normalized,
    );
    if (repeated) {
      throw const RepositoryException(
        RepositoryErrorCode.duplicateName,
        'Ya existe una lista con ese nombre. Elige otro.',
      );
    }
  }
}
