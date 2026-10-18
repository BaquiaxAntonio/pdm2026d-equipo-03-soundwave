import 'package:sqflite/sqflite.dart';

class BlockedSongDao {
  const BlockedSongDao(this.database);

  final DatabaseExecutor database;

  Future<Set<String>> songIds(String playlistId) async {
    final rows = await database.query(
      'blocked_songs',
      columns: ['song_id'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    return rows.map((row) => row['song_id']! as String).toSet();
  }

  Future<void> setBlocked({
    required String playlistId,
    required String songId,
    required bool blocked,
    DateTime? blockedAt,
  }) async {
    if (blocked) {
      await database.insert('blocked_songs', {
        'playlist_id': playlistId,
        'song_id': songId,
        'blocked_at': (blockedAt ?? DateTime.now()).millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await database.delete(
        'blocked_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [playlistId, songId],
      );
    }
  }
}
