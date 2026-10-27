import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/soundwave_database.dart';
import '../../../core/providers/data_mode_provider.dart';
import '../data/player_queue_repository.dart';
import '../models/player_queue_filter.dart';

final playerQueueRepositoryProvider = FutureProvider<PlayerQueueRepository>((
  ref,
) async {
  if (ref.watch(dataModeProvider) == DataMode.demo) {
    return MemoryPlayerQueueRepository();
  }
  final repository = SqlitePlayerQueueRepository(
    await ref.watch(soundwaveDatabaseProvider.future),
  );
  await repository.initialize();
  return repository;
});

final playerQueueFilterProvider =
    NotifierProvider<PlayerQueueFilterNotifier, PlayerQueueFilter>(
      PlayerQueueFilterNotifier.new,
    );

class PlayerQueueFilterNotifier extends Notifier<PlayerQueueFilter> {
  @override
  PlayerQueueFilter build() => const PlayerQueueFilter();

  void setText(String text) {
    if (state.text != text) state = PlayerQueueFilter(text: text);
  }
}

final playerQueueProvider = FutureProvider<List<PlayerQueueEntry>>((ref) async {
  final filter = ref.watch(playerQueueFilterProvider);
  final repository = await ref.watch(playerQueueRepositoryProvider.future);
  return repository.list(filter);
});

final fullPlayerQueueProvider = FutureProvider<List<PlayerQueueEntry>>((
  ref,
) async {
  final repository = await ref.watch(playerQueueRepositoryProvider.future);
  return repository.list(const PlayerQueueFilter());
});
