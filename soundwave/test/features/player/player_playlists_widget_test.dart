import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/player/data/player_playlist_repository.dart';
import 'package:soundwave/features/player/data/player_queue_repository.dart';
import 'package:soundwave/features/player/player_song_local.dart';
import 'package:soundwave/features/player/player_playlists_screen.dart';
import 'package:soundwave/features/player/player_screen.dart';
import 'package:soundwave/features/player/providers/player_playlists_provider.dart';
import 'package:soundwave/features/player/providers/player_queue_provider.dart';

class RecordingPlaylistRepository extends MemoryPlayerPlaylistRepository {
  RecordingPlaylistRepository()
    : super(catalog: selectionQueue.map((entry) => entry.song).toList());
  List<String> savedSongIds = [];

  @override
  Future<void> save({
    String? id,
    required String name,
    List<String>? songIds,
  }) async {
    await super.save(id: id, name: name, songIds: songIds);
    savedSongIds = List.of(songIds ?? const []);
  }
}

const selectionQueue = [
  PlayerQueueEntry(
    song: PlayerSongLocal(
      id: 'a',
      title: 'Primera',
      artist: 'Artista A',
      durationSeconds: 180,
    ),
    position: 0,
  ),
  PlayerQueueEntry(
    song: PlayerSongLocal(
      id: 'b',
      title: 'Segunda',
      artist: 'Artista B',
      durationSeconds: 180,
    ),
    position: 1,
  ),
  PlayerQueueEntry(
    song: PlayerSongLocal(
      id: 'c',
      title: 'Tercera',
      artist: 'Artista C',
      durationSeconds: 180,
    ),
    position: 2,
  ),
];

