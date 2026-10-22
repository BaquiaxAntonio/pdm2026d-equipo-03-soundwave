import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/downloads/data/audio_validation.dart';
import 'package:soundwave/features/downloads/data/http_audio_downloader.dart';
import 'package:soundwave/features/downloads/data/local_audio_file_store.dart';
import 'package:soundwave/features/downloads/data/sqlite_download_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _runNetworkTest = bool.fromEnvironment('RUN_COMMONS_NETWORK_TEST');
const _expectedLength = 647212;
const _userAgent =
    'SoundWave-Academic-Probe/0.1 '
    '(https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave; '
    'https://github.com/JavEstrada09)';
const _sample = Song(
  id: 'wikimedia_commons:157450501',
  title: 'Welcome to Noxville',
  artist: 'Sir Goose of Honker',
  durationMs: 6741,
  provider: 'wikimedia_commons',
  sourceId: '157450501',
);
final _sampleUri = Uri.parse(
  'https://upload.wikimedia.org/wikipedia/commons/7/76/'
  'Welcome_to_Noxville.wav',
);

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'descarga y valida completamente Welcome to Noxville',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'soundwave-commons-probe-',
      );
      Database? database;
      SqliteDownloadRepository? repository;

      try {
        database = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            singleInstance: false,
            version: databaseVersion,
            onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
            onCreate: (db, _) => createDatabaseSchema(db),
          ),
        );
        final files = LocalAudioFileStore(temporaryDirectory);
        final downloader = HttpAudioDownloader((song) async {
          final isVerifiedSample =
              song.id == _sample.id &&
              song.provider == _sample.provider &&
              song.sourceId == _sample.sourceId;
          if (!isVerifiedSample) {
            throw StateError(
              'Download permission is limited to the documented sample.',
            );
          }
          return PermittedAudio(_sampleUri, downloadAllowed: true);
        }, timeout: const Duration(minutes: 1));
        repository = SqliteDownloadRepository(
          database: database,
          files: files,
          openDownload: downloader.open,
        );

        await HttpOverrides.runWithHttpOverrides(
          () => repository!.enqueue(_sample),
          _UserAgentHttpOverrides(_userAgent),
        );

        final record = await repository.findBySongId(_sample.id);
        expect(record, isNotNull);
        expect(record!.state, DownloadState.completed);
        if (record.totalBytes != null) {
          expect(
            record.bytesReceived,
            record.totalBytes,
            reason: 'Received bytes must match the response Content-Length.',
          );
        }
        expect(
          record.bytesReceived,
          _expectedLength,
          reason: 'The downloaded size differs from the documented evaluation.',
        );
        expect(record.localPath, isNotNull);

        final finalFile = File(files.resolve(record.localPath!));
        expect(await finalFile.exists(), isTrue);
        final finalLength = await finalFile.length();
        expect(finalLength, _expectedLength);
        final isValidWav = await isValidAudioFile(finalFile);
        expect(isValidWav, isTrue);

        debugPrint(
          'Commons probe result: Content-Length=${record.totalBytes}, '
          'received=${record.bytesReceived}, fileLength=$finalLength, '
          'isValidAudioFile=$isValidWav, state=${record.state.name}.',
        );
      } finally {
        try {
          await repository?.dispose();
        } finally {
          try {
            await database?.close();
          } finally {
            if (await temporaryDirectory.exists()) {
              await temporaryDirectory.delete(recursive: true);
            }
          }
        }
      }
    },
    skip: _runNetworkTest
        ? false
        : 'Set RUN_COMMONS_NETWORK_TEST=true to run this external network test.',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _UserAgentHttpOverrides extends HttpOverrides {
  _UserAgentHttpOverrides(this.userAgent);

  final String userAgent;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = userAgent;
  }
}
