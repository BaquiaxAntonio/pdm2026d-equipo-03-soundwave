abstract interface class AudioFileStore {
  /// Creates a private temporary file path for the given stable song ID.
  Future<String> createTemporaryPath(String songId);

  /// Atomically promotes a completed temporary file to its relative final path.
  Future<String> commit(String temporaryPath, String songId);

  String resolve(String relativePath);

  Future<bool> exists(String relativePath);

  Future<void> delete(String relativePath);
}
