import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/playlist.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/player/data/player_playlist_repository.dart';
import 'package:soundwave/features/player/player_playlists_screen.dart';
import 'package:soundwave/features/player/providers/player_playlists_provider.dart';
import 'package:soundwave/features/player/providers/player_queue_provider.dart';
import 'package:soundwave/features/player/widgets/player_playlist_form.dart';
import 'package:soundwave/features/playlists/playlist_providers.dart';
import 'package:soundwave/features/playlists/playlist_screen.dart';

// Controlled shared state for the two views of player-managed lists. SQLite
// constraints and UPDATE semantics remain covered by repository tests.
class _GeneralPlaylistView implements PlaylistRepository {
  _GeneralPlaylistView(this.shared);
  final MemoryPlayerPlaylistRepository shared;

  @override
  Future<List<PlaylistEntry>> loadPlaylists() async => [
    for (final item in await shared.list())
      PlaylistEntry(
        playlist: Playlist(
          id: item.id,
          name: item.name,
          archived: item.archived,
        ),
        songCount: item.songCount,
      ),
  ];

  @override
  Future<Playlist> create(String name) async {
    await shared.save(name: name);
    final item = (await shared.list()).firstWhere((p) => p.name == name.trim());
    return Playlist(id: item.id, name: item.name);
  }

  @override
  Future<void> rename({required String id, required String name}) =>
      shared.save(id: id, name: name);

  @override
  Future<void> setArchived({required String id, required bool archived}) =>
      shared.setArchived(id, archived);

  @override
  Future<void> delete(String id) async {
    try {
      await shared.delete(id);
    } on PlayerPlaylistException catch (error) {
      throw RepositoryException(
        error.inUse ? RepositoryErrorCode.inUse : RepositoryErrorCode.storage,
        error.message,
      );
    }
  }
}

class _BothPlaylistScreens extends StatefulWidget {
  const _BothPlaylistScreens();

  @override
  State<_BothPlaylistScreens> createState() => _BothPlaylistScreensState();
}

class _BothPlaylistScreensState extends State<_BothPlaylistScreens> {
  int index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => index = 0),
              child: const Text('Abrir Player'),
            ),
            TextButton(
              onPressed: () => setState(() => index = 1),
              child: const Text('Abrir Listas'),
            ),
          ],
        ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: const [PlayerPlaylistsScreen(), PlaylistScreen()],
          ),
        ),
      ],
    ),
  );
}

