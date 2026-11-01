import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/playlist_repository.dart';
import '../../core/database/soundwave_database.dart';
import '../../core/models/playlist.dart';
import 'data/sqlite_playlist_repository.dart';

/// Retries are disabled so a failure stays visible until the user asks for it
/// again instead of looping silently.
final playlistRepositoryProvider = FutureProvider<PlaylistRepository>((
  ref,
) async {
  final database = await ref.watch(soundwaveDatabaseProvider.future);
  return SqlitePlaylistRepository(database: database);
}, retry: (_, _) => null);

final playlistEntriesProvider = FutureProvider<List<PlaylistEntry>>((
  ref,
) async {
  final repository = await ref.watch(playlistRepositoryProvider.future);
  return repository.loadPlaylists();
}, retry: (_, _) => null);
