import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/features/player/data/player_playlist_repository.dart';
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

// Esquema publicado como v2 por Henry: licencias y usuarios, sin las
// columnas de playlists que se agregaron después conservando databaseVersion=2.
const _version2HenryStatements = [
  ..._version1Statements,
  'ALTER TABLE songs ADD COLUMN license TEXT',
  'ALTER TABLE songs ADD COLUMN license_url TEXT',
  'ALTER TABLE songs ADD COLUMN attribution TEXT',
  'ALTER TABLE songs ADD COLUMN source_url TEXT',
  '''CREATE TABLE users (
    id TEXT PRIMARY KEY,
    username TEXT NOT NULL COLLATE NOCASE UNIQUE,
    display_name TEXT,
    password_hash TEXT NOT NULL
  )''',
];

// Esquema publicado como v2 por Ramos: parte de la v2 de Henry y agrega
// columnas e índice parcial del reproductor.
const _version2RamosStatements = [
  ..._version2HenryStatements,
  'ALTER TABLE playlists ADD COLUMN player_managed INTEGER NOT NULL DEFAULT 0 CHECK (player_managed IN (0, 1))',
  'ALTER TABLE playlists ADD COLUMN archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))',
  '''CREATE UNIQUE INDEX idx_player_playlist_name
     ON playlists(trim(name) COLLATE NOCASE)
     WHERE player_managed = 1''',
];

