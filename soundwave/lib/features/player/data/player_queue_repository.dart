import 'package:sqflite/sqflite.dart';

import '../../../core/database/playlist_dao.dart';
import '../mock_player_data.dart';
import '../models/player_queue_filter.dart';
import '../player_song_local.dart';

class PlayerQueueEntry {
  const PlayerQueueEntry({required this.song, required this.position});

  final PlayerSongLocal song;
  final int position;
}

abstract class PlayerQueueRepository {
  Future<List<PlayerQueueEntry>> list(PlayerQueueFilter filter);
  Future<void> remove(PlayerQueueEntry entry);
  Future<void> restore(PlayerQueueEntry entry);
}

class SqlitePlayerQueueRepository implements PlayerQueueRepository {
  SqlitePlayerQueueRepository(this.database);

  final Database database;
  static const collectionId = 'player-lab-queue';

  Future<void> initialize() => database.transaction((tx) async {
    final existing = await tx.query(
      'playlists',
      where: 'id = ?',
      whereArgs: [collectionId],
    );
    if (existing.isNotEmpty) return;
    await PlaylistDao(
      tx,
    ).create(id: collectionId, name: 'Cola de reproducción');
    for (var index = 0; index < mockPlayerSongs.length; index++) {
      final song = mockPlayerSongs[index];
      final id = 'player-demo:${song.id}';
      await tx.insert('songs', {
        'id': id,
        'provider': 'player-demo',
        'source_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'duration_ms': song.durationSeconds * 1000,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await PlaylistDao(
        tx,
      ).addSong(playlistId: collectionId, songId: id, position: index);
    }
  });

  @override
  Future<List<PlayerQueueEntry>> list(PlayerQueueFilter filter) async {
    final rows = await database.rawQuery(
      '''
      SELECT s.*, p.position FROM playlist_songs p
      JOIN songs s ON s.id = p.song_id
      WHERE p.playlist_id = ? ORDER BY p.position
    ''',
      [collectionId],
    );
    final entries = rows.map(
      (row) => PlayerQueueEntry(
        song: PlayerSongLocal(
          id: row['id']! as String,
          title: row['title']! as String,
          artist: row['artist']! as String,
          durationSeconds: (row['duration_ms']! as int) ~/ 1000,
        ),
        position: row['position']! as int,
      ),
    );
    return entries.where((entry) => matchesQueueFilter(entry, filter)).toList();
  }

  @override
  Future<void> remove(PlayerQueueEntry entry) async {
    await PlaylistDao(
      database,
    ).removeSong(playlistId: collectionId, songId: entry.song.id);
  }

  @override
  Future<void> restore(PlayerQueueEntry entry) async {
    await PlaylistDao(database).addSong(
      playlistId: collectionId,
      songId: entry.song.id,
      position: entry.position,
    );
  }
}

bool matchesQueueFilter(PlayerQueueEntry entry, PlayerQueueFilter filter) {
  final text = filter.text.trim().toLowerCase();
  return entry.song.title.toLowerCase().contains(text) ||
      entry.song.artist.toLowerCase().contains(text);
}

class MemoryPlayerQueueRepository implements PlayerQueueRepository {
  MemoryPlayerQueueRepository()
    : _entries = [
        for (var i = 0; i < mockPlayerSongs.length; i++)
          PlayerQueueEntry(song: mockPlayerSongs[i], position: i),
      ];

  final List<PlayerQueueEntry> _entries;

  @override
  Future<List<PlayerQueueEntry>> list(PlayerQueueFilter filter) async =>
      _entries.where((entry) => matchesQueueFilter(entry, filter)).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<void> remove(PlayerQueueEntry entry) async {
    _entries.removeWhere((item) => item.song.id == entry.song.id);
  }

  @override
  Future<void> restore(PlayerQueueEntry entry) async {
    _entries.add(entry);
  }
}
