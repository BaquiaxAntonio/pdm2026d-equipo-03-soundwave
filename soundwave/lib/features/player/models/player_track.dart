import '../../../core/models/song.dart';

class PlayerTrack {
  const PlayerTrack({required this.song, required this.localPath});

  final Song song;
  final String? localPath;

  String get id => song.id;
  String get title => song.title;
  String get artist => song.artist;
  Duration get duration => song.durationMs == null
      ? const Duration(minutes: 3)
      : Duration(milliseconds: song.durationMs!);
}
