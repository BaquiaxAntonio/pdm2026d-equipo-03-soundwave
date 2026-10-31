import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:soundwave/core/database/blocked_song_dao.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/features/player/data/player_playlist_repository.dart';
import 'package:soundwave/features/player/player_song_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  for (final sqlite in [false, true]) {
    group(sqlite ? 'SQLite' : 'demo', () {
      Database? database;
      late PlayerPlaylistRepository repository;

      setUp(() async {
        if (!sqlite) {
          repository = MemoryPlayerPlaylistRepository(
            catalog: [
              for (final number in [1, 2, 3])
                PlayerSongLocal(
                  id: 'song:$number',
                  title: number == 1 ? 'Canción' : 'Canción $number',
                  artist: 'Artista',
                  durationSeconds: 0,
                ),
            ],
          );
          return;
        }
        database = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            singleInstance: false,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            version: databaseVersion,
            onCreate: (db, _) => createDatabaseSchema(db),
          ),
        );
        repository = SqlitePlayerPlaylistRepository(database!);
        await database!.insert('songs', {
          'id': 'song:1',
          'provider': 'test',
          'source_id': '1',
          'title': 'Canción',
          'artist': 'Artista',
        });
        for (final number in [2, 3]) {
          await database!.insert('songs', {
            'id': 'song:$number',
            'provider': 'test',
            'source_id': '$number',
            'title': 'Canción $number',
            'artist': 'Artista',
          });
        }
      });

      tearDown(() async {
        await database?.close();
      });

      test('create, update same ID, archive, restore and delete', () async {
        await repository.save(name: '  Viaje  ');
        final first = (await repository.list()).single;
        expect(first.name, 'Viaje');
        await repository.save(id: first.id, name: 'Viaje nocturno');
        final edited = (await repository.list()).single;
        expect(edited.id, first.id);
        expect(edited.name, 'Viaje nocturno');
        await repository.setArchived(first.id, true);
        expect((await repository.list()).single.archived, isTrue);
        await repository.setArchived(first.id, false);
        expect((await repository.list()).single.archived, isFalse);
        await repository.delete(first.id);
        expect(await repository.list(), isEmpty);
      });

      test('duplicate names give a human message on create and edit', () async {
        await repository.save(name: 'Viaje');
        await expectLater(
          repository.save(name: ' viaje '),
          throwsA(
            isA<PlayerPlaylistException>().having(
              (e) => e.message,
              'message',
              'Ya existe una lista con ese nombre.',
            ),
          ),
        );
        await repository.save(name: 'Estudio');
        final study = (await repository.list()).firstWhere(
          (p) => p.name == 'Estudio',
        );
        await expectLater(
          repository.save(id: study.id, name: 'VIAJE'),
          throwsA(isA<PlayerPlaylistException>()),
        );
        expect((await repository.list()).length, 2);
      });

      test(
        'cannot delete a referenced playlist; archiving preserves songs',
        () async {
          await repository.save(
            name: 'Con canciones',
            songIds: ['song:1', 'song:1'],
          );
          final entry = (await repository.list()).single;
          expect(entry.songCount, 1);
          await expectLater(
            repository.delete(entry.id),
            throwsA(
              isA<PlayerPlaylistException>().having(
                (e) => e.inUse,
                'inUse',
                isTrue,
              ),
            ),
          );
          await repository.setArchived(entry.id, true);
          final archived = (await repository.list()).single;
          expect(archived.archived, isTrue);
          expect(archived.songCount, 1);
          if (sqlite) {
            expect(await database!.query('playlist_songs'), hasLength(1));
            expect(await database!.query('songs'), hasLength(3));
          }
        },
      );

      test('rejects blank names', () async {
        await expectLater(
          repository.save(name: '  '),
          throwsA(isA<PlayerPlaylistException>()),
        );
        expect(await repository.list(), isEmpty);
      });

      test('an empty list can receive songs and later remove them', () async {
        await repository.save(name: 'Vacía');
        final entry = (await repository.list()).single;
        expect(await repository.songs(entry.id), isEmpty);
        await repository.save(
          id: entry.id,
          name: 'Con canción',
          songIds: ['song:1'],
        );
        expect((await repository.list()).single.id, entry.id);
        expect((await repository.list()).single.songCount, 1);
        expect((await repository.songs(entry.id)).map((s) => s.id), ['song:1']);
        expect((await repository.songs(entry.id)).single.title, 'Canción');
        await repository.save(id: entry.id, name: 'Renombrada');
        expect((await repository.songs(entry.id)).map((s) => s.id), ['song:1']);
        await repository.save(
          id: entry.id,
          name: 'Vacía de nuevo',
          songIds: [],
        );
        expect(await repository.songs(entry.id), isEmpty);
        await repository.delete(entry.id);
        expect(await repository.list(), isEmpty);
      });

      test(
        'editing preserves existing order and appends only new songs',
        () async {
          await repository.save(name: 'Orden', songIds: ['song:1', 'song:2']);
          final entry = (await repository.list()).single;
          await repository.save(
            id: entry.id,
            name: 'Orden',
            songIds: ['song:3', 'song:1', 'song:3'],
          );
          expect((await repository.songs(entry.id)).map((s) => s.id), [
            'song:1',
            'song:3',
          ]);
          expect((await repository.list()).single.songCount, 2);
        },
      );

      if (sqlite) {
        test(
          'retained memberships keep blocks; edits do not affect other lists',
          () async {
            await repository.save(
              name: 'Editar',
              songIds: ['song:1', 'song:2'],
            );
            final entry = (await repository.list()).single;
            final dao = BlockedSongDao(database!);
            await dao.setBlocked(
              playlistId: entry.id,
              songId: 'song:1',
              blocked: true,
            );
            await dao.setBlocked(
              playlistId: entry.id,
              songId: 'song:2',
              blocked: true,
            );
            final before = (await database!.query(
              'blocked_songs',
              where: 'playlist_id = ? AND song_id = ?',
              whereArgs: [entry.id, 'song:1'],
            )).single;
            await repository.save(name: 'Otra', songIds: ['song:2']);
            final other = (await repository.list()).firstWhere(
              (p) => p.name == 'Otra',
            );
            await repository.save(
              id: entry.id,
              name: 'Editada',
              songIds: ['song:1', 'song:3'],
            );
            expect(await dao.songIds(entry.id), {'song:1'});
            final after = (await database!.query(
              'blocked_songs',
              where: 'playlist_id = ? AND song_id = ?',
              whereArgs: [entry.id, 'song:1'],
            )).single;
            expect(after, before);
            expect((await repository.songs(other.id)).single.id, 'song:2');
            expect(
              await database!.rawQuery('PRAGMA foreign_key_check'),
              isEmpty,
            );
          },
        );

        test(
          'a failed membership update rolls back the name and songs',
          () async {
            await repository.save(
              name: 'Original',
              songIds: ['song:1', 'song:2'],
            );
            final entry = (await repository.list()).single;
            await expectLater(
              repository.save(
                id: entry.id,
                name: 'Cambio',
                songIds: ['song:3', 'missing'],
              ),
              throwsA(isA<DatabaseException>()),
            );
            expect((await repository.list()).single.name, 'Original');
            expect((await repository.songs(entry.id)).map((s) => s.id), [
              'song:1',
              'song:2',
            ]);
          },
        );

        test(
          'other modules collections are hidden and cannot be edited',
          () async {
            await database!.insert('playlists', {
              'id': 'offline',
              'name': 'Viaje',
            });
            await repository.save(name: 'Viaje');
            expect(await repository.list(), hasLength(1));
            await expectLater(
              repository.save(id: 'offline', name: 'Otro'),
              throwsA(isA<PlayerPlaylistException>()),
            );
            await repository.setArchived('offline', true);
            await repository.delete('offline');
            final offline = (await database!.query(
              'playlists',
              where: 'id = ?',
              whereArgs: ['offline'],
            )).single;
            expect(offline['name'], 'Viaje');
            expect(offline['archived'], 0);
          },
        );
      }
    });
  }

  test('edited songs survive closing and reopening the SQLite file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'player-list-edit-',
    );
    final databasePath = path.join(directory.path, 'playlists.db');
    Database? db;
    Future<Database> open() => databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createDatabaseSchema(db),
      ),
    );
    try {
      db = await open();
      await db.insert('songs', {
        'id': 'saved',
        'provider': 'test',
        'source_id': 'saved',
        'title': 'Persistida',
        'artist': 'Artista',
      });
      var repository = SqlitePlayerPlaylistRepository(db);
      await repository.save(name: 'Vacía');
      final entry = (await repository.list()).single;
      await repository.save(
        id: entry.id,
        name: 'Con canción',
        songIds: ['saved'],
      );
      await db.close();
      db = await open();
      repository = SqlitePlayerPlaylistRepository(db);
      expect((await repository.list()).single.id, entry.id);
      expect((await repository.list()).single.songCount, 1);
      expect((await repository.songs(entry.id)).single.title, 'Persistida');
    } finally {
      if (db?.isOpen ?? false) await db!.close();
      await directory.delete(recursive: true);
    }
  });
}
