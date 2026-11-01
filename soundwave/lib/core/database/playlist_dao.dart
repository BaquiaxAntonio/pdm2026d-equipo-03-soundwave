import 'package:sqflite/sqflite.dart';

import '../models/playlist.dart';

class PlaylistDao {
  const PlaylistDao(this.database);

  final DatabaseExecutor database;

  Future<void> create({required String id, required String name}) =>
      database.insert('playlists', {'id': id, 'name': name});

  /// Active and archived playlists with their song count, ordered by state and
  /// name so the UI shows active lists first.
  Future<List<PlaylistEntry>> entries() async {
    final rows = await database.rawQuery('''
SELECT p.id, p.name, p.archived, COUNT(ps.song_id) AS song_count
FROM playlists p
LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
GROUP BY p.id, p.name, p.archived
ORDER BY p.archived, p.name COLLATE NOCASE
''');
    return rows
        .map(
          (row) => PlaylistEntry(
            playlist: Playlist.fromMap(row),
            songCount: (row['song_count'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<Playlist?> findById(String id) async {
    final rows = await database.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Playlist.fromMap(rows.first);
  }

  Future<int> rename({required String id, required String name}) => database
      .update('playlists', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<int> setArchived({required String id, required bool archived}) =>
      database.update(
        'playlists',
        {'archived': archived ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<int> songCount(String id) async {
    final rows = await database.rawQuery(
      'SELECT COUNT(*) AS total FROM playlist_songs WHERE playlist_id = ?',
      [id],
    );
    return (rows.single['total'] as int?) ?? 0;
  }

  Future<int> delete(String id) =>
      database.delete('playlists', where: 'id = ?', whereArgs: [id]);

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

  Future<int> removeSong({
    required String playlistId,
    required String songId,
  }) => database.delete(
    'playlist_songs',
    where: 'playlist_id = ? AND song_id = ?',
    whereArgs: [playlistId, songId],
  );
}
