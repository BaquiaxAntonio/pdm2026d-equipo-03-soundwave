import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/download_record.dart';
import '../../downloads/download_providers.dart';
import '../models/player_track.dart';
import 'player_provider.dart';

final playerFromDownloadsProvider = Provider<void>((ref) {
  List<(String, String?)>? previousFiles;
  ref.listen<AsyncValue<List<DownloadEntry>>>(downloadEntriesProvider, (
    previous,
    next,
  ) {
    next.whenData((entries) {
      final tracks = <PlayerTrack>[];
      for (final entry in entries) {
        if (entry.record.state == DownloadState.completed &&
            entry.record.localPath != null &&
            entry.song != null) {
          tracks.add(PlayerTrack.fromDownload(entry.song!, entry.record));
        }
      }
      final files = tracks.map((track) => (track.id, track.localPath)).toList();
      final previous = previousFiles;
      // Byte-progress events must not enqueue hundreds of redundant reloads.
      if (listEquals(previous, files)) return;
      previousFiles = files;
      ref.read(playerControllerProvider.notifier).load(tracks);
    });
  }, fireImmediately: true);
});
