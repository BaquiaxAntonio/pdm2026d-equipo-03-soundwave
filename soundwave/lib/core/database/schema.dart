import 'package:sqflite/sqflite.dart';

const databaseName = 'soundwave.db';
const databaseVersion = 3;

const createSongsTable = '''
CREATE TABLE songs (
  id TEXT PRIMARY KEY,
  provider TEXT NOT NULL,
  source_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  duration_ms INTEGER CHECK (duration_ms IS NULL OR duration_ms >= 0),
  artwork_url TEXT,
  license TEXT,
  license_url TEXT,
  attribution TEXT,
  source_url TEXT,
  UNIQUE (provider, source_id)
)
''';

const createDownloadsTable = '''
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
''';

const createPlaylistsTable = '''
CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0
)
''';

const createPlaylistNameIndex =
    'CREATE UNIQUE INDEX IF NOT EXISTS idx_playlists_name_unique '
    'ON playlists(name COLLATE NOCASE)';

const createPlaylistSongsTable = '''
CREATE TABLE playlist_songs (
  playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 0),
  PRIMARY KEY (playlist_id, song_id),
  UNIQUE (playlist_id, position)
)
''';

const createBlockedSongsTable = '''
CREATE TABLE blocked_songs (
  playlist_id TEXT NOT NULL,
  song_id TEXT NOT NULL,
  blocked_at INTEGER NOT NULL,
  PRIMARY KEY (playlist_id, song_id),
  FOREIGN KEY (playlist_id, song_id)
    REFERENCES playlist_songs(playlist_id, song_id) ON DELETE CASCADE
)
''';

const createUsersTable = '''
CREATE TABLE users (
 id TEXT PRIMARY KEY,
 username TEXT NOT NULL COLLATE NOCASE UNIQUE,
 display_name TEXT,
 password_hash TEXT NOT NULL
)
''';

const createSchemaStatements = [
  createSongsTable,
  createDownloadsTable,
  createPlaylistsTable,
  createPlaylistSongsTable,
  createBlockedSongsTable,
  createUsersTable,
  createPlaylistNameIndex,
  'CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)',
  'CREATE INDEX idx_songs_artist ON songs(artist COLLATE NOCASE)',
  'CREATE INDEX idx_downloads_state ON downloads(state)',
];

Future<void> createDatabaseSchema(DatabaseExecutor database) async {
  for (final statement in createSchemaStatements) {
    await database.execute(statement);
  }
}

/// Applies only steps that an already installed database has not run yet.
/// Never rewrite a released step: a phone that already upgraded will not run
/// it again and its schema would silently diverge.
Future<void> upgradeDatabaseSchema(
  DatabaseExecutor database,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion < 1) {
    // A brand new file is created with the current schema, never by replaying
    // historical steps.
    await createDatabaseSchema(database);
    return;
  }
  if (oldVersion < 2 && newVersion >= 2) {
    await _upgradeToVersion2(database);
  }
  if (oldVersion < 3 && newVersion >= 3) {
    await _upgradeToVersion3(database);
  }
}

/// v2: song license metadata and local users.
Future<void> _upgradeToVersion2(DatabaseExecutor database) async {
  await database.execute('ALTER TABLE songs ADD COLUMN license TEXT');
  await database.execute('ALTER TABLE songs ADD COLUMN license_url TEXT');
  await database.execute('ALTER TABLE songs ADD COLUMN attribution TEXT');
  await database.execute('ALTER TABLE songs ADD COLUMN source_url TEXT');
  await database.execute(createUsersTable);
}

/// v3: playlists can be archived and their names are unique (case-insensitive).
Future<void> _upgradeToVersion3(DatabaseExecutor database) async {
  // A build of this branch shipped the playlist change as version 2, so the
  // column is only added when it is still missing.
  if (!await _hasColumn(database, 'playlists', 'archived')) {
    await database.execute(
      'ALTER TABLE playlists ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
    );
  }
  // The unique index cannot be created while two lists share a name, so names
  // already stored on the phone are suffixed instead of being deleted.
  await _deduplicatePlaylistNames(database);
  await database.execute(createPlaylistNameIndex);
}

Future<bool> _hasColumn(
  DatabaseExecutor database,
  String table,
  String column,
) async {
  final columns = await database.rawQuery('PRAGMA table_info($table)');
  return columns.any((row) => row['name'] == column);
}

Future<void> _deduplicatePlaylistNames(DatabaseExecutor database) async {
  final rows = await database.query(
    'playlists',
    columns: ['id', 'name'],
    orderBy: 'rowid',
  );
  final used = <String>{};
  for (final row in rows) {
    final id = row['id']! as String;
    final name = row['name']! as String;
    var candidate = name;
    var suffix = 2;
    while (!used.add(candidate.toLowerCase())) {
      candidate = '$name ($suffix)';
      suffix++;
    }
    if (candidate != name) {
      await database.update(
        'playlists',
        {'name': candidate},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
