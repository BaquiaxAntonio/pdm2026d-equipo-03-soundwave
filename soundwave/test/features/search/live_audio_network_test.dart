import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/features/search/data/commons_api_client.dart';
import 'package:soundwave/features/downloads/data/http_audio_downloader.dart';
import 'package:soundwave/features/downloads/data/local_audio_file_store.dart';
import 'package:soundwave/features/downloads/data/sqlite_download_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'búsqueda en vivo, licencia, descarga íntegra y reapertura offline',
    () async {
      sqfliteFfiInit();
      final client = CommonsApiClient();
      final resolver = CommonsAudioResolver(client);
      final items = await client.search('Beethoven');
      final candidates = items
          .where(
            (item) =>
                hasSupportedCommonsLicense(item) &&
                (item.song.durationMs ?? 0) > 60000 &&
                (item.fileSizeBytes ?? 0) < 20000000,
          )
          .take(2)
          .toList();
      expect(
        candidates,
        hasLength(2),
        reason:
            'Se requieren dos pistas completas y libres en los resultados reales.',
      );
      final directory = await Directory.systemTemp.createTemp(
        'soundwave-live-',
      );
      final db = await databaseFactoryFfi.openDatabase(
        '${directory.path}/probe.db',
        options: OpenDatabaseOptions(
          version: databaseVersion,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) => createDatabaseSchema(db),
        ),
      );
      final files = LocalAudioFileStore(Directory('${directory.path}/audio'));
      final downloader = HttpAudioDownloader((song) async {
        final resolved = await resolver.resolve(song);
        return PermittedAudio(
          resolved.uri,
          downloadAllowed: resolved.downloadAllowed,
          sha1: resolved.sha1,
          size: resolved.fileSizeBytes,
        );
      }, timeout: const Duration(minutes: 1));
      var repository = SqliteDownloadRepository(
        database: db,
        files: files,
        openDownload: downloader.open,
      );
      try {
        for (final item in candidates) {
          await repository.enqueue(item.song);
          final record = await repository.findBySongId(item.song.id);
          expect(record?.state, DownloadState.completed);
          expect(record?.bytesReceived, item.fileSizeBytes);
          expect(record?.localPath, endsWith('.ogg'));
          expect(await files.exists(record!.localPath!), isTrue);
          debugPrint(
            'VALIDADO: ${item.song.id} | ${item.song.title} | ${item.licenseShortName} | ${record.bytesReceived} bytes',
          );
        }
        await repository.dispose();
        repository = SqliteDownloadRepository(
          database: db,
          files: files,
          openDownload: (_) async => throw StateError('Sin red'),
        );
        await repository.recoverInterrupted();
        final records = await repository.loadDownloads();
        expect(records, hasLength(2));
        expect(
          records.every((r) => r.state == DownloadState.completed),
          isTrue,
        );
      } finally {
        await repository.dispose();
        await db.close();
        await directory.delete(recursive: true);
      }
    },
    skip: !const bool.fromEnvironment('RUN_COMMONS_NETWORK_TEST'),
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
