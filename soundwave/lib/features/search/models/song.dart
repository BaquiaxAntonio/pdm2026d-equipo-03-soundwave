class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationInSeconds,
  });

  final String id;
  final String title;
  final String artist;
  final int durationInSeconds;
}
