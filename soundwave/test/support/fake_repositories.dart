import 'dart:async';

import 'package:soundwave/core/contracts/audio_file_store.dart';
import 'package:soundwave/core/contracts/catalog_repository.dart';
import 'package:soundwave/core/contracts/download_repository.dart';
import 'package:soundwave/core/contracts/playback_preferences_repository.dart';
import 'package:soundwave/core/errors/repository_exception.dart';
import 'package:soundwave/core/models/download_record.dart';
import 'package:soundwave/core/models/song.dart';

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository([Iterable<Song> songs = const []])
    : _songs = [...songs];

  final List<Song> _songs;

  @override
  Future<Song?> findById(String songId) async {
    for (final song in _songs) {
      if (song.id == songId) return song;
    }
    return null;
  }

  @override
  Future<List<Song>> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List.unmodifiable(_songs);
    return List.unmodifiable(
      _songs.where(
        (song) =>
            song.title.toLowerCase().contains(normalized) ||
            song.artist.toLowerCase().contains(normalized),
      ),
    );
  }

  @override
  Future<void> saveAll(Iterable<Song> songs) async {
    for (final song in songs) {
      _songs.removeWhere((existing) => existing.id == song.id);
      _songs.add(song);
    }
  }
}

class FakeDownloadRepository implements DownloadRepository {
  final Map<String, DownloadRecord> _records = {};
  final _changes = StreamController<List<DownloadRecord>>.broadcast();

  List<DownloadRecord> get records => List.unmodifiable(_records.values);

  void _emit() => _changes.add(records);

  @override
  Stream<List<DownloadRecord>> watchDownloads() async* {
    yield records;
    yield* _changes.stream;
  }

  @override
  Future<DownloadRecord?> findBySongId(String songId) async => _records[songId];

  @override
  Future<void> enqueue(Song song) async {
    if (_records.containsKey(song.id)) {
      throw const RepositoryException(
        RepositoryErrorCode.conflict,
        'A download already exists for this song.',
      );
    }
    final now = DateTime.now();
    _records[song.id] = DownloadRecord(
      songId: song.id,
      state: DownloadState.queued,
      bytesReceived: 0,
      createdAt: now,
      updatedAt: now,
    );
    _emit();
  }

  @override
  Future<void> retry(String songId) async {
    final record = _required(songId);
    _records[songId] = _copy(record, state: DownloadState.queued);
    _emit();
  }

  @override
  Future<void> requestRemoval(
    String songId, {
    required DateTime undoUntil,
  }) async {
    final record = _required(songId);
    _records[songId] = _copy(
      record,
      state: DownloadState.pendingDeletion,
      deletionDeadline: undoUntil,
    );
    _emit();
  }

  @override
  Future<void> undoRemoval(String songId) async {
    final record = _required(songId);
    _records[songId] = _copy(
      record,
      state: DownloadState.completed,
      deletionDeadline: null,
    );
    _emit();
  }

  DownloadRecord _required(String songId) =>
      _records[songId] ??
      (throw const RepositoryException(
        RepositoryErrorCode.notFound,
        'No download exists for this song.',
      ));

  DownloadRecord _copy(
    DownloadRecord record, {
    required DownloadState state,
    DateTime? deletionDeadline,
  }) => DownloadRecord(
    songId: record.songId,
    state: state,
    bytesReceived: record.bytesReceived,
    totalBytes: record.totalBytes,
    localPath: record.localPath,
    createdAt: record.createdAt,
    updatedAt: DateTime.now(),
    errorMessage: record.errorMessage,
    deletionDeadline: deletionDeadline,
  );

  Future<void> dispose() => _changes.close();
}

class FakeAudioFileStore implements AudioFileStore {
  final Map<String, List<int>> files = {};
  int _nextTemporaryId = 0;

  @override
  Future<String> createTemporaryPath(String songId) async =>
      '.part/${songId}_${_nextTemporaryId++}';

  @override
  Future<String> commit(String temporaryPath, String songId) async {
    final bytes = files.remove(temporaryPath);
    if (bytes == null) {
      throw const RepositoryException(
        RepositoryErrorCode.notFound,
        'Temporary audio file does not exist.',
      );
    }
    final finalPath = '$songId.audio';
    files[finalPath] = bytes;
    return finalPath;
  }

  @override
  String resolve(String relativePath) => relativePath;

  @override
  Future<bool> exists(String relativePath) async =>
      files.containsKey(relativePath);

  @override
  Future<void> delete(String relativePath) async => files.remove(relativePath);
}

class FakePlaybackPreferencesRepository
    implements PlaybackPreferencesRepository {
  final Map<String, Set<String>> _blocked = {};

  @override
  Future<Set<String>> blockedSongIds(String collectionId) async =>
      Set.unmodifiable(_blocked[collectionId] ?? const {});

  @override
  Future<void> setBlocked({
    required String collectionId,
    required String songId,
    required bool blocked,
  }) async {
    final songs = _blocked.putIfAbsent(collectionId, () => <String>{});
    if (blocked) {
      songs.add(songId);
    } else {
      songs.remove(songId);
    }
  }
}

DownloadRecord completedRecord(String songId) {
  final now = DateTime.now();
  return DownloadRecord(
    songId: songId,
    state: DownloadState.completed,
    bytesReceived: 1024,
    totalBytes: 1024,
    localPath: '$songId.audio',
    createdAt: now,
    updatedAt: now,
  );
}
