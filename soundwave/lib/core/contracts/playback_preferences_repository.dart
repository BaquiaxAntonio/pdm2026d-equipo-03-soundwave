abstract interface class PlaybackPreferencesRepository {
  Future<Set<String>> blockedSongIds(String collectionId);

  Future<void> setBlocked({
    required String collectionId,
    required String songId,
    required bool blocked,
  });
}
