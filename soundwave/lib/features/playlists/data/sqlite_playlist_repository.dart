import 'package:sqflite/sqflite.dart';

import '../../../core/contracts/playlist_repository.dart';
import '../../../core/database/playlist_dao.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/models/playlist.dart';

/// SQLite implementation for the playlist CRUD. Every expected failure becomes
/// a [RepositoryException] with a message a person can read; raw SQL errors
/// never reach the form or the list.
class SqlitePlaylistRepository implements PlaylistRepository {
  SqlitePlaylistRepository({required this.database, String Function()? newId})
    : _newId = newId ?? _defaultId;

  final Database database;
  final String Function() _newId;

  static String _defaultId() => 'list-${DateTime.now().microsecondsSinceEpoch}';

  PlaylistDao get _playlists => PlaylistDao(database);

  @override
  Future<List<PlaylistEntry>> loadPlaylists() => _playlists.entries();

  @override
  Future<Playlist> create(String name) async {
    final normalized = _validName(name);
    final id = _newId();
    try {
      await _playlists.create(id: id, name: normalized);
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
    return Playlist(id: id, name: normalized);
  }

  /// Updates the same row: the id stays untouched, even when the name changes.
  @override
  Future<void> rename({required String id, required String name}) async {
    final normalized = _validName(name);
    try {
      final updated = await _playlists.rename(id: id, name: normalized);
      if (updated == 0) throw _notFound;
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> setArchived({required String id, required bool archived}) async {
    final updated = await _playlists.setArchived(id: id, archived: archived);
    if (updated == 0) throw _notFound;
  }

  @override
  Future<void> delete(String id) async {
    try {
      await database.transaction((transaction) async {
        final playlists = PlaylistDao(transaction);
        final playlist = await playlists.findById(id);
        if (playlist == null) throw _notFound;
        final count = await playlists.songCount(id);
        if (count > 0) {
          // Nothing is deleted: the caller offers archiving instead.
          throw RepositoryException(
            RepositoryErrorCode.inUse,
            'La lista «${playlist.name}» tiene $count '
            '${count == 1 ? 'canción' : 'canciones'}. '
            'Archívala para dejar de verla.',
          );
        }
        await playlists.delete(id);
      });
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
  }

  RepositoryException _translate(DatabaseException error) {
    if (error.isUniqueConstraintError()) {
      return const RepositoryException(
        RepositoryErrorCode.duplicateName,
        'Ya existe una lista con ese nombre. Elige otro.',
      );
    }
    return RepositoryException(
      RepositoryErrorCode.storage,
      'No pudimos guardar la lista. Inténtalo de nuevo.',
      cause: error,
    );
  }

  static const _notFound = RepositoryException(
    RepositoryErrorCode.notFound,
    'Esa lista ya no existe.',
  );

  static String _validName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'El nombre de la lista no puede estar vacío.',
      );
    }
    if (name.length > 60) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'Usa un nombre de 60 caracteres o menos.',
      );
    }
    return name;
  }
}
