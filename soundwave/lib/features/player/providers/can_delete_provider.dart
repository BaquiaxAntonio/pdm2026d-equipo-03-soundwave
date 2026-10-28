import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';

final playerCanDeleteOverrideProvider = Provider<void>((ref) {
  ref.listen(playerControllerProvider, (previous, next) {
    // coordination point: keep track of active song
  });
});

bool isSongCurrentlyPlaying(Ref ref, String songId) {
  final state = ref.read(playerControllerProvider);
  if (!state.isPlaying) return false;
  final track = state.tracks.isEmpty ? null : state.tracks[state.index];
  return track?.id == songId;
}
