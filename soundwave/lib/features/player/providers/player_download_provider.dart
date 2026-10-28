import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/download_record.dart';
import '../../../core/providers/data_mode_provider.dart';
import '../../downloads/download_providers.dart';
import '../../downloads/download_status.dart';
import '../../downloads/download_store.dart';
import 'player_queue_provider.dart';

/// Resuelve el ID actual sin inventar metadatos ni fuentes de audio.
final playerDownloadProvider = Provider<Future<String> Function(String)>((ref) {
  return (songId) async {
    if (ref.read(dataModeProvider) == DataMode.demo) {
      final queue = await ref.read(fullPlayerQueueProvider.future);
      final matches = queue.where((entry) => entry.song.id == songId);
      if (matches.isEmpty) {
        return 'La canción ya no está disponible en la cola.';
      }
      final song = matches.first.song;
      final added = ref
          .read(downloadStoreProvider.notifier)
          .add(
            DownloadStatus(
              id: song.id,
              title: song.title,
              artist: song.artist,
              durationSeconds: song.durationSeconds,
              // El modo demo no guarda audio: no se atribuye un tamaño ficticio.
              sizeMb: 0,
              coverIndex: 0,
            ),
          );
      return added
          ? '«${song.title}» agregada a Descargas (modo demo).'
          : 'Esta canción ya está en Descargas (modo demo).';
    }
    final session = await ref.read(downloadSessionProvider.future);
    if (session == null) {
      return 'No se pudo acceder al servicio de descargas. Intenta de nuevo.';
    }
    final song = await session.findSong(songId);
    if (song == null || song.provider == 'player-demo') {
      return 'Esta canción de prueba no tiene una fuente de audio descargable.';
    }
    final existing = await session.repository.findBySongId(song.id);
    switch (existing?.state) {
      case DownloadState.completed:
        return 'Esta canción ya está descargada.';
      case DownloadState.queued:
      case DownloadState.downloading:
        return 'La descarga de esta canción ya está en curso.';
      case DownloadState.pendingDeletion:
        return 'Restaura la canción desde Descargas antes de descargarla de nuevo.';
      case DownloadState.failed:
        await session.repository.retry(song.id);
      case null:
        await session.repository.enqueue(song);
    }
    final result = await session.repository.findBySongId(song.id);
    if (result?.state == DownloadState.completed) {
      return 'Canción descargada. Ya está disponible en Descargas.';
    }
    if (result?.state == DownloadState.failed) {
      return 'No se pudo descargar la canción. Revisa la conexión y la fuente de audio.';
    }
    return 'Descarga solicitada. Puedes ver su estado en Descargas.';
  };
});
