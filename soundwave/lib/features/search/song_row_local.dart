import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song.dart';
import 'cover_placeholder_local.dart';
import 'search_controller.dart';
import 'search_theme_local.dart';

// Fila limpia sin tarjeta: portada + centro flexible + duración.
// Motivo: evita tarjeta-dentro-de-tarjeta y desbordes con títulos largos
// o texto ampliado (Expanded + ellipsis). Sin onTap ni efecto ripple
// porque la fila no reproduce ni navega todavía.
class SongRowLocal extends ConsumerWidget {
  final Song song;

  const SongRowLocal({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(searchDownloadStateProvider(song.id));
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: SearchThemeLocal.space16,
        vertical: SearchThemeLocal.space8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoverPlaceholderLocal(songId: song.id),
          const SizedBox(width: SearchThemeLocal.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  style: SearchThemeLocal.songTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SearchThemeLocal.space4),
                Text(
                  song.artist,
                  style: SearchThemeLocal.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (download.message case final message?) ...[
                  const SizedBox(height: SearchThemeLocal.space4),
                  Text(
                    message,
                    style: SearchThemeLocal.auxiliary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SearchThemeLocal.space12),
          Text(
            song.formattedDuration,
            style: SearchThemeLocal.auxiliary,
            semanticsLabel:
                'Duración ${song.formattedDuration.replaceAll(':', ' minutos ')} segundos',
          ),
          const SizedBox(width: SearchThemeLocal.space4),
          _DownloadAction(song: song, state: download),
        ],
      ),
    );
  }
}

class _DownloadAction extends ConsumerWidget {
  const _DownloadAction({required this.song, required this.state});

  final Song song;
  final SearchDownloadViewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.status == SearchDownloadStatus.preparing ||
        state.status == SearchDownloadStatus.requesting) {
      return Semantics(
        label: state.message,
        child: const SizedBox.square(
          dimension: 48,
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SearchThemeLocal.accent,
              ),
            ),
          ),
        ),
      );
    }

    return IconButton(
      tooltip: _tooltip,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      color: SearchThemeLocal.accent,
      disabledColor: SearchThemeLocal.textSecondary,
      onPressed: state.canActivate
          ? () => _requestDownload(context, ref)
          : null,
      icon: Icon(_icon),
    );
  }

  Future<void> _requestDownload(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(searchDownloadControllerProvider.notifier)
        .request(song);
    final message = result.message;
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String get _tooltip => switch (state.status) {
    SearchDownloadStatus.available => 'Descargar ${song.title}',
    SearchDownloadStatus.failed => 'Reintentar descarga de ${song.title}',
    SearchDownloadStatus.queued => 'Descarga en cola de ${song.title}',
    SearchDownloadStatus.downloading => 'Descargando ${song.title}',
    SearchDownloadStatus.completed => '${song.title} descargada',
    SearchDownloadStatus.pendingDeletion =>
      '${song.title} pendiente de eliminación',
    SearchDownloadStatus.unavailable =>
      'Información de descarga de ${song.title}',
    SearchDownloadStatus.preparing || SearchDownloadStatus.requesting =>
      state.message ?? 'Preparando descarga de ${song.title}',
  };

  IconData get _icon => switch (state.status) {
    SearchDownloadStatus.available => Icons.download_outlined,
    SearchDownloadStatus.failed => Icons.refresh,
    SearchDownloadStatus.queued => Icons.schedule,
    SearchDownloadStatus.downloading => Icons.downloading,
    SearchDownloadStatus.completed => Icons.download_done,
    SearchDownloadStatus.pendingDeletion => Icons.delete_outline,
    SearchDownloadStatus.unavailable => Icons.cloud_off_outlined,
    SearchDownloadStatus.preparing ||
    SearchDownloadStatus.requesting => Icons.downloading,
  };
}
