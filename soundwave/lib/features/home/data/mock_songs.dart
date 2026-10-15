class Song {
  final String title;
  final String artist;
  final String duration;

  const Song({
    required this.title,
    required this.artist,
    required this.duration,
  });
}

const List<Song> recentSongs = [
  Song(title: 'Midnight City', artist: 'M83', duration: '4:03'),
  Song(title: 'Blinding Lights', artist: 'The Weeknd', duration: '3:20'),
  Song(title: 'Levitating', artist: 'Dua Lipa', duration: '3:23'),
  Song(title: 'Save Your Tears', artist: 'The Weeknd', duration: '3:35'),
];

const List<Song> favoriteSongs = [
  Song(title: 'Starboy', artist: 'The Weeknd ft. Daft Punk', duration: '3:50'),
  Song(title: 'Get Lucky', artist: 'Daft Punk ft. Pharrell', duration: '6:09'),
  Song(
    title: 'Instant Crush',
    artist: 'Daft Punk ft. Julian Casablancas',
    duration: '5:37',
  ),
  Song(title: 'Around the World', artist: 'Daft Punk', duration: '7:10'),
];

const List<Song> recommendedSongs = [
  Song(title: 'Bohemian Rhapsody', artist: 'Queen', duration: '5:55'),
  Song(title: 'Hotel California', artist: 'Eagles', duration: '6:30'),
  Song(title: 'Smells Like Teen Spirit', artist: 'Nirvana', duration: '5:01'),
  Song(title: 'Imagine', artist: 'John Lennon', duration: '3:07'),
];
