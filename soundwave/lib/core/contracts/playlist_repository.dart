import '../models/playlist.dart';

/// Persistence contract for playlists. Renaming always updates the same row:
/// the id never changes, and archiving is offered when a list is still in use.
abstract interface class PlaylistRepository {
  Future<List<PlaylistEntry>> loadPlaylists();

  Future<Playlist> create(String name);

  Future<void> rename({required String id, required String name});

  Future<void> setArchived({required String id, required bool archived});

  Future<void> delete(String id);
}
