import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'blocked_song_dao.dart';
import 'download_dao.dart';
import 'playlist_dao.dart';
import 'song_dao.dart';
import 'soundwave_database.dart';

final songDaoProvider = FutureProvider<SongDao>(
  (ref) async => SongDao(await ref.watch(soundwaveDatabaseProvider.future)),
);

final downloadDaoProvider = FutureProvider<DownloadDao>(
  (ref) async => DownloadDao(await ref.watch(soundwaveDatabaseProvider.future)),
);

final playlistDaoProvider = FutureProvider<PlaylistDao>(
  (ref) async => PlaylistDao(await ref.watch(soundwaveDatabaseProvider.future)),
);

final blockedSongDaoProvider = FutureProvider<BlockedSongDao>(
  (ref) async =>
      BlockedSongDao(await ref.watch(soundwaveDatabaseProvider.future)),
);
