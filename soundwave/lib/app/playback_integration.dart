import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/player/providers/player_from_downloads_provider.dart';

/// Mounted once by MainShell. Download filters never modify the audio queue.
final playbackIntegrationProvider = Provider<void>((ref) {
  ref.watch(playerFromDownloadsProvider);
});
