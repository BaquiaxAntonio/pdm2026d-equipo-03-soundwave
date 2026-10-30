import '../../../core/models/song.dart';
import '../../../core/models/download_record.dart';

class PlayerTrack {
  const PlayerTrack({required this.song, required this.localPath});

  final Song song;
  final String? localPath;

  factory PlayerTrack.fromDownload(Song song, DownloadRecord download) {
    if (download.songId != song.id ||
        download.state != DownloadState.completed ||
        download.localPath == null) {
      throw ArgumentError('Playback requires a completed download with a path.');
    }
    return PlayerTrack(song: song, localPath: download.localPath);
  }

  String get id => song.id;
  String get title => song.title;
  String get artist => song.artist;
  Duration get duration => song.durationMs == null
      ? const Duration(minutes: 3)
      : Duration(milliseconds: song.durationMs!);
}
