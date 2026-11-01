import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/soundwave_database.dart';
import '../../../core/providers/data_mode_provider.dart';
import '../data/player_playlist_repository.dart';
import '../models/player_playlist.dart';

final playerPlaylistRepositoryProvider =
    FutureProvider<PlayerPlaylistRepository>((ref) async {
      if (ref.watch(dataModeProvider) == DataMode.demo) {
        return MemoryPlayerPlaylistRepository();
      }
      return SqlitePlayerPlaylistRepository(
        await ref.watch(soundwaveDatabaseProvider.future),
      );
    });

final playerPlaylistsProvider = FutureProvider<List<PlayerPlaylist>>((
  ref,
) async {
  final repository = await ref.watch(playerPlaylistRepositoryProvider.future);
  return repository.list();
});