void main() {
  late RecordingPlaylistRepository repository;

  setUp(() {
    repository = RecordingPlaylistRepository();
  });

  Future<void> showScreen(
    WidgetTester tester, {
    List<PlayerQueueEntry> queue = const [],
    bool fromPlayer = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerPlaylistRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          fullPlayerQueueProvider.overrideWith((ref) async => queue),
        ],
        child: MaterialApp(
          home: fromPlayer
              ? const PlayerScreen()
              : const PlayerPlaylistsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the player opens its playlist management screen', (
    tester,
  ) async {
    await showScreen(tester, fromPlayer: true);
    await tester.tap(find.byTooltip('Listas de reproducción'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPlaylistsScreen), findsOneWidget);
    expect(find.text('Nueva lista'), findsOneWidget);
  });

  testWidgets('create refreshes; tapping fills form and update preserves ID', (
    tester,
  ) async {
    await showScreen(tester);
    await tester.tap(find.text('Nueva lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Viaje');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Viaje'), findsOneWidget);
    final first = (await repository.list()).single;
    await tester.tap(find.text('Viaje'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'Viaje',
    );
    await tester.enterText(find.byType(TextFormField), 'Viaje nocturno');
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect(find.text('Viaje nocturno'), findsOneWidget);
    expect(find.text('Viaje'), findsNothing);
    final updated = (await repository.list()).single;
    expect(updated.id, first.id);
    expect(updated.name, 'Viaje nocturno');
  });

  testWidgets('duplicate stays in form with human message', (tester) async {
    await repository.save(name: 'Viaje');
    await showScreen(tester);
    await tester.tap(find.text('Nueva lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'viaje');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('Ya existe una lista con ese nombre.'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(await repository.list(), hasLength(1));
  });

  testWidgets('a new list can include a snapshot of the current queue', (
    tester,
  ) async {
    await showScreen(
      tester,
      queue: const [
        PlayerQueueEntry(
          song: PlayerSongLocal(
            id: 's',
            title: 'Tema',
            artist: 'Artista',
            durationSeconds: 180,
          ),
          position: 0,
        ),
      ],
    );
    await tester.tap(find.text('Nueva lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Mi cola');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('1 canción'), findsOneWidget);
    expect((await repository.list()).single.songCount, 1);
  });

  testWidgets('delete in use offers archive and preserves membership', (
    tester,
  ) async {
    await repository.save(name: 'Mi cola', songIds: ['s']);
    await showScreen(tester);
    await tester.tap(find.byTooltip('Opciones de Mi cola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(find.text('Lista en uso'), findsOneWidget);
    expect((await repository.list()).single.songCount, 1);
    await tester.tap(find.text('Archivar'));
    await tester.pumpAndSettle();
    expect(find.text('Archivadas'), findsOneWidget);
    expect((await repository.list()).single.archived, isTrue);
    expect((await repository.list()).single.songCount, 1);
  });

  testWidgets('selecting one song saves only that ID', (tester) async {
    await showScreen(tester, queue: selectionQueue);
    await tester.tap(find.text('Nueva lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Solo la segunda');
    await tester.ensureVisible(find.byKey(const ValueKey('playlist-song:b')));
    await tester.tap(find.byKey(const ValueKey('playlist-song:b')));
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(repository.savedSongIds, ['b']);
    expect((await repository.list()).single.songCount, 1);
  });

  testWidgets('select all then deselect one preserves queue order', (
    tester,
  ) async {
    await showScreen(tester, queue: selectionQueue);
    await tester.tap(find.text('Nueva lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Selección parcial');
    await tester.ensureVisible(find.text('Seleccionar todas'));
    await tester.tap(find.text('Seleccionar todas'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((tile) => tile.value == true),
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('playlist-song:b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playlist-song:b')));
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(repository.savedSongIds, ['a', 'c']);
    expect((await repository.list()).single.songCount, 2);
  });

  testWidgets('clear selection allows an empty list', (tester) async {
    await showScreen(tester, queue: selectionQueue);
    await tester.tap(find.text('Nueva lista'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Sin canciones');
    await tester.ensureVisible(find.text('Seleccionar todas'));
    await tester.tap(find.text('Seleccionar todas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Limpiar selección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar selección'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .every((tile) => tile.value == false),
      isTrue,
    );
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(repository.savedSongIds, isEmpty);
    expect((await repository.list()).single.songCount, 0);
  });

  testWidgets('deleting an empty list refreshes the list', (tester) async {
    await repository.save(name: 'Vacía');
    await showScreen(tester);
    await tester.tap(find.byTooltip('Opciones de Vacía'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(find.text('Vacía'), findsNothing);
    expect(
      find.text('No tienes listas. Crea tu primera lista.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'create empty, edit to add one song, then reopen with selection',
    (tester) async {
      await showScreen(tester, queue: selectionQueue);
      await tester.tap(find.text('Nueva lista'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Para después');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      final original = (await repository.list()).single;
      expect(original.songCount, 0);
      await tester.tap(find.text('Para después'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('playlist-song:b')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('playlist-song:b')));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('1 canción'), findsOneWidget);
      expect((await repository.list()).single.id, original.id);
      expect((await repository.songs(original.id)).single.id, 'b');
      await tester.tap(find.text('Para después'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('playlist-song:b')),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('playlist-song:a')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('editing preserves saved songs outside the current queue', (
    tester,
  ) async {
    await repository.save(name: 'Guardadas', songIds: ['b']);
    final original = (await repository.list()).single;
    await showScreen(tester, queue: [selectionQueue.first]);
    await tester.tap(find.text('Guardadas'));
    await tester.pumpAndSettle();
    expect(find.text('Segunda'), findsOneWidget);
    expect(find.text('Artista B'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('playlist-song:b')),
          )
          .value,
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('playlist-song:a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playlist-song:a')));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect((await repository.songs(original.id)).map((s) => s.id), ['b', 'a']);
    expect(find.text('2 canciones'), findsOneWidget);
    await tester.tap(find.text('Guardadas'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('playlist-song:b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playlist-song:b')));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();
    expect((await repository.songs(original.id)).single.id, 'a');
    expect((await repository.list()).single.id, original.id);
  });

  testWidgets('cancelling membership edits leaves the saved list unchanged', (
    tester,
  ) async {
    await repository.save(name: 'Sin cambios', songIds: ['a']);
    final original = (await repository.list()).single;
    await showScreen(tester, queue: selectionQueue);
    await tester.tap(find.text('Sin cambios'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Limpiar selección'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpiar selección'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await repository.songs(original.id)).single.id, 'a');
  });
}
