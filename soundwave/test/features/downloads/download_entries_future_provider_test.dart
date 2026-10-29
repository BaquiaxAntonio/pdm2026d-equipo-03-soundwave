import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/downloads/download_providers.dart';

import '../../support/fake_repositories.dart';

const _song = Song(
  id: 'fixture:async',
  title: 'Carga asíncrona',
  artist: 'SoundWave',
  provider: 'fixture',
  sourceId: 'async',
);

class _FailingDownloadRepository extends FakeDownloadRepository {
  int loadAttempts = 0;

  @override
  Future<List<DownloadRecord>> loadDownloads() async {
    loadAttempts++;
    throw StateError('storage unavailable');
  }
}

void main() {
  ProviderContainer containerFor(FakeDownloadRepository repository) =>
      ProviderContainer(
        overrides: [
          downloadSessionProvider.overrideWith(
            (ref) async => DownloadSession(repository, (_) async => _song),
          ),
        ],
      );

  test('loads a single download snapshot through a FutureProvider', () async {
    final repository = FakeDownloadRepository();
    await repository.enqueue(_song);
    final container = containerFor(repository);
    addTearDown(container.dispose);
    addTearDown(repository.dispose);

    final entries = await container.read(downloadEntriesFutureProvider.future);

    expect(entries, hasLength(1));
    expect(entries.single.record.songId, _song.id);
    expect(entries.single.song, _song);
  });

  test(
    'keeps a repository failure as an error without an automatic retry',
    () async {
      final repository = _FailingDownloadRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      addTearDown(repository.dispose);

      await expectLater(
        container.read(downloadEntriesFutureProvider.future),
        throwsStateError,
      );

      expect(repository.loadAttempts, 1);
    },
  );
}
