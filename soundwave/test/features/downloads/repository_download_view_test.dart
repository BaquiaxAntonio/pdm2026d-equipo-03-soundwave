import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/download_repository.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/downloads/download_screen.dart';
import 'package:soundwave/main.dart';

const song = Song(
  id: 'fixture:real',
  title: 'Audio persistido',
  artist: 'Fixture',
  provider: 'fixture',
  sourceId: 'real',
);

class WidgetRepository implements DownloadRepository {
  DownloadState state = DownloadState.completed;
  final changes = StreamController<List<DownloadRecord>>.broadcast(sync: true);
  DateTime? deadline;
  bool failRemoval = false;
  bool failUndo = false;
  List<DownloadRecord> snapshot() => [
    DownloadRecord(
      songId: song.id,
      state: state,
      bytesReceived: 48,
      totalBytes: 48,
      localPath: 'fixture.wav',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      deletionDeadline: deadline,
    ),
  ];
  @override
  Stream<List<DownloadRecord>> watchDownloads() => Stream.multi((listener) {
    final subscription = changes.stream.listen(
      listener.add,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
    listener.add(snapshot());
  });
  @override
  Future<DownloadRecord?> findBySongId(String songId) async => snapshot().first;
  @override
  Future<void> enqueue(Song song) async {}
  @override
  Future<void> retry(String songId) async {
    state = DownloadState.downloading;
    changes.add(snapshot());
  }

  @override
  Future<void> requestRemoval(
    String songId, {
    required DateTime undoUntil,
  }) async {
    if (failRemoval) throw StateError('storage');
    state = DownloadState.pendingDeletion;
    deadline = undoUntil;
    changes.add(snapshot());
  }

  @override
  Future<void> undoRemoval(String songId) async {
    if (failUndo) throw StateError('storage');
    state = DownloadState.completed;
    deadline = null;
    changes.add(snapshot());
  }
}

class ConsecutiveRepository extends WidgetRepository {
  final states = <String, DownloadState>{
    'first': DownloadState.completed,
    'second': DownloadState.completed,
  };

  @override
  List<DownloadRecord> snapshot() => [
    for (final entry in states.entries)
      DownloadRecord(
        songId: entry.key,
        state: entry.value,
        bytesReceived: 48,
        localPath: '${entry.key}.wav',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        deletionDeadline: deadline,
      ),
  ];

  @override
  Future<void> requestRemoval(
    String songId, {
    required DateTime undoUntil,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    states[songId] = DownloadState.pendingDeletion;
    deadline = undoUntil;
    changes.add(snapshot());
  }

  @override
  Future<void> undoRemoval(String songId) async {
    states[songId] = DownloadState.completed;
    changes.add(snapshot());
  }
}

void main() {
  late WidgetRepository repository;
  setUp(() {
    repository = WidgetRepository();
  });
  tearDown(() => repository.changes.close());
  Widget app({bool shell = false}) => ProviderScope(
    overrides: [
      dataModeProvider.overrideWithValue(DataMode.localSqlite),
      downloadUndoDurationProvider.overrideWithValue(
        const Duration(minutes: 1),
      ),
      downloadSessionProvider.overrideWith(
        (ref) async => DownloadSession(repository, (_) async => song),
      ),
    ],
    child: shell ? const MyApp() : const MaterialApp(home: DownloadScreen()),
  );

  testWidgets('repository screen removes and undoes through the contract', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsOneWidget);
    expect(find.text('Descargada'), findsOneWidget);
    expect(find.textContaining('Datos simulados'), findsNothing);
    final original = repository.snapshot().single.toMap();
    expect(
      tester.widget<Dismissible>(find.byType(Dismissible)).key,
      ValueKey(song.id),
    );
    await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsNothing);
    expect(repository.state, DownloadState.pendingDeletion);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsOneWidget);
    expect(repository.state, DownloadState.completed);
    expect(repository.snapshot().single.toMap(), original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('failed swipe keeps the record and reports the failure', (
    tester,
  ) async {
    repository.failRemoval = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final original = repository.snapshot().single.toMap();
    await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsOneWidget);
    expect(repository.snapshot().single.toMap(), original);
    expect(find.textContaining('No se pudo completar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed undo retains persistent deletion and permits retry', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
    await tester.pumpAndSettle();
    repository.failUndo = true;
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(repository.state, DownloadState.pendingDeletion);
    expect(find.text('Audio persistido'), findsNothing);
    expect(find.textContaining('No se pudo completar'), findsOneWidget);
    repository.failUndo = false;
    await tester.tap(
      find.descendant(
        of: find.byType(TextButton),
        matching: find.textContaining('Deshacer'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsOneWidget);
    expect(repository.snapshot(), hasLength(1));
  });

  testWidgets(
    'consecutive swipes retain independent undo under the active filter',
    (tester) async {
      final multiple = ConsecutiveRepository();
      addTearDown(multiple.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataModeProvider.overrideWithValue(DataMode.localSqlite),
            downloadUndoDurationProvider.overrideWithValue(
              const Duration(minutes: 1),
            ),
            downloadSessionProvider.overrideWith(
              (ref) async => DownloadSession(multiple, (_) async => null),
            ),
          ],
          child: const MaterialApp(home: DownloadScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Completadas'));
      await tester.pumpAndSettle();
      for (final id in ['first', 'second']) {
        await tester.drag(find.byKey(ValueKey(id)), const Offset(-700, 0));
        await tester.pumpAndSettle();
        expect(multiple.states[id], DownloadState.pendingDeletion);
        expect(find.byKey(ValueKey(id)), findsNothing);
      }
      expect(find.text('No hay descargas completadas.'), findsOneWidget);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('second')), findsOneWidget);
      expect(find.byKey(const ValueKey('first')), findsNothing);
      await tester.tap(find.text('Deshacer eliminación de first'));
      await tester.pumpAndSettle();
      expect(find.byType(Dismissible), findsNWidgets(2));
      expect(multiple.snapshot().map((record) => record.songId).toSet(), {
        'first',
        'second',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('navigation retains repository state between tabs', (
    tester,
  ) async {
    await tester.pumpWidget(app(shell: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descargas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar Audio persistido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descargas'));
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsNothing);
    expect(find.textContaining('Deshacer eliminación'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('repository screen reports loading failure with retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          downloadEntriesProvider.overrideWith(
            (ref) => Stream.error(StateError('storage')),
          ),
        ],
        child: const MaterialApp(home: DownloadScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('No se pudieron cargar tus descargas.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
