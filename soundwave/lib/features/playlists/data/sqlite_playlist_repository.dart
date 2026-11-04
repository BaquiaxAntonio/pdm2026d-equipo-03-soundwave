import 'package:sqflite/sqflite.dart';

import '../../../core/contracts/playlist_repository.dart';
import '../../../core/database/playlist_dao.dart';
import '../../../core/database/song_dao.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/models/playlist.dart';
import '../../../core/models/song.dart';

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
      await database.transaction((transaction) async {
        final playlists = PlaylistDao(transaction);
        if (await playlists.nameExists(normalized)) throw _duplicate;
        await playlists.create(id: id, name: normalized);
      });
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
    return Playlist(id: id, name: normalized);
  }

  /// Updates the same row: the id stays untouched, even when the name changes.
  @override
  Future<void> rename({required String id, required String name}) async {
    _rejectFavorites(id);
    final normalized = _validName(name);
    try {
      await database.transaction((transaction) async {
        final playlists = PlaylistDao(transaction);
        if (await playlists.nameExists(normalized, exceptId: id)) {
          throw _duplicate;
        }
        final updated = await playlists.rename(id: id, name: normalized);
        if (updated == 0) throw _notFound;
      });
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
  }

  @override
  Future<void> setArchived({required String id, required bool archived}) async {
    _rejectFavorites(id);
    final updated = await _playlists.setArchived(id: id, archived: archived);
    if (updated == 0) throw _notFound;
  }

  @override
  Future<void> delete(String id) async {
    _rejectFavorites(id);
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

  @override
  Future<List<Song>> loadSongs(String playlistId) =>
      _playlists.songs(playlistId);

  @override
  Future<bool> addSong({required String playlistId, required Song song}) async {
    var added = false;
    try {
      await database.transaction((transaction) async {
        final playlists = PlaylistDao(transaction);
        final playlist = await playlists.findById(playlistId);
        if (playlist == null) throw _notFound;
        if (await playlists.hasSong(playlistId: playlistId, songId: song.id)) {
          return;
        }
        await SongDao.upsertIn(transaction, song);
        final position = await playlists.nextPosition(playlistId);
        await playlists.addSong(
          playlistId: playlistId,
          songId: song.id,
          position: position,
        );
        added = true;
      });
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
    return added;
  }

  @override
  Future<void> removeSong({
    required String playlistId,
    required String songId,
  }) => _playlists.removeSong(playlistId: playlistId, songId: songId);

  @override
  Future<void> setFavorite({required Song song, required bool favorite}) async {
    try {
      await database.transaction((transaction) async {
        final playlists = PlaylistDao(transaction);
        await playlists.ensureFavorites();
        if (!favorite) {
          await playlists.removeSong(
            playlistId: favoritesPlaylistId,
            songId: song.id,
          );
          return;
        }
        if (await playlists.hasSong(
          playlistId: favoritesPlaylistId,
          songId: song.id,
        )) {
          return;
        }
        await SongDao.upsertIn(transaction, song);
        final position = await playlists.nextPosition(favoritesPlaylistId);
        await playlists.addSong(
          playlistId: favoritesPlaylistId,
          songId: song.id,
          position: position,
        );
      });
    } on DatabaseException catch (error) {
      throw _translate(error);
    }
  }

  RepositoryException _translate(DatabaseException error) {
    if (error.isUniqueConstraintError()) {
      return _duplicate;
    }
    return RepositoryException(
      RepositoryErrorCode.storage,
      'No pudimos guardar la lista. Inténtalo de nuevo.',
      cause: error,
    );
  }

  /// The database only enforces unique names for the lists owned by the
  /// player, so the check below covers every list shown in the Listas tab.
  static const _duplicate = RepositoryException(
    RepositoryErrorCode.duplicateName,
    'Ya existe una lista con ese nombre. Elige otro.',
  );

  static const _notFound = RepositoryException(
    RepositoryErrorCode.notFound,
    'Esa lista ya no existe.',
  );

  static const _favoritesProtected = RepositoryException(
    RepositoryErrorCode.invalidData,
    'La lista «Música que me gusta» es automática y no se puede modificar.',
  );

  static void _rejectFavorites(String id) {
    if (isFavoritesPlaylist(id)) throw _favoritesProtected;
  }

  static String _validName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.toLowerCase() == favoritesPlaylistName.toLowerCase()) {
      throw const RepositoryException(
        RepositoryErrorCode.invalidData,
        'Ese nombre está reservado para tus favoritos.',
      );
    }
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
