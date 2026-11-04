import '../models/playlist.dart';
import '../models/song.dart';

/// Persistence contract for playlists. Renaming always updates the same row:
/// the id never changes, and archiving is offered when a list is still in use.
abstract interface class PlaylistRepository {
  Future<List<PlaylistEntry>> loadPlaylists();

  Future<Playlist> create(String name);

  Future<void> rename({required String id, required String name});

  Future<void> setArchived({required String id, required bool archived});

  Future<void> delete(String id);

  Future<List<Song>> loadSongs(String playlistId);

  /// Appends the song at the end. Returns false when it was already in the
  /// list; saving the song metadata first keeps the playlist_songs FK valid.
  Future<bool> addSong({required String playlistId, required Song song});

  Future<void> removeSong({required String playlistId, required String songId});

  /// Adds or removes [song] from the reserved favorites playlist.
  Future<void> setFavorite({required Song song, required bool favorite});
}
