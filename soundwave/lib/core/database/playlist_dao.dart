import 'package:sqflite/sqflite.dart';

class PlaylistDao {
  const PlaylistDao(this.database);

  final DatabaseExecutor database;

  Future<void> create({required String id, required String name}) =>
      database.insert('playlists', {'id': id, 'name': name});

  Future<void> ensureOfflineCollection() async {
    await database.insert('playlists', {
      'id': 'offline',
      'name': 'Colección sin conexión',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> addSong({
    required String playlistId,
    required String songId,
    required int position,
  }) => database.insert('playlist_songs', {
    'playlist_id': playlistId,
    'song_id': songId,
    'position': position,
  });

  Future<List<String>> songIds(String playlistId) async {
    final rows = await database.query(
      'playlist_songs',
      columns: ['song_id'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position',
    );
    return rows.map((row) => row['song_id']! as String).toList(growable: false);
  }
}
