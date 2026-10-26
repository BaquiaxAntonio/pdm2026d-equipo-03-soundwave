import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/features/downloads/download_providers.dart';

import '../../support/fake_repositories.dart';

class _SnapshotDownloadRepository extends FakeDownloadRepository {
  _SnapshotDownloadRepository(this.snapshot);

  final List<DownloadRecord> snapshot;

  @override
  Stream<List<DownloadRecord>> watchDownloads() => Stream.value(snapshot);
}

void main() {
  test(
    'the immutable filter triggers a reactive completed-only query',
    () async {
      final completed = completedRecord('song:completed');
      final queued = DownloadRecord(
        songId: 'song:queued',
        state: DownloadState.queued,
        bytesReceived: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final repository = _SnapshotDownloadRepository([completed, queued]);
      final container = ProviderContainer(
        overrides: [
          downloadSessionProvider.overrideWith(
            (ref) async => DownloadSession(repository, (_) async => null),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repository.dispose);
      final completedUpdate = Completer<List<DownloadEntry>>();
      final subscription = container.listen(downloadEntriesProvider, (_, next) {
        if (next.hasValue && next.value!.length == 1) {
          completedUpdate.complete(next.value!);
        }
      });
      addTearDown(subscription.close);

      final allEntries = await container.read(downloadEntriesProvider.future);
      expect(allEntries.map((entry) => entry.record.songId), [
        'song:completed',
        'song:queued',
      ]);
      final initialFilter = container.read(downloadFilterProvider);
      expect(initialFilter.completedOnly, isFalse);

      container.read(downloadFilterProvider.notifier).showCompleted();
      final completedEntries = await completedUpdate.future;

      expect(completedEntries, hasLength(1));
      expect(completedEntries.single.record.songId, completed.songId);
      expect(initialFilter.completedOnly, isFalse);
      expect(container.read(downloadFilterProvider).completedOnly, isTrue);
    },
  );
}
