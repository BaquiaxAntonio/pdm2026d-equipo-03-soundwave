import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/database/soundwave_database.dart';
import '../../../core/database/dao_providers.dart';
import '../../../core/errors/repository_exception.dart';
import '../../../core/models/song.dart';
import '../download_providers.dart';
import 'local_audio_file_store.dart';
import 'sqlite_download_repository.dart';
import '../../search/data/commons_api_client.dart';
import '../../search/data/commons_catalog_repository.dart';
import 'http_audio_downloader.dart';

OpenDownload createOpenDownload(Ref ref) {
  final resolver = CommonsAudioResolver(ref.watch(commonsApiClientProvider));
  return HttpAudioDownloader((song) async {
    final audio = await resolver.resolve(song);
    await (await ref.read(songDaoProvider.future)).upsert(audio.song);
    return PermittedAudio(
      audio.uri,
      downloadAllowed: audio.downloadAllowed,
      sha1: audio.sha1,
      size: audio.fileSizeBytes,
    );
  }).open;
}

Future<DownloadInput> unavailable(Song song) async =>
    throw const RepositoryException(
      RepositoryErrorCode.network,
      'La fuente de audio aún no está configurada.',
    );

Future<DownloadSession> createSession(Ref ref) async {
  final open = ref.watch(openDownloadProvider);
  final canDelete = ref.watch(canDeleteAudioProvider);
  final database = await ref.watch(soundwaveDatabaseProvider.future);
  final directory = await getApplicationSupportDirectory();
  final files = LocalAudioFileStore(
    Directory(p.join(directory.path, 'downloads')),
  );
  final repository = SqliteDownloadRepository(
    database: database,
    files: files,
    openDownload: open,
    canDelete: canDelete,
  );
  Timer? timer;
  var running = false;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    unawaited(repository.dispose());
  });
  await repository.recoverInterrupted();
  if (!disposed) {
    timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (running || disposed) return;
      running = true;
      try {
        await repository.finalizeExpiredRemovals();
      } catch (_) {
        /* Keep persistent pending records for the next safe retry. */
      } finally {
        running = false;
      }
    });
  }
  return DownloadSession(
    repository,
    repository.songs.findById,
    localAudioUri: (path) async {
      if (!await files.exists(path)) {
        throw StateError(
          'El archivo descargado ya no existe. Vuelve a descargarlo.',
        );
      }
      return File(files.resolve(path)).uri;
    },
  );
}
