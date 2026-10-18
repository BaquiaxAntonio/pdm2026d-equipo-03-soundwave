import 'package:sqflite/sqflite.dart';

import '../models/download_record.dart';

class DownloadDao {
  const DownloadDao(this.database);

  final DatabaseExecutor database;

  Future<void> upsert(DownloadRecord record) => database.insert(
    'downloads',
    record.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<DownloadRecord?> findBySongId(String songId) async {
    final rows = await database.query(
      'downloads',
      where: 'song_id = ?',
      whereArgs: [songId],
    );
    return rows.isEmpty ? null : DownloadRecord.fromMap(rows.first);
  }

  Future<List<DownloadRecord>> all() async {
    final rows = await database.query('downloads', orderBy: 'created_at DESC');
    return rows.map(DownloadRecord.fromMap).toList(growable: false);
  }

  Future<int> delete(String songId) =>
      database.delete('downloads', where: 'song_id = ?', whereArgs: [songId]);
}
