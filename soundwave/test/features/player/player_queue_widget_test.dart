import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/downloads/download_store.dart';
import 'package:soundwave/features/player/data/player_queue_repository.dart';
import 'package:soundwave/features/player/models/player_queue_filter.dart';
import 'package:soundwave/features/player/player_queue_view.dart';
import 'package:soundwave/features/player/player_screen.dart';
import 'package:soundwave/features/player/providers/player_queue_provider.dart';
import 'package:soundwave/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/fake_repositories.dart';

class ControlledDownloadRepository extends FakeDownloadRepository {
  final requested = <Song>[];
  Completer<void>? completion;
  bool fail = false;

  @override
  Future<void> enqueue(Song song) async {
    requested.add(song);
    await completion?.future;
    if (fail) throw StateError('download failed');
    await super.enqueue(song);
  }
}

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
  PlayerQueueRepository repository, {
  Widget child = const PlayerQueueView(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerQueueRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> showPlayer(
  WidgetTester tester,
  PlayerQueueRepository repository, {
  DownloadSession? downloadSession,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerQueueRepositoryProvider.overrideWith((ref) async => repository),
        downloadSessionProvider.overrideWith((ref) async => downloadSession),
        dataModeProvider.overrideWithValue(
          downloadSession == null ? DataMode.demo : DataMode.localSqlite,
        ),
      ],
      child: const MaterialApp(home: PlayerScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el aviso de bloqueo desaparece después de cinco segundos', (
    tester,
  ) async {
    await showPlayer(tester, ControlledQueueRepository());
    await tester.scrollUntilVisible(
      find.text('Bloquear canción'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bloquear canción'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Deshacer'), findsNothing);
    expect(find.text('Bloqueadas en sesión: 1'), findsOneWidget);
  });

  testWidgets('la X cierra el aviso conservando el bloqueo', (tester) async {
    await showPlayer(tester, ControlledQueueRepository());
    await tester.scrollUntilVisible(
      find.text('Bloquear canción'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bloquear canción'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Bloqueadas en sesión: 1'), findsOneWidget);
  });

  testWidgets('el ícono agrega a Descargas demo sin duplicar la canción', (
    tester,
  ) async {
    await showPlayer(tester, ControlledQueueRepository());
    await tester.ensureVisible(find.byTooltip('Descargar canción'));
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    expect(
      find.text('«Estudio tranquilo» agregada a Descargas (modo demo).'),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerScreen)),
    );
    final downloaded = container
        .read(downloadStoreProvider)
        .singleWhere((song) => song.id == 'p1');
    expect(downloaded.title, 'Estudio tranquilo');
    expect(downloaded.artist, 'SoundWave Mock');
    expect(downloaded.durationSeconds, 180);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    expect(
      find.text('Esta canción ya está en Descargas (modo demo).'),
      findsOneWidget,
    );
    expect(
      container.read(downloadStoreProvider).where((song) => song.id == 'p1'),
      hasLength(1),
    );
  });

  testWidgets(
    'la canción en reproducción aparece en Descargas al cambiar de pestaña',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataModeProvider.overrideWithValue(DataMode.demo),
            playerQueueRepositoryProvider.overrideWith(
              (ref) async => ControlledQueueRepository(),
            ),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reproductor'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Siguiente'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Reproducir'));
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byTooltip('Descargar canción'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Descargar canción'));
      await tester.pumpAndSettle();
      expect(
        find.text('«Viaje en bus» agregada a Descargas (modo demo).'),
        findsOneWidget,
      );
      await tester.tap(find.text('Descargas'));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('p2'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(of: row, matching: find.text('Viaje en bus')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('SoundWave Mock')),
        findsOneWidget,
      );
      await tester.tap(find.text('Reproductor'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descargas'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('descarga la canción actual y evita solicitudes duplicadas', (
    tester,
  ) async {
    final downloads = ControlledDownloadRepository()
      ..completion = Completer<void>();
    addTearDown(downloads.dispose);
    final resolvedIds = <String>[];
    await showPlayer(
      tester,
      ControlledQueueRepository(),
      downloadSession: DownloadSession(downloads, (id) async {
        resolvedIds.add(id);
        return Song(
          id: id,
          title: 'Audio de prueba',
          artist: 'Artista',
          provider: 'fixture',
          sourceId: id,
        );
      }),
    );
    await tester.ensureVisible(find.byTooltip('Siguiente'));
    await tester.tap(find.byTooltip('Siguiente'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Descargar canción'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    final busyButton = find.byWidgetPredicate(
      (widget) =>
          widget is IconButton && widget.tooltip == 'Solicitando descarga',
    );
    expect(tester.widget<IconButton>(busyButton).onPressed, isNull);
    expect(resolvedIds, ['p2']);
    expect(downloads.requested.single.id, 'p2');
    downloads.completion!.complete();
    await tester.pumpAndSettle();
    expect((await downloads.findBySongId('p2'))?.songId, 'p2');
    expect(
      find.text('Descarga solicitada. Puedes ver su estado en Descargas.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    expect(downloads.requested, hasLength(1));
  });

  testWidgets('una canción de prueba no se presenta como descargada', (
    tester,
  ) async {
    final downloads = ControlledDownloadRepository();
    addTearDown(downloads.dispose);
    await showPlayer(
      tester,
      ControlledQueueRepository(),
      downloadSession: DownloadSession(
        downloads,
        (id) async => Song(
          id: id,
          title: 'Demo',
          artist: 'Demo',
          provider: 'player-demo',
          sourceId: id,
        ),
      ),
    );
    await tester.ensureVisible(find.byTooltip('Descargar canción'));
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Esta canción de prueba no tiene una fuente de audio descargable.',
      ),
      findsOneWidget,
    );
    expect(downloads.requested, isEmpty);
  });

  testWidgets('un error de descarga permite volver a intentar', (tester) async {
    final downloads = ControlledDownloadRepository()..fail = true;
    addTearDown(downloads.dispose);
    await showPlayer(
      tester,
      ControlledQueueRepository(),
      downloadSession: DownloadSession(
        downloads,
        (id) async => Song(
          id: id,
          title: 'Audio',
          artist: 'Artista',
          provider: 'fixture',
          sourceId: id,
        ),
      ),
    );
    await tester.ensureVisible(find.byTooltip('Descargar canción'));
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo descargar la canción. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Descargar canción'), findsOneWidget);
    downloads.fail = false;
    await tester.tap(find.byTooltip('Descargar canción'));
    await tester.pumpAndSettle();
    expect(downloads.records.single.songId, 'p1');
  });

  testWidgets('Bloquear ofrece Deshacer y recupera canción, tiempo y pausa', (
    tester,
  ) async {
    await showPlayer(tester, ControlledQueueRepository());
    await tester.scrollUntilVisible(
      find.byType(Slider),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    tester.widget<Slider>(find.byType(Slider)).onChanged!(73);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Bloquear canción'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Bloquear canción'));
    await tester.pumpAndSettle();

    expect(find.text('Estudio tranquilo: canción bloqueada'), findsOneWidget);
    expect(find.text('Bloqueadas en sesión: 1'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('Bloqueadas en sesión: 0'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(Slider),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1:13 / 3:00'), findsOneWidget);
    expect(find.byTooltip('Reproducir'), findsOneWidget);
  });

  testWidgets(
    'Deshacer funciona tras bloquear la última canción en reproducción',
    (tester) async {
      final repository = ControlledQueueRepository();
      final entries = await repository.list(const PlayerQueueFilter());
      for (final entry in entries.skip(1)) {
        await repository.remove(entry);
      }
      await showPlayer(tester, repository);
      await tester.scrollUntilVisible(
        find.byType(Slider),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      tester.widget<Slider>(find.byType(Slider)).onChanged!(42);
      await tester.pump();
      await tester.ensureVisible(find.byTooltip('Reproducir'));
      await tester.tap(find.byTooltip('Reproducir'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Bloquear canción'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Bloquear canción'));
      await tester.pumpAndSettle();

      expect(
        find.text('No hay canciones disponibles para reproducir.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay canciones disponibles para reproducir.'),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.byType(Slider),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('0:42 / 3:00'), findsOneWidget);
      expect(find.byTooltip('Pausar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('el filtro cambia las filas y muestra vacío sin recargar', (
    tester,
  ) async {
    final repository = ControlledQueueRepository();
    await showQueue(tester, repository);
    expect(find.byType(Dismissible), findsNWidgets(3));
    await tester.enterText(find.byType(TextFormField), 'VIAJE');
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsOneWidget);
    expect(find.text('Viaje en bus'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'sin coincidencias');
    await tester.pumpAndSettle();
    expect(find.text('No hay canciones para este filtro.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'soundwave');
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsNWidgets(3));
  });

  testWidgets(
    'borrar espera al repositorio y Deshacer restaura ID, datos y orden',
    (tester) async {
      final repository = ControlledQueueRepository();
      final original = await repository.list(const PlayerQueueFilter());
      repository.deletion = Completer<void>();
      await showQueue(tester, repository);
      await tester.drag(
        find.byKey(const ValueKey('p2')),
        const Offset(-600, 0),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
      expect(find.text('Deshacer'), findsNothing);
      repository.deletion!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p2')), findsNothing);
      expect((await repository.list(const PlayerQueueFilter())).length, 2);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
      final restored = await repository.list(const PlayerQueueFilter());
      expect(restored.map((e) => e.song.id), original.map((e) => e.song.id));
      expect(restored[1].song, same(original[1].song));
      expect(restored[1].position, original[1].position);
    },
  );

  testWidgets('si falla borrar la fila permanece', (tester) async {
    final repository = ControlledQueueRepository()..failRemove = true;
    await showQueue(tester, repository);
    await tester.drag(find.byKey(const ValueKey('p2')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    expect(
      find.text('No se pudo quitar la canción. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('error permite Reintentar', (tester) async {
    final repository = ControlledQueueRepository()..failLoad = true;
    await showQueue(tester, repository);
    expect(find.text('No se pudo cargar la cola.'), findsOneWidget);
    repository.failLoad = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsNWidgets(3));
  });

  testWidgets(
    'el reproductor conserva los controles y la cola al quedar vacía',
    (tester) async {
      final repository = ControlledQueueRepository();
      await showPlayer(tester, repository);
      expect(find.text('0:00 / 3:00'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Siguiente'));
      await tester.tap(find.byTooltip('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('0:00 / 3:30'), findsOneWidget);
      for (final id in ['p1', 'p2', 'p3']) {
        final row = find.byKey(ValueKey(id));
        await Scrollable.ensureVisible(tester.element(row), alignment: 0.4);
        await tester.drag(row, const Offset(-600, 0));
        await tester.pumpAndSettle();
        if (id != 'p3') {
          ScaffoldMessenger.of(
            tester.element(find.byType(PlayerQueueView)),
          ).removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('La cola está vacía.'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(
        find.text('No hay canciones disponibles para reproducir.'),
        findsNothing,
      );
      await tester.scrollUntilVisible(find.byKey(const ValueKey('p3')), 200);
      expect(find.byKey(const ValueKey('p3')), findsOneWidget);
    },
  );

  test(
    'SQLite conserva eliminación y restauración al cerrar y abrir',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('player-queue-');
      final path = '${directory.path}/queue.db';
      Future<Database> open() => databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => createDatabaseSchema(db),
        ),
      );
      var database = await open();
      try {
        var repository = SqlitePlayerQueueRepository(database);
        await repository.initialize();
        final original = await repository.list(const PlayerQueueFilter());
        final removed = original[1];
        await repository.remove(removed);
        await database.close();
        database = await open();
        repository = SqlitePlayerQueueRepository(database);
        await repository.initialize();
        expect(
          (await repository.list(
            const PlayerQueueFilter(),
          )).map((e) => e.song.id),
          [original.first.song.id, original.last.song.id],
        );
        await repository.restore(removed);
        await database.close();
        database = await open();
        repository = SqlitePlayerQueueRepository(database);
        await repository.initialize();
        final restored = await repository.list(const PlayerQueueFilter());
        expect(restored.map((e) => e.song.id), original.map((e) => e.song.id));
        expect(restored[1].song.title, removed.song.title);
        expect(restored[1].song.artist, removed.song.artist);
        expect(restored[1].song.durationSeconds, removed.song.durationSeconds);
        expect(restored[1].position, removed.position);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
