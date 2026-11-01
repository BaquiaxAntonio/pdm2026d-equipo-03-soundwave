import 'package:sqflite/sqflite.dart';

const databaseName = 'soundwave.db';
const databaseVersion = 2;

// ============================================================
// TABLAS DE LA BASE DE DATOS
// ============================================================

// Tabla de canciones
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

// Tabla de descargas
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

// Tabla de listas de reproducción
const createPlaylistsTable = '''
CREATE TABLE playlists (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
)
''';

// Relación entre listas y canciones
const createPlaylistSongsTable = '''
CREATE TABLE playlist_songs (
  playlist_id TEXT NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  song_id TEXT NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 0),
  PRIMARY KEY (playlist_id, song_id),
  UNIQUE (playlist_id, position)
)
''';

// Canciones bloqueadas por lista
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

// Tabla de usuarios
const createUsersTable = '''
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  display_name TEXT,
  password_hash TEXT NOT NULL
)
''';

// ============================================================
// SENTENCIAS PARA CREAR LA BASE DE DATOS
// ============================================================

const createSchemaStatements = [
  createSongsTable,
  createDownloadsTable,
  createPlaylistsTable,
  createPlaylistSongsTable,
  createBlockedSongsTable,
  createUsersTable,
  'CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)',
  'CREATE INDEX idx_songs_artist ON songs(artist COLLATE NOCASE)',
  'CREATE INDEX idx_downloads_state ON downloads(state)',
];

// Migración de listas administradas por Player.
// Solo las listas creadas por Player participan
// en el índice UNIQUE de nombres.
const playerPlaylistMigration = [
  'ALTER TABLE playlists ADD COLUMN player_managed INTEGER NOT NULL DEFAULT 0 CHECK (player_managed IN (0, 1))',
  'ALTER TABLE playlists ADD COLUMN archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))',
  '''CREATE UNIQUE INDEX idx_player_playlist_name
     ON playlists(trim(name) COLLATE NOCASE)
     WHERE player_managed = 1''',
];

// ============================================================
// CREACIÓN DE UNA BASE DE DATOS NUEVA
// ============================================================

Future<void> createDatabaseSchema(DatabaseExecutor database) async {
  for (final statement in createSchemaStatements) {
    await database.execute(statement);
  }

  // Las columnas de licencia y la tabla users
  // ya están incluidas en el esquema inicial.
  // Solo aplicamos las columnas e índice del Player.
  await _upgradePlayerPlaylists(database);
}

// ============================================================
// FUNCIONES AUXILIARES
// ============================================================

// Obtener los nombres de las columnas existentes.
Future<Set<String>> _getTableColumns(
  DatabaseExecutor database,
  String tableName,
) async {
  final result = await database.rawQuery('PRAGMA table_info($tableName)');

  return result.map((column) => column['name'] as String).toSet();
}

// Agregar una columna únicamente cuando no existe.
Future<void> _addColumnIfMissing(
  DatabaseExecutor database,
  String tableName,
  String columnName,
  String columnDefinition,
) async {
  final columns = await _getTableColumns(database, tableName);

  if (!columns.contains(columnName)) {
    await database.execute(
      'ALTER TABLE $tableName ADD COLUMN '
      '$columnName $columnDefinition',
    );
  }
}

// Migración de las listas de reproducción.
Future<void> _upgradePlayerPlaylists(DatabaseExecutor database) async {
  await _addColumnIfMissing(
    database,
    'playlists',
    'player_managed',
    'INTEGER NOT NULL DEFAULT 0 '
        'CHECK (player_managed IN (0, 1))',
  );

  await _addColumnIfMissing(
    database,
    'playlists',
    'archived',
    'INTEGER NOT NULL DEFAULT 0 '
        'CHECK (archived IN (0, 1))',
  );

  await database.execute(
    '''CREATE UNIQUE INDEX IF NOT EXISTS idx_player_playlist_name
       ON playlists(trim(name) COLLATE NOCASE)
       WHERE player_managed = 1''',
  );
}

// ============================================================
// ACTUALIZACIÓN DE LA BASE DE DATOS
// ============================================================

Future<void> upgradeDatabaseSchema(
  DatabaseExecutor database,
  int oldVersion,
  int newVersion,
) async {
  // Crear el esquema cuando se parte de la versión 0.
  if (oldVersion < 1 && newVersion >= 1) {
    await createDatabaseSchema(database);
    return;
  }

  // Migración de la versión 1 a la versión 2.
  if (oldVersion < 2 && newVersion >= 2) {
    // Agregar las columnas de licencia solo si faltan.
    await _addColumnIfMissing(database, 'songs', 'license', 'TEXT');

    await _addColumnIfMissing(database, 'songs', 'license_url', 'TEXT');

    await _addColumnIfMissing(database, 'songs', 'attribution', 'TEXT');

    await _addColumnIfMissing(database, 'songs', 'source_url', 'TEXT');

    // Crear la tabla de usuarios solo si no existe.
    await database.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        display_name TEXT,
        password_hash TEXT NOT NULL
      )
    ''');

    // Aplicar la migración de listas del Player.
    await _upgradePlayerPlaylists(database);
  }
}
