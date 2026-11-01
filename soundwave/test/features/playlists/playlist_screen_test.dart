import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/playlist.dart';
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
        ],
        child: const MaterialApp(home: PlaylistScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tocar una lista abre el formulario lleno y guarda cambios con el mismo id',
    (tester) async {
      final repository = _FakePlaylistRepository([
        const PlaylistEntry(
          playlist: Playlist(id: 'pl-1', name: 'Transporte'),
          songCount: 3,
        ),
      ]);
      await pumpScreen(tester, repository);

      await tester.tap(find.text('Transporte'));
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

    await tester.tap(find.byTooltip('Eliminar Transporte'));
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
}

class _FakePlaylistRepository implements PlaylistRepository {
  _FakePlaylistRepository([Iterable<PlaylistEntry> seed = const []])
    : _entries = [...seed];

  final List<PlaylistEntry> _entries;
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
