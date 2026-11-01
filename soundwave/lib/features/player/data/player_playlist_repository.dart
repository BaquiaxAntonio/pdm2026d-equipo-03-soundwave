import 'package:sqflite/sqflite.dart';

import '../models/player_playlist.dart';
import '../mock_player_data.dart';
import '../player_song_local.dart';

class PlayerPlaylistException implements Exception {
  const PlayerPlaylistException(this.message, {this.inUse = false});
  final String message;
  final bool inUse;
}

abstract class PlayerPlaylistRepository {
  Future<List<PlayerPlaylist>> list();
  Future<List<PlayerSongLocal>> songs(String id);

  /// Al editar, null conserva las canciones; una lista vacía las quita todas.
  Future<void> save({String? id, required String name, List<String>? songIds});
  Future<void> delete(String id);
  Future<void> setArchived(String id, bool archived);
}

String _validatedName(String name) {
  final result = name.trim();
  if (result.isEmpty) {
    throw const PlayerPlaylistException('Escribe un nombre para la lista.');
  }
  return result;
}

const _duplicate = PlayerPlaylistException(
  'Ya existe una lista con ese nombre.',
);
const _inUse = PlayerPlaylistException(
  'Esta lista contiene canciones. Puedes archivarla para conservarlas.',
  inUse: true,
);

class SqlitePlayerPlaylistRepository implements PlayerPlaylistRepository {
  const SqlitePlayerPlaylistRepository(this.database);
  final Database database;

  @override
  Future<List<PlayerSongLocal>> songs(String id) async {
    final rows = await database.rawQuery(
      '''
      SELECT s.* FROM playlist_songs ps
      JOIN playlists p ON p.id = ps.playlist_id
      JOIN songs s ON s.id = ps.song_id
      WHERE p.id = ? AND p.player_managed = 1 ORDER BY ps.position
    ''',
      [id],
    );
    return rows
        .map(
          (row) => PlayerSongLocal(
            id: row['id']! as String,
            title: row['title']! as String,
            artist: row['artist']! as String,
            durationSeconds: ((row['duration_ms'] as int?) ?? 0) ~/ 1000,
          ),
        )
        .toList();
  }

  @override
  Future<List<PlayerPlaylist>> list() async {
    final rows = await database.rawQuery('''
      SELECT p.id, p.name, p.archived, COUNT(ps.song_id) AS song_count
      FROM playlists p LEFT JOIN playlist_songs ps ON ps.playlist_id = p.id
      WHERE p.player_managed = 1 GROUP BY p.id
      ORDER BY p.archived, p.name COLLATE NOCASE
    ''');
    return rows
        .map(
          (row) => PlayerPlaylist(
            id: row['id']! as String,
            name: row['name']! as String,
            archived: row['archived'] == 1,
            songCount: row['song_count']! as int,
          ),
        )
        .toList();
  }

  @override
  Future<void> save({
    String? id,
    required String name,
    List<String>? songIds,
  }) async {
    final cleanName = _validatedName(name);
    try {
      await database.transaction((tx) async {
        if (id != null) {
          final changed = await tx.update(
            'playlists',
            {'name': cleanName},
            where: 'id = ? AND player_managed = 1',
            whereArgs: [id],
          );
          if (changed == 0) {
            throw const PlayerPlaylistException('La lista ya no existe.');
          }
          if (songIds != null) await _syncSongs(tx, id, songIds);
          return;
        }
        final newId = 'player-list:${DateTime.now().microsecondsSinceEpoch}';
        await tx.insert('playlists', {
          'id': newId,
          'name': cleanName,
          'player_managed': 1,
        });
        await _syncSongs(tx, newId, songIds ?? const []);
      });
    } on DatabaseException catch (error) {
      if (error.isUniqueConstraintError()) throw _duplicate;
      rethrow;
    }
  }

