import '../../../core/contracts/playback_preferences_repository.dart';
import '../../../core/database/blocked_song_dao.dart';

class SqlitePlaybackPreferencesRepository
    implements PlaybackPreferencesRepository {
  SqlitePlaybackPreferencesRepository(this._dao);

  final BlockedSongDao _dao;

  @override
  Future<Set<String>> blockedSongIds(String collectionId) =>
      _dao.songIds(collectionId);

  @override
  Future<void> setBlocked({
    required String collectionId,
    required String songId,
    required bool blocked,
  }) async {
    await _dao.setBlocked(
      playlistId: collectionId,
      songId: songId,
      blocked: blocked,
    );
  }
}
