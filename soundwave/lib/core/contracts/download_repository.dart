import '../models/download_record.dart';
import '../models/song.dart';

abstract interface class DownloadRepository {
  /// Reads one complete snapshot for screens that model loading, error, empty,
  /// and data states with a FutureProvider.
  Future<List<DownloadRecord>> loadDownloads();

  Stream<List<DownloadRecord>> watchDownloads();

  Future<DownloadRecord?> findBySongId(String songId);

  Future<void> enqueue(Song song);

  Future<void> retry(String songId);

  Future<void> requestRemoval(String songId, {required DateTime undoUntil});

  Future<void> undoRemoval(String songId);
}
