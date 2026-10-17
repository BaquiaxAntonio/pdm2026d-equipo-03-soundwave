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
