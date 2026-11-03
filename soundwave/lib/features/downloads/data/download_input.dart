import '../../../core/models/song.dart';

/// Provider-specific adapters resolve a permitted URL for each attempt.
class DownloadInput {
  const DownloadInput(
    this.bytes, {
    this.totalBytes,
    this.close,
    this.expectedSha1,
  });
  final Stream<List<int>> bytes;
  final int? totalBytes;
  final String? expectedSha1;
  final void Function()? close;
}

typedef OpenDownload = Future<DownloadInput> Function(Song song);
