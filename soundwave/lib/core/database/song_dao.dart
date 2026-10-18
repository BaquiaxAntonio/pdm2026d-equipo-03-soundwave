import 'package:sqflite/sqflite.dart';

import '../models/song.dart';

class SongDao {
  const SongDao(this.database);

  final Database database;

  Future<void> upsert(Song song) => database.transaction((transaction) async {
    final updated = await transaction.update(
      'songs',
      song.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [song.id],
    );
    if (updated == 0) await transaction.insert('songs', song.toMap());
  });

  Future<Song?> findById(String id) async {
    final rows = await database.query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  Future<Song?> findBySource(String provider, String sourceId) async {
    final rows = await database.query(
      'songs',
      where: 'provider = ? AND source_id = ?',
      whereArgs: [provider, sourceId],
    );
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  Future<List<Song>> search(String query) async {
    final normalizedQuery = query.trim();
    final rows = await database.query(
      'songs',
      where: normalizedQuery.isEmpty ? null : 'title LIKE ? OR artist LIKE ?',
      whereArgs: normalizedQuery.isEmpty
          ? null
          : ['%$normalizedQuery%', '%$normalizedQuery%'],
      orderBy: 'title COLLATE NOCASE, artist COLLATE NOCASE',
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<int> delete(String id) =>
      database.delete('songs', where: 'id = ?', whereArgs: [id]);
}