// Estado incompleto posible en una instalación intervenida: archived existe,
// pero player_managed y el índice todavía faltan.
const _version2PartialStatements = [
  ..._version2HenryStatements,
  'ALTER TABLE playlists ADD COLUMN archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))',
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

  Future<Database> openLegacy(String createSql) =>
      databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => db.execute(createSql),
        ),
      );

  Future<Database> openVersion1() async {
    final database = await openLegacy('SELECT 1');
    for (final statement in _version1Statements) {
      await database.execute(statement);
    }
    return database;
  }

  Future<Database> openHistoricalV2(List<String> statements) async {
    final database = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          for (final statement in statements) {
            await db.execute(statement);
          }
        },
      ),
    );
    await database.insert('songs', {
      'id': 'demo:blue-hour',
      'provider': 'demo',
      'source_id': 'blue-hour',
      'title': 'Blue Hour',
      'artist': 'The Soundwaves',
      'license': 'CC-BY',
      'license_url': 'https://example.test/license',
      'attribution': 'The Soundwaves',
      'source_url': 'https://example.test/song',
    });
    await database.insert('playlists', {'id': 'legacy', 'name': 'Favorites'});
    await database.insert('playlist_songs', {
      'playlist_id': 'legacy',
      'song_id': 'demo:blue-hour',
      'position': 0,
    });
    await database.insert('blocked_songs', {
      'playlist_id': 'legacy',
      'song_id': 'demo:blue-hour',
      'blocked_at': 1234,
    });
    await database.insert('users', {
      'id': 'user-1',
      'username': 'Henry',
      'display_name': 'Henry B',
      'password_hash': 'stored-hash',
    });
    await database.insert('downloads', {
      'song_id': 'demo:blue-hour',
      'state': 'completed',
      'bytes_received': 10,
      'created_at': 1,
      'updated_at': 2,
    });
    return database;
  }

  Future<void> expectHistoricalDataAndCrud(Database database) async {
    expect(await database.getVersion(), 3);
    expect((await database.query('songs')).single['id'], 'demo:blue-hour');
    expect((await database.query('songs')).single['license'], 'CC-BY');
    expect((await database.query('users')).single['id'], 'user-1');
    expect(
      (await database.query('downloads')).single['song_id'],
      'demo:blue-hour',
    );
    expect((await database.query('playlists')).single['id'], 'legacy');
    expect(await database.query('playlist_songs'), hasLength(1));
    expect(await database.query('blocked_songs'), hasLength(1));
    final playlistColumns = await database.rawQuery(
      'PRAGMA table_info(playlists)',
    );
    expect(
      playlistColumns.map((row) => row['name']),
      containsAll(['player_managed', 'archived']),
    );
    final playerIndexes = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_player_playlist_name'],
    );
    expect(playerIndexes, hasLength(1));
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);

    final repository = SqlitePlayerPlaylistRepository(database);
    await repository.save(name: 'Migrated CRUD');
    final created = (await repository.list()).single;
    await repository.setArchived(created.id, true);
    expect((await repository.list()).single.archived, isTrue);
    await expectLater(
      repository.save(name: ' migrated crud '),
      throwsA(isA<PlayerPlaylistException>()),
    );
  }

  Future<Database> openCurrent() => databaseFactoryFfi.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: databaseVersion,
      singleInstance: false,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) => createDatabaseSchema(db),
      onUpgrade: upgradeDatabaseSchema,
    ),
  );

  test('opening a v1 database with data migrates it to v3', () async {
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
    await legacy.insert('playlists', {'id': 'offline', 'name': 'Favoritas'});
    await legacy.insert('playlist_songs', {
      'playlist_id': 'favoritas',
      'song_id': 'demo:blue-hour',
      'position': 0,
    });
    await legacy.insert('blocked_songs', {
      'playlist_id': 'favoritas',
      'song_id': 'demo:blue-hour',
      'blocked_at': 1234,
    });
    await legacy.close();

    final upgraded = await openCurrent();
    addTearDown(upgraded.close);

    expect(await upgraded.getVersion(), 3);
    final playlists = await upgraded.query('playlists', orderBy: 'rowid');
    expect(playlists, hasLength(2));
    // The upgrade never renames or deletes lists the user already had, even
    // when they share a name.
    expect(playlists.map((row) => row['name']), everyElement('Favoritas'));
    expect(playlists.every((row) => row['archived'] == 0), isTrue);
    expect(playlists.every((row) => row['player_managed'] == 0), isTrue);
    expect(
      await upgraded.query(
        'playlist_songs',
        where: 'playlist_id = ?',
        whereArgs: ['favoritas'],
      ),
      hasLength(1),
    );
    expect((await upgraded.query('songs')).single['title'], 'Blue Hour');
    expect(await upgraded.query('blocked_songs'), hasLength(1));

    final songColumns = await upgraded.rawQuery('PRAGMA table_info(songs)');
    expect(
      songColumns.map((row) => row['name']),
      containsAll(['license', 'license_url', 'attribution', 'source_url']),
    );
    final tables = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'users'",
    );
    expect(tables, hasLength(1));

    final indexes = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_player_playlist_name'],
    );
    expect(indexes, hasLength(1));
  });

  for (final historical in [
    ('Henry v2 without player columns', _version2HenryStatements),
    ('Ramos v2 with player columns and index', _version2RamosStatements),
    ('partial v2 with one playlist column', _version2PartialStatements),
  ]) {
    test('upgrades ${historical.$1} to v3 without data loss', () async {
      final legacy = await openHistoricalV2(historical.$2);
      await legacy.close();

      final upgraded = await openCurrent();
      addTearDown(upgraded.close);
      await expectHistoricalDataAndCrud(upgraded);

      // Opening and closing a migrated database is stable and retains IDs.
      await upgraded.close();
      final reopened = await openCurrent();
      addTearDown(reopened.close);
      expect((await reopened.query('playlists')).first['id'], 'legacy');
      expect((await reopened.query('users')).single['id'], 'user-1');
      expect(await reopened.query('blocked_songs'), hasLength(1));
    });
  }

  test('new installation creates the v3 schema', () async {
    final database = await openCurrent();
    addTearDown(database.close);
    expect(await database.getVersion(), 3);
    final columns = await database.rawQuery('PRAGMA table_info(playlists)');
    expect(
      columns.map((row) => row['name']),
      containsAll(['player_managed', 'archived']),
    );
    expect(await database.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('the name index only covers lists managed by the player', () async {
    final database = await openCurrent();
    addTearDown(database.close);

    // Lists created outside the player keep the duplicates they always had.
    await database.insert('playlists', {'id': 'a', 'name': 'Road trip'});
    await database.insert('playlists', {'id': 'b', 'name': 'road trip'});
    expect(await database.query('playlists'), hasLength(2));

    await database.insert('playlists', {
      'id': 'p1',
      'name': 'Viaje',
      'player_managed': 1,
    });
    await expectLater(
      database.insert('playlists', {
        'id': 'p2',
        'name': ' viaje ',
        'player_managed': 1,
      }),
      throwsA(isA<DatabaseException>()),
    );

    // The player names stay usable by the other collections.
    await database.insert('playlists', {'id': 'c', 'name': 'viaje'});
    expect(await database.query('playlists'), hasLength(4));
  });
}
