import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/player/providers/player_playlists_provider.dart';
import '../features/playlists/playlist_providers.dart';

/// Both screens read the same playlists table. Refresh their snapshots only
/// after a successful mutation, without recreating either repository.
void invalidatePlaylistViews(WidgetRef ref) {
  ref.invalidate(playlistEntriesProvider);
  ref.invalidate(playerPlaylistsProvider);
}
