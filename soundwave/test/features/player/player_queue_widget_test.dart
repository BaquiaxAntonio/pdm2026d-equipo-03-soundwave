import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/player/data/player_queue_repository.dart';
import 'package:soundwave/features/player/models/player_queue_filter.dart';
import 'package:soundwave/features/player/player_queue_view.dart';
import 'package:soundwave/features/player/player_screen.dart';
import 'package:soundwave/features/player/providers/player_from_downloads_provider.dart';
import 'package:soundwave/features/player/providers/player_provider.dart';
import 'package:soundwave/features/player/providers/player_queue_provider.dart';
import '../../support/fake_repositories.dart';
import 'fake_playback_controller.dart';

class ControlledQueueRepository extends MemoryPlayerQueueRepository {
  bool failLoad = false;
  bool failRemove = false;
  Completer<void>? deletion;
  @override
  Future<List<PlayerQueueEntry>> list(PlayerQueueFilter filter) {
    if (failLoad) throw StateError('load failed');
    return super.list(filter);
  }

  @override
  Future<void> remove(PlayerQueueEntry entry) async {
    if (failRemove) throw StateError('delete failed');
    await deletion?.future;
    await super.remove(entry);
  }
}

Future<void> showQueue(
  WidgetTester tester,
  PlayerQueueRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerQueueRepositoryProvider.overrideWith((_) async => repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: PlayerQueueView())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pantalla, controles y cola leen el mismo controlador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = FakePlaybackController();
    final container = ProviderContainer(
      overrides: [
        playerFromDownloadsProvider.overrideWith((_) {}),
        playbackEngineProvider.overrideWithValue(engine),
        playbackPreferencesProvider.overrideWith(
          (_) async => FakePlaybackPreferencesRepository(),
        ),
        playbackSourceProvider.overrideWithValue(
          (track) async => Uri.file('/private/${track.localPath}'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    await controller.load(testTracks);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlayerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pausar'), findsOneWidget);
    engine.position = const Duration(seconds: 37);
    engine.emit();
    await tester.pump();
    expect(find.text('0:37'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Segunda');
    await tester.pumpAndSettle();
    expect(
      container.read(playerControllerProvider).currentTrack?.id,
      testTracks.first.id,
    );
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    expect(controller.currentTrack?.id, testTracks.last.id);
    expect(find.text('En reproducción · Artista'), findsOneWidget);
    await tester.tap(find.text('Bloquear canción'));
    await tester.pumpAndSettle();
    expect(container.read(playerControllerProvider).blockedIds, {
      testTracks.last.id,
    });
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(container.read(playerControllerProvider).blockedIds, isEmpty);
  });

  testWidgets('vacío permite ir a buscar sin inventar canciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [playerFromDownloadsProvider.overrideWith((_) {})],
        child: const MaterialApp(home: PlayerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No hay canciones disponibles para reproducir.'),
      findsOneWidget,
    );
    expect(find.text('Buscar música libre'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('filtro de selección de listas conserva IDs y muestra vacío', (
    tester,
  ) async {
    await showQueue(tester, ControlledQueueRepository());
    expect(find.byType(Dismissible), findsNWidgets(3));
    await tester.enterText(find.byType(TextFormField), 'VIAJE');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'sin coincidencias');
    await tester.pumpAndSettle();
    expect(find.text('No hay canciones para este filtro.'), findsOneWidget);
  });

  testWidgets('borrar espera al repositorio y Deshacer restaura ID y orden', (
    tester,
  ) async {
    final repository = ControlledQueueRepository();
    final original = await repository.list(const PlayerQueueFilter());
    repository.deletion = Completer<void>();
    await showQueue(tester, repository);
    await tester.drag(find.byKey(const ValueKey('p2')), const Offset(-600, 0));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    repository.deletion!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p2')), findsNothing);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    final restored = await repository.list(const PlayerQueueFilter());
    expect(restored.map((e) => e.song.id), original.map((e) => e.song.id));
    expect(restored[1].position, original[1].position);
  });

  testWidgets('si falla borrar la fila permanece', (tester) async {
    await showQueue(tester, ControlledQueueRepository()..failRemove = true);
    await tester.drag(find.byKey(const ValueKey('p2')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    expect(
      find.text('No se pudo quitar la canción. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('error de catálogo permite Reintentar', (tester) async {
    final repository = ControlledQueueRepository()..failLoad = true;
    await showQueue(tester, repository);
    expect(find.text('No se pudo cargar la cola.'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsNWidgets(3));
  });
}
