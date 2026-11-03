import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/dao_providers.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/database/song_dao.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/downloads/data/local_audio_file_store.dart';
import 'package:soundwave/features/downloads/data/sqlite_download_repository.dart';
import 'package:soundwave/features/downloads/download_providers.dart';
import 'package:soundwave/features/search/data/commons_api_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const sample = Song(
    id: 'wikimedia_commons:157450501',
    title: 'Welcome to Noxville',
    artist: 'Sir Goose of Honker',
    provider: 'wikimedia_commons',
    sourceId: '157450501',
  );

  test(
    'native provider rejects unreviewed Commons songs before HTTP',
    () async {
      final container = ProviderContainer();
      try {
        final open = container.read(openDownloadProvider);
        await expectLater(
          open(
            Song.fromMap({
              ...sample.toMap(),
              'id': 'wikimedia_commons:1',
              'source_id': '1',
            }),
          ),
          throwsA(isA<CommonsAudioResolutionException>()),
        );
      } finally {
        container.dispose();
      }
    },
  );

  test(
    'production resolver and HTTP persist reviewed Commons audio after SQLite reopen',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'soundwave-live-',
      );
      final files = LocalAudioFileStore(
        Directory('${directory.path}/downloads'),
      );
      Future<Database> openDb() => databaseFactoryFfi.openDatabase(
        '${directory.path}/metadata.db',
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => createDatabaseSchema(db),
        ),
      );
      var database = await openDb();
      final container = ProviderContainer(
        overrides: [
          songDaoProvider.overrideWith((ref) async => SongDao(database)),
        ],
      );
      var repository = SqliteDownloadRepository(
        database: database,
        files: files,
        openDownload: container.read(openDownloadProvider),
      );
      try {
        await repository.enqueue(sample);
        final record = (await repository.findBySongId(sample.id))!;
        expect(record.state, DownloadState.completed);
        expect(record.bytesReceived, 647212);
        expect(await files.exists(record.localPath!), isTrue);
        expect(
          (await repository.songs.findById(sample.id))!.license,
          'CC BY 4.0',
        );
        await repository.dispose();
        await database.close();
        database = await openDb();
        repository = SqliteDownloadRepository(
          database: database,
          files: files,
          openDownload: (_) async => throw const SocketException('offline'),
        );
        await repository.recoverInterrupted();
        expect(
          (await repository.findBySongId(sample.id))!.state,
          DownloadState.completed,
        );
        expect(await files.exists(record.localPath!), isTrue);
        final credits = (await repository.songs.findById(sample.id))!;
        expect(credits.license, 'CC BY 4.0');
        expect(credits.attribution, isNotEmpty);
        expect(credits.sourceUrl, contains('commons.wikimedia.org'));
      } finally {
        container.dispose();
        await repository.dispose();
        await database.close();
      }
    },
    skip: const bool.fromEnvironment('RUN_COMMONS_NETWORK_TEST')
        ? false
        : 'External Commons network test is opt-in.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
