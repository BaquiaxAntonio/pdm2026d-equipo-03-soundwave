import 'dart:async';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../../core/contracts/audio_file_store.dart';
import '../../../core/contracts/download_repository.dart';
import '../../../core/database/download_dao.dart';
import '../../../core/database/song_dao.dart';
import '../../../core/database/playlist_dao.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/models/download_record.dart';
import '../../../core/models/song.dart';
import 'download_input.dart';
import 'local_audio_file_store.dart';
export 'download_input.dart';

/// Persistent Android implementation; URL resolution and safe playback release
/// are injected by their owners. Web keeps the separate demonstration store.
class SqliteDownloadRepository implements DownloadRepository {
  SqliteDownloadRepository({
    required this.database,
    required this.files,
    required this.openDownload,
    this.canDelete,
    DateTime Function()? clock,
  }) : downloads = DownloadDao(database),
       songs = SongDao(database),
       now = clock ?? DateTime.now;

  final Database database;
  final AudioFileStore files;
  final OpenDownload openDownload;
  final Future<bool> Function(String songId)? canDelete;
  final DateTime Function() now;
  Future<void> _mutations = Future.value();
  bool _disposed = false;
  Future<T> _exclusive<T>(Future<T> Function() action) {
    final result = _mutations.then((_) => action());
    _mutations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  final DownloadDao downloads;
  final SongDao songs;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _busy = <String>{};

  @override
  Future<List<DownloadRecord>> loadDownloads() => downloads.all();

  @override
  Stream<List<DownloadRecord>> watchDownloads() => Stream.multi((listener) {
    var pending = Future<void>.value();
    void refresh() {
      pending = pending.then((_) async {
        try {
          listener.add(await downloads.all());
        } catch (error, stack) {
          listener.addError(error, stack);
        }
      });
    }

    final subscription = _changes.stream.listen(
      (_) => refresh(),
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
    refresh();
  });

  @override
  Future<DownloadRecord?> findBySongId(String songId) =>
      downloads.findBySongId(songId);

  RepositoryException _conflict() => const RepositoryException(
    RepositoryErrorCode.conflict,
    'A download already exists or is active for this song.',
  );

  Future<DownloadRecord> _required(String id) async =>
      await downloads.findBySongId(id) ??
      (throw const RepositoryException(
        RepositoryErrorCode.notFound,
        'Download not found.',
      ));

  Future<void> _save(DownloadRecord record) async {
    await database.transaction((tx) async {
      await DownloadDao(tx).upsert(record);
      if (record.state == DownloadState.completed) {
        final playlists = PlaylistDao(tx);
        await playlists.ensureOfflineCollection();
        if (!(await playlists.songIds('offline')).contains(record.songId)) {
          final rows = await tx.rawQuery(
            "SELECT MAX(position) AS last FROM playlist_songs WHERE playlist_id = ?",
            ['offline'],
          );
          await playlists.addSong(
            playlistId: 'offline',
            songId: record.songId,
            position: ((rows.single['last'] as int?) ?? -1) + 1,
          );
        }
      }
    });
    if (!_disposed) _changes.add(null);
  }

  @override
  Future<void> enqueue(Song song) async {
    if (!_busy.add(song.id)) throw _conflict();
    try {
      await songs.upsert(song);
      final timestamp = now();
      final record = DownloadRecord(
        songId: song.id,
        state: DownloadState.queued,
        bytesReceived: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await database.transaction((tx) async {
        if (await DownloadDao(tx).findBySongId(song.id) != null) {
          throw _conflict();
        }
        await DownloadDao(tx).upsert(record);
      });
      _changes.add(null);
      await _transfer(song, record);
    } finally {
      _busy.remove(song.id);
    }
  }

  @override
  Future<void> retry(String songId) async {
    if (!_busy.add(songId)) throw _conflict();
    try {
      final record = await _required(songId);
      if (record.state != DownloadState.failed) throw _conflict();
      final song = await songs.findById(songId);
      if (song == null) {
        throw const RepositoryException(
          RepositoryErrorCode.notFound,
          'Song not found.',
        );
      }
      await _transfer(song, record);
    } finally {
      _busy.remove(songId);
    }
  }

  Future<void> _transfer(Song song, DownloadRecord previous) async {
    var received = 0;
    int? total;
    DownloadRecord record(DownloadState state, {String? path, String? error}) =>
        DownloadRecord(
          songId: song.id,
          state: state,
          bytesReceived: received,
          totalBytes: total,
          localPath: path,
          errorMessage: error,
          createdAt: previous.createdAt,
          updatedAt: now(),
        );
    await _save(record(DownloadState.downloading));
    DownloadInput? input;
    try {
      input = await openDownload(song);
      if (input.totalBytes != null && input.totalBytes! < 0) {
        throw const RepositoryException(
          RepositoryErrorCode.invalidData,
          'Invalid audio length.',
        );
      }
      total = input.totalBytes;
      final temporary = await files.createTemporaryPath(song.id);
      final output = await File(temporary).open(mode: FileMode.write);
      try {
        await for (final chunk in input.bytes) {
          await output.writeFrom(chunk);
          received += chunk.length;
          await _save(record(DownloadState.downloading));
        }
        await output.flush();
      } finally {
        await output.close();
      }
      if (received == 0 || (total != null && received != total)) {
        throw const RepositoryException(
          RepositoryErrorCode.invalidData,
          'Audio transfer is empty or incomplete.',
        );
      }
      final relative = await files.commit(temporary, song.id);
      await _save(record(DownloadState.completed, path: relative));
    } catch (error) {
      await _save(record(DownloadState.failed, error: error.toString()));
      rethrow;
    } finally {
      input?.close?.call();
    }
  }

  /// Call once at startup, before allowing transfers. Partial files remain for
  /// future reconciliation; they are never exposed as available downloads.
  Future<void> recoverInterrupted() async {
    if (_busy.isNotEmpty) throw _conflict();
    for (final record in await downloads.all()) {
      final interrupted =
          record.state == DownloadState.downloading ||
          record.state == DownloadState.queued;
      final missing =
          record.state == DownloadState.completed &&
          (record.localPath == null || !await files.exists(record.localPath!));
      if (interrupted || missing) {
        await _save(
          DownloadRecord.fromMap({
            ...record.toMap(),
            'state': DownloadState.failed.name,
            'local_path': null,
            'error_message': interrupted
                ? 'Download interrupted.'
                : 'Audio missing.',
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }),
        );
      }
    }
    await finalizeExpiredRemovals();
    final store = files;
    if (store is LocalAudioFileStore) {
      await store.reconcile({
        for (final record in await downloads.all())
          if (record.localPath != null) record.localPath!,
      });
    }
  }

  /// Re-read under the same operation queue as Undo; file deletion comes first,
  /// so a storage failure retains the record for a later retry.
  Future<void> finalizeExpiredRemovals() => _exclusive(() async {
    for (final record in await downloads.all()) {
      if (record.state != DownloadState.pendingDeletion ||
          record.deletionDeadline == null ||
          record.deletionDeadline!.isAfter(now()) ||
          _busy.contains(record.songId)) {
        continue;
      }
      // Without a playback coordinator we retain the file, safely reversible.
      if (canDelete == null || !await canDelete!(record.songId)) continue;
      if (record.localPath != null) await files.delete(record.localPath!);
      await database.transaction((tx) async {
        await tx.delete(
          'playlist_songs',
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: ['offline', record.songId],
        );
        await DownloadDao(tx).delete(record.songId);
      });
      if (!_disposed) _changes.add(null);
    }
  });

  @override
  Future<void> requestRemoval(String songId, {required DateTime undoUntil}) =>
      _exclusive(() async {
        if (_busy.contains(songId)) throw _conflict();
        final record = await _required(songId);
        if ((record.state != DownloadState.completed &&
                record.state != DownloadState.failed) ||
            !undoUntil.isAfter(now())) {
          throw _conflict();
        }
        await _save(
          DownloadRecord.fromMap({
            ...record.toMap(),
            'state': DownloadState.pendingDeletion.name,
            'deletion_deadline': undoUntil.millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          }),
        );
      });

  @override
  Future<void> undoRemoval(String songId) => _exclusive(() async {
    final record = await _required(songId);
    if (record.state != DownloadState.pendingDeletion ||
        record.deletionDeadline == null ||
        !record.deletionDeadline!.isAfter(now())) {
      throw _conflict();
    }
    await _save(
      DownloadRecord.fromMap({
        ...record.toMap(),
        'state':
            record.localPath != null && await files.exists(record.localPath!)
            ? DownloadState.completed.name
            : DownloadState.failed.name,
        'deletion_deadline': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  });

  /// The shared provider owns the database. Await active calls before disposal.
  Future<void> dispose() async {
    await _mutations;
    _disposed = true;
    await _changes.close();
  }
}
