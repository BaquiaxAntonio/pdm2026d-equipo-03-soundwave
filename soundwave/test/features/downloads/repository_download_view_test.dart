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
    state = DownloadState.pendingDeletion;
    deadline = undoUntil;
    changes.add(snapshot());
  }

  @override
  Future<void> undoRemoval(String songId) async {
    state = DownloadState.completed;
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
    await tester.tap(find.byTooltip('Eliminar Audio persistido'));
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsNothing);
    expect(repository.state, DownloadState.pendingDeletion);
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(find.text('Audio persistido'), findsOneWidget);
    expect(repository.state, DownloadState.completed);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

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
