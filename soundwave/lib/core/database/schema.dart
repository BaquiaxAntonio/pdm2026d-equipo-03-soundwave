import 'package:sqflite/sqflite.dart';

const databaseName = 'soundwave.db';
const databaseVersion = 2;

const createSongsTable = '''
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
  name TEXT NOT NULL
)
''';

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

const createSchemaStatements = [
  createSongsTable,
  createDownloadsTable,
  createPlaylistsTable,
  createPlaylistSongsTable,
  createBlockedSongsTable,
  'CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)',
  'CREATE INDEX idx_songs_artist ON songs(artist COLLATE NOCASE)',
  'CREATE INDEX idx_downloads_state ON downloads(state)',
];

Future<void> createDatabaseSchema(DatabaseExecutor database) async {
  for (final statement in createSchemaStatements) {
    await database.execute(statement);
  }
  await upgradeDatabaseSchema(database, 1, databaseVersion);
}

// V2: solo las listas creadas por Player participan del índice UNIQUE.
// Las colecciones v1 de otros módulos conservan sus nombres y referencias.
const playerPlaylistMigration = [
  'ALTER TABLE playlists ADD COLUMN player_managed INTEGER NOT NULL DEFAULT 0 CHECK (player_managed IN (0, 1))',
  'ALTER TABLE playlists ADD COLUMN archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))',
  '''CREATE UNIQUE INDEX idx_player_playlist_name
     ON playlists(trim(name) COLLATE NOCASE) WHERE player_managed = 1''',
];

Future<void> upgradeDatabaseSchema(
  DatabaseExecutor database,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion < 1 && newVersion >= 1) {
    for (final statement in createSchemaStatements) {
      await database.execute(statement);
    }
  }
  if (oldVersion < 2 && newVersion >= 2) {
    for (final statement in playerPlaylistMigration) {
      await database.execute(statement);
    }
  }
}
