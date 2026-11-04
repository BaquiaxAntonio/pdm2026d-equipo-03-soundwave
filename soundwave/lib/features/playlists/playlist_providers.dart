import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/contracts/playlist_repository.dart';
import '../../core/database/song_dao.dart';
import '../../core/database/soundwave_database.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
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

final playlistSongsProvider = FutureProvider.family<List<Song>, String>((
  ref,
  playlistId,
) async {
  final repository = await ref.watch(playlistRepositoryProvider.future);
  return repository.loadSongs(playlistId);
}, retry: (_, _) => null);

final favoriteSongIdsProvider = FutureProvider<Set<String>>((ref) async {
  final songs = await ref.watch(
    playlistSongsProvider(favoritesPlaylistId).future,
  );
  return {for (final song in songs) song.id};
}, retry: (_, _) => null);

/// Every song the app already knows (downloads plus saved search results), so
/// a list can be filled without going back to the search screen.
final catalogSongsProvider = FutureProvider<List<Song>>((ref) async {
  final database = await ref.watch(soundwaveDatabaseProvider.future);
  return SongDao(database).search('');
}, retry: (_, _) => null);
