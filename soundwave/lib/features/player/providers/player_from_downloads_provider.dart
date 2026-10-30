import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/download_record.dart';
import '../../downloads/download_providers.dart';
import '../models/player_track.dart';
import 'player_provider.dart';

final playerFromDownloadsProvider = Provider<void>((ref) {
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
          tracks.add(
            PlayerTrack.fromDownload(entry.song!, entry.record),
          );
        }
      }
      ref.read(playerControllerProvider.notifier).load(tracks);
    });
  });
});
