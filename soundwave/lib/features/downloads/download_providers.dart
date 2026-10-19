import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/download_repository.dart';
import '../../core/models/download_record.dart';
import '../../core/models/song.dart';
import '../../core/providers/data_mode_provider.dart';
import 'data/download_input.dart';
import 'data/download_factory_stub.dart'
    if (dart.library.io) 'data/download_factory_native.dart'
    as platform;

class DownloadSession {
  const DownloadSession(this.repository, this.findSong);
  final DownloadRepository repository;
  final Future<Song?> Function(String id) findSong;
}

class DownloadEntry {
  const DownloadEntry(this.record, this.song);
  final DownloadRecord record;
  final Song? song;
}

/// API/search supplies the resolver when a permitted provider is agreed.
final openDownloadProvider = Provider<OpenDownload>(
  (ref) => platform.unavailable,
);

/// Safe default: retain pending files until the audio owner confirms release.
final canDeleteAudioProvider = Provider<Future<bool> Function(String)>(
  (ref) =>
      (_) async => false,
);

/// Configurable UX interval, matching the existing SnackBar's default duration.
final downloadUndoDurationProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 4),
);

final downloadSessionProvider = FutureProvider<DownloadSession?>((ref) async {
  if (ref.watch(dataModeProvider) == DataMode.demo) return null;
  return platform.createSession(ref);
}, retry: (_, _) => null);

/// Snapshot used by the asynchronous-state screen. Explicitly disable
/// Riverpod's automatic retry so an error remains visible until the user taps
/// the UI's retry action.
final downloadEntriesFutureProvider = FutureProvider<List<DownloadEntry>>((
  ref,
) async {
  final session = await ref.watch(downloadSessionProvider.future);
  if (session == null) return [];
  final records = await session.repository.loadDownloads();
  return Future.wait(
    records.map(
      (record) async =>
          DownloadEntry(record, await session.findSong(record.songId)),
    ),
  );
}, retry: (_, _) => null);

/// Live updates remain available for the current downloads management view.
/// The four-state screen will use [downloadEntriesFutureProvider].
final downloadEntriesProvider = StreamProvider<List<DownloadEntry>>((
  ref,
) async* {
  final session = await ref.watch(downloadSessionProvider.future);
  if (session == null) {
    yield [];
    return;
  }
  await for (final records in session.repository.watchDownloads()) {
    yield await Future.wait(
      records.map(
        (record) async =>
            DownloadEntry(record, await session.findSong(record.songId)),
      ),
    );
  }
});
