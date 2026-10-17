import '../models/song.dart';

abstract interface class CatalogRepository {
  /// Searches provider and/or cached songs. Empty [query] may return the cache.
  Future<List<Song>> search(String query);

  Future<Song?> findById(String songId);

  Future<void> saveAll(Iterable<Song> songs);
}
