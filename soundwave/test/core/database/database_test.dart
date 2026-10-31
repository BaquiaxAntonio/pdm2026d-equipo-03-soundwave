import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:soundwave/core/database/blocked_song_dao.dart';
import 'package:soundwave/core/database/download_dao.dart';
import 'package:soundwave/core/database/playlist_dao.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/database/song_dao.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/player/data/player_playlist_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late SongDao songs;
  late DownloadDao downloads;
  late PlaylistDao playlists;
  late BlockedSongDao blockedSongs;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createDatabaseSchema(db),
      ),
    );
    songs = SongDao(database);
    downloads = DownloadDao(database);
    playlists = PlaylistDao(database);
    blockedSongs = BlockedSongDao(database);
  });

  tearDown(() => database.close());

  const song = Song(
    id: 'demo:blue-hour',
    title: 'Blue Hour',
    artist: 'The Soundwaves',
    durationMs: 205000,
    provider: 'demo',
    sourceId: 'blue-hour',
  );

  test('stores songs and searches by title or artist', () async {
    await songs.upsert(song);
    expect((await songs.findById(song.id))?.durationMs, 205000);
    expect((await songs.search('soundwaves')).single.id, song.id);
    expect((await songs.search('no match')), isEmpty);
  });

  test('reopens a file database without losing its songs', () async {
    final directory = await Directory.systemTemp.createTemp('soundwave-db-');
    final databasePath = path.join(directory.path, 'soundwave.db');
    try {
      final firstOpen = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onCreate: (db, _) => createDatabaseSchema(db),
        ),
      );
      await SongDao(firstOpen).upsert(song);
      await firstOpen.close();

      final reopened = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onUpgrade: upgradeDatabaseSchema,
        ),
      );
      expect((await SongDao(reopened).findById(song.id))?.title, song.title);
      await reopened.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('rejects duplicate provider identities', () async {
    await songs.upsert(song);
    await expectLater(
      songs.upsert(
        const Song(
          id: 'demo:another-id',
          title: 'Duplicate Source',
          artist: 'Another Artist',
          provider: 'demo',
          sourceId: 'blue-hour',
        ),
      ),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'upgrades a populated v1 file and persists v2 CRUD after reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp('soundwave-v1-');
      final databasePath = path.join(directory.path, 'migration.db');
      Database? opened;
      try {
        opened = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, _) async {
              // Esquema v1 publicado, sin columnas ni índices de v2.
              for (final statement in createSchemaStatements) {
                await db.execute(statement);
              }
            },
          ),
        );
        await SongDao(opened).upsert(song);
        await PlaylistDao(opened).ensureOfflineCollection();
        await PlaylistDao(
          opened,
        ).addSong(playlistId: 'offline', songId: song.id, position: 0);
        await BlockedSongDao(
          opened,
        ).setBlocked(playlistId: 'offline', songId: song.id, blocked: true);
        final now = DateTime.utc(2026, 10, 31);
        await DownloadDao(opened).upsert(
          DownloadRecord(
            songId: song.id,
            state: DownloadState.completed,
            bytesReceived: 512,
            totalBytes: 512,
            localPath: 'audio/legacy.mp3',
            createdAt: now,
            updatedAt: now,
          ),
        );
        // Los nombres repetidos previos, ajenos al reproductor, se conservan.
        await PlaylistDao(
          opened,
        ).create(id: 'legacy', name: 'Colección sin conexión');
        await opened.close();
        opened = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: databaseVersion,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onUpgrade: upgradeDatabaseSchema,
          ),
        );
        expect(await opened.getVersion(), 2);
        expect((await SongDao(opened).findById(song.id))?.title, song.title);
        expect(
          (await DownloadDao(opened).findBySongId(song.id))?.localPath,
          'audio/legacy.mp3',
        );
        expect(await PlaylistDao(opened).songIds('offline'), [song.id]);
        expect(await BlockedSongDao(opened).songIds('offline'), {song.id});
        expect(await opened.query('playlists'), hasLength(2));
        final columns = await opened.rawQuery('PRAGMA table_info(playlists)');
        expect(
          columns.map((row) => row['name']),
          containsAll(['player_managed', 'archived']),
        );
        final repository = SqlitePlayerPlaylistRepository(opened);
        await repository.save(name: 'Nueva lista', songIds: [song.id]);
        final first = (await repository.list()).single;
        await repository.save(id: first.id, name: 'Lista editada');
        await repository.setArchived(first.id, true);
        await repository.save(name: 'Borrar');
        final deleted = (await repository.list()).firstWhere(
          (p) => p.name == 'Borrar',
        );
        await repository.delete(deleted.id);
        await opened.close();
        opened = await databaseFactoryFfi.openDatabase(
          databasePath,
          options: OpenDatabaseOptions(
            version: databaseVersion,
            onUpgrade: upgradeDatabaseSchema,
          ),
        );
        final persisted = (await SqlitePlayerPlaylistRepository(
          opened,
        ).list()).single;
        expect(persisted.id, first.id);
        expect(persisted.name, 'Lista editada');
        expect(persisted.archived, isTrue);
        expect(persisted.songCount, 1);
        await expectLater(
          SqlitePlayerPlaylistRepository(opened).save(name: ' LISTA EDITADA '),
          throwsA(isA<PlayerPlaylistException>()),
        );
        expect(await opened.rawQuery('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        if (opened?.isOpen ?? false) await opened!.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('applies the v1 migration to an empty existing database', () async {
    final legacyDatabase = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        singleInstance: false,
      ),
    );
    try {
      await upgradeDatabaseSchema(legacyDatabase, 0, databaseVersion);
      final tables = await legacyDatabase.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      expect(
        tables.map((row) => row['name']),
        containsAll([
          'songs',
          'downloads',
          'playlists',
          'playlist_songs',
          'blocked_songs',
        ]),
      );
    } finally {
      await legacyDatabase.close();
    }
  });

  test(
    'persists a download record and rejects missing song references',
    () async {
      final now = DateTime.utc(2026, 10, 17);
      final record = DownloadRecord(
        songId: song.id,
        state: DownloadState.completed,
        bytesReceived: 512,
        totalBytes: 1024,
        localPath: 'audio/blue-hour.mp3',
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        downloads.upsert(record),
        throwsA(isA<DatabaseException>()),
      );
      await songs.upsert(song);
      await downloads.upsert(record);
      expect((await downloads.findBySongId(song.id))?.progress, 0.5);
    },
  );

  test('persists collection membership and scoped blocks', () async {
    await songs.upsert(song);
    await playlists.ensureOfflineCollection();
    await playlists.addSong(
      playlistId: 'offline',
      songId: song.id,
      position: 0,
    );
    await blockedSongs.setBlocked(
      playlistId: 'offline',
      songId: song.id,
      blocked: true,
    );

    expect(await playlists.songIds('offline'), [song.id]);
    expect(await blockedSongs.songIds('offline'), {song.id});
    await songs.delete(song.id);
    expect(await blockedSongs.songIds('offline'), isEmpty);
  });
}
