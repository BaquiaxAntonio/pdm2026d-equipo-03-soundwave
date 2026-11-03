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
  static const collectionId = 'offline';

  Future<void> initialize() => PlaylistDao(database).ensureOfflineCollection();

  @override
  Future<List<PlayerQueueEntry>> list(PlayerQueueFilter filter) async {
    final rows = await database.rawQuery(
      '''
      SELECT s.*, p.position FROM playlist_songs p
      JOIN songs s ON s.id = p.song_id
      JOIN downloads d ON d.song_id = s.id
      WHERE p.playlist_id = ? AND d.state = 'completed' ORDER BY p.position
    ''',
      [collectionId],
    );
    final entries = rows.map(
      (row) => PlayerQueueEntry(
        song: PlayerSongLocal(
          id: row['id']! as String,
          title: row['title']! as String,
          artist: row['artist']! as String,
          durationSeconds: ((row['duration_ms'] as int?) ?? 0) ~/ 1000,
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