void main() {
  late MemoryPlayerPlaylistRepository shared;

  setUp(() => shared = MemoryPlayerPlaylistRepository());

  Future<void> openScreens(WidgetTester tester) async {
    final general = _GeneralPlaylistView(shared);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          playerPlaylistRepositoryProvider.overrideWith((ref) async => shared),
          playlistRepositoryProvider.overrideWith((ref) async => general),
          fullPlayerQueueProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: _BothPlaylistScreens()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> playerAction(
    WidgetTester tester,
    String name,
    String action,
  ) async {
    await tester.tap(find.byTooltip('Opciones de $name'));
    await tester.pumpAndSettle();
    await tap(tester, action);
    if (action == 'Eliminar') await tap(tester, 'Eliminar');
  }

  testWidgets(
    'Player create/edit and Listas archive/delete refresh both views',
    (tester) async {
      await openScreens(tester);
      await tap(tester, 'Nueva lista');
      expect(find.byType(PlayerPlaylistForm), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Viaje');
      await tap(tester, 'Crear');
      final id = (await shared.list()).single.id;

      await tap(tester, 'Abrir Listas');
      expect(find.text('Viaje'), findsOneWidget);
      await tap(tester, 'Abrir Player');
      await tap(tester, 'Viaje');
      expect(find.byType(PlayerPlaylistForm), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Viaje',
      );
      await tester.enterText(find.byType(TextFormField), 'Noche');
      await tap(tester, 'Guardar cambios');
      expect((await shared.list()).single.id, id);

      await tap(tester, 'Abrir Listas');
      expect(find.text('Noche'), findsOneWidget);
      expect(find.text('Viaje'), findsNothing);
      await tester.tap(find.byTooltip('Archivar Noche'));
      await tester.pumpAndSettle();
      await tap(tester, 'Abrir Player');
      expect(find.text('Archivadas'), findsOneWidget);
      await playerAction(tester, 'Noche', 'Restaurar');

      await tap(tester, 'Abrir Listas');
      expect(find.text('Archivadas'), findsNothing);
      expect(find.byTooltip('Archivar Noche'), findsOneWidget);
      await tester.tap(find.byTooltip('Eliminar Noche'));
      await tester.pumpAndSettle();
      await tap(tester, 'Eliminar');
      await tap(tester, 'Abrir Player');
      expect(find.text('Noche'), findsNothing);
      expect(await shared.list(), isEmpty);
    },
  );

  testWidgets(
    'Listas edits and restores; Player archives and deletes reactively',
    (tester) async {
      await shared.save(name: 'Compartida');
      final id = (await shared.list()).single.id;
      await openScreens(tester);
      await tap(tester, 'Abrir Listas');
      await tap(tester, 'Compartida');
      await tester.enterText(find.byType(TextFormField), 'Editada');
      await tap(tester, 'Guardar cambios');
      await tap(tester, 'Abrir Player');
      expect(find.text('Editada'), findsOneWidget);
      expect(find.text('Compartida'), findsNothing);
      expect((await shared.list()).single.id, id);

      await playerAction(tester, 'Editada', 'Archivar');
      await tap(tester, 'Abrir Listas');
      expect(find.text('Archivadas'), findsOneWidget);
      await tester.tap(find.byTooltip('Desarchivar Editada'));
      await tester.pumpAndSettle();
      await tap(tester, 'Abrir Player');
      expect(find.text('Archivadas'), findsNothing);
      await playerAction(tester, 'Editada', 'Eliminar');
      await tap(tester, 'Abrir Listas');
      expect(find.text('Editada'), findsNothing);
      expect(find.text('Aún no tienes listas'), findsOneWidget);
    },
  );

  testWidgets('duplicate edit keeps the form and both lists unchanged', (
    tester,
  ) async {
    await shared.save(name: 'Viaje');
    await shared.save(name: 'Trabajo', songIds: ['saved-song']);
    final id = (await shared.list()).firstWhere((p) => p.name == 'Trabajo').id;
    await openScreens(tester);
    await tap(tester, 'Trabajo');
    await tester.enterText(find.byType(TextFormField), 'viaje');
    await tap(tester, 'Guardar cambios');
    expect(find.text('Ya existe una lista con ese nombre.'), findsOneWidget);
    expect(find.byType(PlayerPlaylistForm), findsOneWidget);
    expect((await shared.list()).firstWhere((p) => p.id == id).name, 'Trabajo');
    expect((await shared.songs(id)).single.id, 'saved-song');
    await tap(tester, 'Cancelar');
    await tap(tester, 'Abrir Listas');
    expect(find.text('Trabajo'), findsOneWidget);
    expect(find.text('Viaje'), findsOneWidget);
    expect(await shared.list(), hasLength(2));
  });

  testWidgets(
    'blocked deletion offers archive and updates the other view without losing songs',
    (tester) async {
      await shared.save(name: 'En uso', songIds: ['saved-song']);
      final id = (await shared.list()).single.id;
      await openScreens(tester);
      await playerAction(tester, 'En uso', 'Eliminar');
      expect(find.text('Lista en uso'), findsOneWidget);
      expect(
        find.text(
          'Esta lista contiene canciones. Puedes archivarla para conservarlas.',
        ),
        findsOneWidget,
      );
      expect((await shared.list()).single.archived, isFalse);
      await tap(tester, 'Archivar');
      await tap(tester, 'Abrir Listas');
      expect(find.text('Archivadas'), findsOneWidget);
      expect(find.text('Archivada · 1 canción'), findsOneWidget);
      expect((await shared.list()).single.id, id);
      expect((await shared.songs(id)).single.id, 'saved-song');
    },
  );
}
