import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';

class PlayerDeletionGuard {
  PlayerDeletionGuard(this._ref);

  final Ref _ref;

  Future<bool> canDelete(String songId) async {
    final state = _ref.read(playerControllerProvider);
    if (state.isPlaying && state.tracks.isNotEmpty) {
      final current = state.tracks[state.index];
      if (current.id == songId) {
        return false;
      }
    }
    return true;
  }

  Future<void> ensureReleased(String songId) async {
    final state = _ref.read(playerControllerProvider);
    if (state.tracks.isNotEmpty) {
      final current = state.tracks[state.index];
      if (current.id == songId && state.isPlaying) {
        final notifier = _ref.read(playerControllerProvider.notifier);
        await notifier.pause();
      }
    }
  }
}

final playerDeletionGuardProvider = Provider<PlayerDeletionGuard>((ref) {
  return PlayerDeletionGuard(ref);
});
