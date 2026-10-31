class PlayerPlaylist {
  const PlayerPlaylist({
    required this.id,
    required this.name,
    this.archived = false,
    this.songCount = 0,
  });

  final String id;
  final String name;
  final bool archived;
  final int songCount;
}
