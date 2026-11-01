import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:soundwave/core/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exact schema that version 1 phones already have. It is intentionally frozen:
/// a released migration must never be edited to describe a newer change.
const _version1Statements = [
  '''
CREATE TABLE songs (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  source_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  duration_ms INTEGER CHECK (duration_ms IS NULL OR duration_ms >= 0),
  artwork_url TEXT,
  UNIQUE (provider, source_id)
)
''',
  '''
CREATE TABLE downloads (
  song_id TEXT PRIMARY KEY REFERENCES songs(id) ON DELETE CASCADE,
  state TEXT NOT NULL CHECK (state IN
    ('queued', 'downloading', 'completed', 'failed', 'pendingDeletion')),
  bytes_received INTEGER NOT NULL DEFAULT 0 CHECK (bytes_received >= 0),
  total_bytes INTEGER CHECK (total_bytes IS NULL OR total_bytes >= 0),
  local_path TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  error_message TEXT,
  deletion_deadline INTEGER
)
''',
  '''
CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
)
''',
  '''
CREATE TABLE playlist_songs (
  playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 0),
  PRIMARY KEY (playlist_id, song_id),
  UNIQUE (playlist_id, position)
)
''',
  '''
CREATE TABLE blocked_songs (
  playlist_id TEXT NOT NULL,
  song_id TEXT NOT NULL,
  blocked_at INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, song_id),
  FOREIGN KEY (playlist_id, song_id)
    REFERENCES playlist_songs(playlist_id, song_id) ON DELETE CASCADE
)
''',
  'CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)',
  'CREATE INDEX idx_songs_artist ON songs(artist COLLATE NOCASE)',
  'CREATE INDEX idx_downloads_state ON downloads(state)',
];

void main() {
  late Directory directory;
  late String databasePath;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('soundwave-migration-');
    databasePath = path.join(directory.path, 'soundwave.db');
  });

  tearDown(() => directory.delete(recursive: true));

  Future<Database> openVersion1() => databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final statement in _version1Statements) {
          await db.execute(statement);
        }
      },
    ),
  );

  Future<Database> openCurrent() => databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => createDatabaseSchema(db),
      onUpgrade: upgradeDatabaseSchema,
    ),
  );

  test('opening a v1 database with data keeps it and adds v2', () async {
    final legacy = await openVersion1();
    await legacy.insert('songs', {
      'id': 'demo:blue-hour',
      'provider': 'demo',
      'source_id': 'blue-hour',
      'title': 'Blue Hour',
      'artist': 'The Soundwaves',
      'duration_ms': 205000,
    });
    await legacy.insert('playlists', {'id': 'favoritas', 'name': 'Favoritas'});
    await legacy.insert('playlists', {
      'id': 'offline',
      'name': 'Colección sin conexión',
    });
    await legacy.insert('playlist_songs', {
      'playlist_id': 'favoritas',
      'song_id': 'demo:blue-hour',
      'position': 0,
    });
    await legacy.close();

    final upgraded = await openCurrent();
    addTearDown(upgraded.close);

    final playlists = await upgraded.query('playlists', orderBy: 'name');
    expect(playlists, hasLength(2));
    expect(
      playlists.map((row) => row['name']),
      containsAll(['Colección sin conexión', 'Favoritas']),
    );
    expect(playlists.every((row) => row['archived'] == 0), isTrue);
    expect(
      await upgraded.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: ['favoritas'],
      ),
      hasLength(1),
    );
    expect((await upgraded.query('songs')).single['title'], 'Blue Hour');

    final indexes = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_playlists_name_unique'],
    );
    expect(indexes, hasLength(1));

    await upgraded.update(
      'playlists',
      {'archived': 1},
      where: 'id = ?',
      whereArgs: ['offline'],
    );
    expect(
      (await upgraded.query(
        'playlists',
        where: 'id = ?',
        whereArgs: ['offline'],
      )).single['archived'],
      1,
    );

    await expectLater(
      upgraded.insert('playlists', {'id': 'other', 'name': 'favoritas'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('upgrading renames duplicate names instead of deleting lists', () async {
    final legacy = await openVersion1();
    await legacy.insert('playlists', {'id': 'a', 'name': 'Road trip'});
    await legacy.insert('playlists', {'id': 'b', 'name': 'road trip'});
    await legacy.insert('playlists', {'id': 'c', 'name': 'Road trip (2)'});
    await legacy.close();

    final upgraded = await openCurrent();
    addTearDown(upgraded.close);

    final rows = await upgraded.query('playlists', orderBy: 'rowid');
    final names = rows.map((row) => row['name']! as String).toList();
    expect(rows.map((row) => row['id']), containsAll(['a', 'b', 'c']));
    expect(names, hasLength(3));
    expect(names.map((name) => name.toLowerCase()).toSet(), hasLength(3));
    expect(names.first, 'Road trip');
  });
}
