import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download_cover.dart';
import 'download_status.dart';
import 'download_store.dart';
import 'download_theme.dart';
import '../../core/providers/data_mode_provider.dart';
import 'repository_download_view.dart';

class DownloadScreen extends ConsumerWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dataModeProvider) == DataMode.localSqlite) {
      return const RepositoryDownloadView();
    }
    final songs = ref.watch(downloadStoreProvider);
    final minutes =
        songs.fold<int>(0, (total, song) => total + song.durationSeconds) ~/ 60;
    final size = songs.fold<double>(0, (total, song) => total + song.sizeMb);

    return Theme(
      data: DownloadTheme.data,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 360 ? 16 : 24,
                    24,
                    constraints.maxWidth < 360 ? 16 : 24,
                    32,
                  ),
                  children: [
                    const Text(
                      'TU BIBLIOTECA',
                      style: TextStyle(
                        color: DownloadTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mis descargas',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text('Tu música, siempre contigo'),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: DownloadTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.offline_pin_rounded,
                            color: DownloadTheme.accent,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tu colección sin conexión',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${songs.length} ${songs.length == 1 ? 'canción' : 'canciones'} · $minutes min · ${size.toStringAsFixed(1).replaceAll('.', ',')} MB',
                            style: const TextStyle(
                              color: DownloadTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Modo de demostración · Datos simulados, sin archivos de audio.',
                            style: TextStyle(
                              fontSize: 12,
                              color: DownloadTheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (songs.isEmpty)
                      _EmptyDownloads(
                        onReset: () => ref
                            .read(downloadStoreProvider.notifier)
                            .resetDemo(),
                      )
                    else ...[
                      Text(
                        'En tu colección',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      for (final song in songs)
                        _DownloadRow(
                          key: ValueKey(song.id),
                          song: song,
                          onRemove: () {
                            final store = ref.read(
                              downloadStoreProvider.notifier,
                            );
                            store.remove(song.id);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Se eliminó «${song.title}» de la lista.',
                                  ),
                                  action: SnackBarAction(
                                    label: 'Deshacer',
                                    onPressed: () => store.restore(song),
                                  ),
                                ),
                              );
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({super.key, required this.song, required this.onRemove});
  final DownloadStatus song;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          DownloadCover(index: song.coverIndex),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: DownloadTheme.accent,
                          size: 14,
                        ),
                      ),
                      TextSpan(text: ' Descargada · ${song.durationLabel}'),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Eliminar ${song.title}',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: DownloadTheme.secondary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: DownloadTheme.surface,
            child: Icon(
              Icons.library_music_outlined,
              size: 36,
              color: DownloadTheme.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tu próxima colección empieza aquí',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Aún no tienes canciones descargadas.\nRecupera los ejemplos para seguir explorando.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Restaurar ejemplos'),
          ),
        ],
      ),
    );
  }
}
