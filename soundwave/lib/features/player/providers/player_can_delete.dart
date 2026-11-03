import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'player_provider.dart';

class PlayerDeletionGuard {
  PlayerDeletionGuard(this._ref);
  final Ref _ref;

  Future<bool> canDelete(String songId) =>
      _ref.read(playerControllerProvider.notifier).releaseForDeletion(songId);

  Future<void> ensureReleased(String songId) async {
    await canDelete(songId);
  }
}

final playerDeletionGuardProvider = Provider<PlayerDeletionGuard>(
  PlayerDeletionGuard.new,
);
