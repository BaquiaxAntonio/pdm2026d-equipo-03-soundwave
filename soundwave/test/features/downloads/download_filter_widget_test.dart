import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/downloads/download_screen.dart';

import '../../support/fake_repositories.dart';

class FilterRepository extends FakeDownloadRepository {
  List<DownloadRecord> snapshot = [
    completedRecord('completed'),
    DownloadRecord(
      songId: 'queued',
      state: DownloadState.queued,
      bytesReceived: 0,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Stream<List<DownloadRecord>> watchDownloads() => Stream.value(snapshot);
}

void main() {
  testWidgets(
    'filter changes the list automatically and shows filtered empty state',
    (tester) async {
      final repository = FilterRepository();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataModeProvider.overrideWithValue(DataMode.localSqlite),
            downloadSessionProvider.overrideWith(
              (ref) async => DownloadSession(repository, (_) async => null),
            ),
          ],
          child: const MaterialApp(home: DownloadScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('queued'), findsOneWidget);
      await tester.tap(find.text('Completadas'));
      await tester.pumpAndSettle();
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('queued'), findsNothing);
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('queued'), findsOneWidget);
      repository.snapshot = [repository.snapshot.last];
      await tester.tap(find.text('Completadas'));
      await tester.pumpAndSettle();
      expect(find.text('No hay descargas completadas.'), findsOneWidget);
      expect(find.text('Recargar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
