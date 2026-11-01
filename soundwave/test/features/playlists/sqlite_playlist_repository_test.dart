import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/features/playlists/data/sqlite_playlist_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late SqlitePlaylistRepository repository;
  var ids = 0;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    ids = 0;
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createDatabaseSchema(db),
      ),
    );
    repository = SqlitePlaylistRepository(
      database: database,
      newId: () => 'list-${ids++}',
    );
  });

  tearDown(() => database.close());

  Future<void> addSong(String playlistId, {required int position}) async {
    final songId = 'demo:song-$position';
    await database.insert('songs', {
      'id': songId,
      'provider': 'demo',
      'source_id': 'song-$position',
      'title': 'Song $position',
      'artist': 'Artist',
    });
    await database.insert('playlist_songs', {
      'playlist_id': playlistId,
      'song_id': songId,
      'position': position,
    });
  }

  test('creates a playlist and returns it in the list', () async {
    final created = await repository.create('  Favoritas  ');

    expect(created.id, 'list-0');
    final entries = await repository.loadPlaylists();
    expect(entries, hasLength(1));
    expect(entries.single.playlist.name, 'Favoritas');
    expect(entries.single.playlist.archived, isFalse);
    expect(entries.single.songCount, 0);
  });

  test('renaming updates the same row and keeps its songs', () async {
    final created = await repository.create('Transporte');
    await addSong(created.id, position: 0);

    await repository.rename(id: created.id, name: 'Viajes');

    final entries = await repository.loadPlaylists();
    expect(entries.single.playlist.id, created.id);
    expect(entries.single.playlist.name, 'Viajes');
    expect(entries.single.songCount, 1);
  });

  test('rejects a repeated name with a human message', () async {
    await repository.create('Transporte');

    await expectLater(
      repository.create(' transporte '),
      throwsA(
        isA<RepositoryException>()
            .having(
              (error) => error.code,
              'code',
              RepositoryErrorCode.duplicateName,
            )
            .having(
              (error) => error.message,
              'message',
              'Ya existe una lista con ese nombre. Elige otro.',
            ),
      ),
    );
    expect(await repository.loadPlaylists(), hasLength(1));
  });

  test('renaming onto an existing name is also rejected', () async {
    await repository.create('Transporte');
    final other = await repository.create('Viajes');

    await expectLater(
      repository.rename(id: other.id, name: 'Transporte'),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.duplicateName,
        ),
      ),
    );
    expect(
      (await repository.loadPlaylists())
          .firstWhere((entry) => entry.playlist.id == other.id)
          .playlist
          .name,
      'Viajes',
    );
  });

  test(
    'blocks deleting a playlist in use and offers archiving instead',
    () async {
      final created = await repository.create('Transporte');
      await addSong(created.id, position: 0);

      await expectLater(
        repository.delete(created.id),
        throwsA(
          isA<RepositoryException>()
              .having((error) => error.code, 'code', RepositoryErrorCode.inUse)
              .having(
                (error) => error.message,
                'message',
                contains('Archívala para dejar de verla'),
              ),
        ),
      );
      expect(await repository.loadPlaylists(), hasLength(1));

      await repository.setArchived(id: created.id, archived: true);
      final archived = (await repository.loadPlaylists()).single;
      expect(archived.playlist.archived, isTrue);
      expect(archived.songCount, 1);

      await repository.setArchived(id: created.id, archived: false);
      expect(
        (await repository.loadPlaylists()).single.playlist.archived,
        isFalse,
      );
    },
  );

  test('deletes a playlist that no longer has songs', () async {
    final created = await repository.create('Temporal');
    await addSong(created.id, position: 0);
    await database.delete(
      'playlist_songs',
      where: 'playlist_id = ?',
      whereArgs: [created.id],
    );

    await repository.delete(created.id);

    expect(await repository.loadPlaylists(), isEmpty);
  });

  test('rejects an empty name with a readable message', () async {
    await expectLater(
      repository.create('   '),
      throwsA(
        isA<RepositoryException>().having(
          (error) => error.code,
          'code',
          RepositoryErrorCode.invalidData,
        ),
      ),
    );
  });
}
