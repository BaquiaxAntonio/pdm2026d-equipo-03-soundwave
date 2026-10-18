import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/database/download_dao.dart';
import 'package:soundwave/core/database/schema.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/downloads/data/local_audio_file_store.dart';
import 'package:soundwave/features/downloads/data/sqlite_download_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const song = Song(
    id: 'fixture:audio',
    title: 'Audio',
    artist: 'Test',
    provider: 'fixture',
    sourceId: 'audio',
  );
  late Database database;
  late LocalAudioFileStore files;
  late SqliteDownloadRepository repository;
  late OpenDownload source;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: databaseVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => createDatabaseSchema(db),
      ),
    );
    files = LocalAudioFileStore(
      await Directory.systemTemp.createTemp('soundwave-mvp06-'),
    );
    source = (_) async => DownloadInput(Stream.value([1, 2, 3]), totalBytes: 3);
    repository = SqliteDownloadRepository(
      database: database,
      files: files,
      openDownload: (song) => source(song),
    );
  });
  tearDown(() async {
    await repository.dispose();
    await database.close();
  });

  test(
    'commits bytes before completion and persists across repository recreation',
    () async {
      await repository.enqueue(song);
      final record = (await repository.findBySongId(song.id))!;
      expect(record.state, DownloadState.completed);
      expect(record.progress, 1);
      expect(await File(files.resolve(record.localPath!)).readAsBytes(), [
        1,
        2,
        3,
      ]);
      final reopened = SqliteDownloadRepository(
        database: database,
        files: files,
        openDownload: source,
      );
      expect(
        (await reopened.findBySongId(song.id))!.localPath,
        record.localPath,
      );
      await reopened.dispose();
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test(
    'prevents simultaneous duplicate transfers and emits real progress',
    () async {
      final bytes = StreamController<List<int>>();
      final opened = Completer<void>();
      source = (_) async {
        opened.complete();
        return DownloadInput(bytes.stream, totalBytes: 4);
      };
      final seen = <DownloadRecord>[];
      final half = Completer<void>();
      final subscription = repository.watchDownloads().listen((records) {
        seen.addAll(records);
        if (records.any((r) => r.bytesReceived == 2) && !half.isCompleted) {
          half.complete();
        }
      });
      final task = repository.enqueue(song);
      await opened.future;
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
      bytes.add([1, 2]);
      await half.future.timeout(const Duration(seconds: 5));
      expect(seen.any((r) => r.progress == 0.5), isTrue);
      bytes.add([3, 4]);
      await bytes.close();
      await task;
      await subscription.cancel();
    },
  );

  test('unknown length stays indeterminate', () async {
    source = (_) async => DownloadInput(Stream.value([1, 2]));
    await repository.enqueue(song);
    expect((await repository.findBySongId(song.id))!.progress, isNull);
  });

  test(
    'incomplete audio fails without final path and can retry from zero',
    () async {
      source = (_) async => DownloadInput(Stream.value([1]), totalBytes: 3);
      await expectLater(
        repository.enqueue(song),
        throwsA(isA<RepositoryException>()),
      );
      final failed = (await repository.findBySongId(song.id))!;
      expect(failed.state, DownloadState.failed);
      expect(failed.localPath, isNull);
      source = (_) async => DownloadInput(Stream.value([4, 5]), totalBytes: 2);
      await repository.retry(song.id);
      final retried = (await repository.findBySongId(song.id))!;
      expect(retried.state, DownloadState.completed);
      expect(retried.bytesReceived, 2);
    },
  );

  test('network error and empty response never become available', () async {
    source = (_) async =>
        DownloadInput(Stream.error(const SocketException('offline')));
    await expectLater(
      repository.enqueue(song),
      throwsA(isA<SocketException>()),
    );
    expect(
      (await repository.findBySongId(song.id))!.state,
      DownloadState.failed,
    );
    source = (_) async => const DownloadInput(Stream.empty());
    await expectLater(
      repository.retry(song.id),
      throwsA(isA<RepositoryException>()),
    );
    expect((await repository.findBySongId(song.id))!.localPath, isNull);
  });

  test(
    'recovers interrupted records and reports missing completed files',
    () async {
      await repository.enqueue(song);
      final original = (await repository.findBySongId(song.id))!;
      await DownloadDao(database).upsert(
        DownloadRecord.fromMap({
          ...original.toMap(),
          'state': 'downloading',
          'local_path': null,
        }),
      );
      await repository.recoverInterrupted();
      expect(
        (await repository.findBySongId(song.id))!.state,
        DownloadState.failed,
      );
      await DownloadDao(database).upsert(
        DownloadRecord.fromMap({
          ...original.toMap(),
          'local_path': 'audio/absent.audio',
        }),
      );
      await repository.recoverInterrupted();
      expect(
        (await repository.findBySongId(song.id))!.errorMessage,
        'Audio missing.',
      );
    },
  );

  test(
    'pending removal survives recreation and undo retains the file',
    () async {
      await repository.enqueue(song);
      await repository.requestRemoval(
        song.id,
        undoUntil: DateTime.now().add(const Duration(minutes: 1)),
      );
      final reopened = SqliteDownloadRepository(
        database: database,
        files: files,
        openDownload: source,
      );
      final pending = (await reopened.findBySongId(song.id))!;
      expect(pending.state, DownloadState.pendingDeletion);
      expect(await files.exists(pending.localPath!), isTrue);
      await reopened.undoRemoval(song.id);
      expect(
        (await repository.findBySongId(song.id))!.state,
        DownloadState.completed,
      );
      await reopened.dispose();
    },
  );

  test(
    'file store rejects traversal and empty or unrelated temporary files',
    () async {
      expect(
        () => files.resolve('../outside'),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => files.resolve(files.root.path),
        throwsA(isA<RepositoryException>()),
      );
      final temporary = await files.createTemporaryPath(song.id);
      await expectLater(
        files.commit(temporary, song.id),
        throwsA(isA<RepositoryException>()),
      );
      await File(temporary).writeAsBytes([1]);
      await expectLater(
        files.commit(temporary, 'different'),
        throwsA(isA<RepositoryException>()),
      );
    },
  );
}
