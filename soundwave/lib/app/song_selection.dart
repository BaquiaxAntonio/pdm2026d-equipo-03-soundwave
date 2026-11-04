import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation_provider.dart';
import '../features/player/providers/player_provider.dart';

/// Stable-ID selection shared by Inicio, Buscar and the Reproductor.
///
/// It only carries the canonical `Song.id`; consumers resolve metadata, download
/// state and audio through the shared catalog/library providers.
final selectedSongIdProvider = NotifierProvider<SelectedSongNotifier, String?>(
  SelectedSongNotifier.new,
);

class SelectedSongNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String songId) => state = songId;
}

/// Opens [songId] in the Reproductor tab without duplicating navigation logic.
void openSongInPlayer(WidgetRef ref, String songId) {
  ref.read(selectedSongIdProvider.notifier).select(songId);
  ref.read(activeTabProvider.notifier).select(AppTab.player);
  ref.read(playerControllerProvider.notifier).openById(songId);
}
