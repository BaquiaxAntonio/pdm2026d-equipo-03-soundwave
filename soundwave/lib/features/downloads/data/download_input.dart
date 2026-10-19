import '../../../core/models/song.dart';

/// Provider-specific adapters resolve a permitted URL for each attempt.
class DownloadInput {
  const DownloadInput(this.bytes, {this.totalBytes, this.close});
  final Stream<List<int>> bytes;
  final int? totalBytes;
  final void Function()? close;
}

typedef OpenDownload = Future<DownloadInput> Function(Song song);