  Future<void> _syncSongs(
    DatabaseExecutor tx,
    String id,
    List<String> songIds,
  ) async {
    final rows = await tx.query(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    final existing = rows.map((row) => row['song_id']! as String).toSet();
    final wanted = songIds.toSet();
    if (existing.length == wanted.length && existing.containsAll(wanted)) {
      return;
    }
    for (final removed in existing.difference(wanted)) {
      await tx.delete(
        'playlist_songs',
        where: 'playlist_id = ? AND song_id = ?',
        whereArgs: [id, removed],
      );
    }
    // Primero conservamos el orden de las canciones que permanecen.
    final ordered = [
      ...existing.where(wanted.contains),
      ...wanted.difference(existing),
    ];
    if (rows.isNotEmpty) {
      // Liberar posiciones antes de compactarlas evita colisiones del UNIQUE.
      final offset = (rows.last['position']! as int) + 1;
      await tx.rawUpdate(
        'UPDATE playlist_songs SET position = position + ? WHERE playlist_id = ?',
        [offset, id],
      );
    }
    for (var i = 0; i < ordered.length; i++) {
      final songId = ordered[i];
      if (existing.contains(songId)) {
        await tx.update(
          'playlist_songs',
          {'position': i},
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [id, songId],
        );
      } else {
        await tx.insert('playlist_songs', {
          'playlist_id': id,
          'song_id': songId,
          'position': i,
        });
      }
    }
  }

  @override
  Future<void> delete(String id) => database.transaction((tx) async {
    final references = await tx.query(
      'playlist_songs',
      columns: ['song_id'],
      where: 'playlist_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (references.isNotEmpty) throw _inUse;
    await tx.delete(
      'playlists',
      where: 'id = ? AND player_managed = 1',
      whereArgs: [id],
    );
  });

  @override
  Future<void> setArchived(String id, bool archived) async {
    await database.update(
      'playlists',
      {'archived': archived ? 1 : 0},
      where: 'id = ? AND player_managed = 1',
      whereArgs: [id],
    );
  }
}

class MemoryPlayerPlaylistRepository implements PlayerPlaylistRepository {
  MemoryPlayerPlaylistRepository({
    List<PlayerSongLocal> catalog = mockPlayerSongs,
  }) : _catalog = {for (final song in catalog) song.id: song};

  final _entries = <String, PlayerPlaylist>{};
  final _songIds = <String, List<String>>{};
  final Map<String, PlayerSongLocal> _catalog;
  var _nextId = 0;

  @override
  Future<List<PlayerSongLocal>> songs(String id) async => [
    for (final songId in _songIds[id] ?? <String>[])
      _catalog[songId] ??
          PlayerSongLocal(
            id: songId,
            title: songId,
            artist: 'Canción guardada',
            durationSeconds: 0,
          ),
  ];

  @override
  Future<List<PlayerPlaylist>> list() async =>
      _entries.values.toList()..sort((a, b) {
        if (a.archived != b.archived) return a.archived ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  @override
  Future<void> save({
    String? id,
    required String name,
    List<String>? songIds,
  }) async {
    final cleanName = _validatedName(name);
    if (_entries.values.any(
      (p) => p.id != id && p.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      throw _duplicate;
    }
    final old = _entries[id];
    if (id != null && old == null) {
      throw const PlayerPlaylistException('La lista ya no existe.');
    }
    final key = id ?? 'player-list:${_nextId++}';
    final existing = _songIds[key] ?? <String>[];
    final wanted = songIds?.toSet();
    final updated = wanted == null
        ? List<String>.of(existing)
        : [
            ...existing.where(wanted.contains),
            ...wanted.where((songId) => !existing.contains(songId)),
          ];
    _songIds[key] = updated;
    _entries[key] = PlayerPlaylist(
      id: key,
      name: cleanName,
      archived: old?.archived ?? false,
      songCount: updated.length,
    );
  }

  @override
  Future<void> delete(String id) async {
    if ((_entries[id]?.songCount ?? 0) > 0) throw _inUse;
    _entries.remove(id);
    _songIds.remove(id);
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final old = _entries[id];
    if (old == null) return;
    _entries[id] = PlayerPlaylist(
      id: id,
      name: old.name,
      archived: archived,
      songCount: old.songCount,
    );
  }
}
