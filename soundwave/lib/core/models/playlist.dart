/// A user-visible collection of songs.
///
/// [archived] keeps a collection out of the way without deleting its songs,
/// which is the offered alternative when a list is still in use.
class Playlist {
  const Playlist({required this.id, required this.name, this.archived = false})
    : assert(id != ''),
      assert(name != '');

  final String id;
  final String name;
  final bool archived;

  Playlist copyWith({String? name, bool? archived}) => Playlist(
    id: id,
    name: name ?? this.name,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'archived': archived ? 1 : 0,
  };

  factory Playlist.fromMap(Map<String, Object?> map) => Playlist(
    id: map['id']! as String,
    name: map['name']! as String,
    archived: (map['archived'] as int? ?? 0) != 0,
  );
}

/// A playlist with the number of songs that reference it. The count feeds the
/// list label and the rule that blocks deleting a playlist still in use.
class PlaylistEntry {
  const PlaylistEntry({required this.playlist, required this.songCount});

  final Playlist playlist;
  final int songCount;

  String get songLabel =>
      '$songCount ${songCount == 1 ? 'canción' : 'canciones'}';
}

/// Reserved list that stores the songs marked with the heart action. Keeping it
/// as a normal playlist avoids a schema migration while reusing playlist_songs.
const favoritesPlaylistId = 'favorites';
const favoritesPlaylistName = 'Música que me gusta';
const favoritesPlaylist = Playlist(
  id: favoritesPlaylistId,
  name: favoritesPlaylistName,
);

bool isFavoritesPlaylist(String id) => id == favoritesPlaylistId;
