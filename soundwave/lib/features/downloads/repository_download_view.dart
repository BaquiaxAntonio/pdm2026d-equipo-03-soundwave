import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/download_record.dart';
import 'download_cover.dart';
import 'download_providers.dart';
import 'download_theme.dart';

class RepositoryDownloadView extends ConsumerWidget {
  const RepositoryDownloadView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> act(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo completar la operación. Inténtalo de nuevo.',
              ),
            ),
          );
        }
      }
    }

    final filter = ref.watch(downloadFilterProvider);
    final entries = ref.watch(downloadEntriesProvider);
    return Theme(
      data: DownloadTheme.data,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: entries.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudieron cargar tus descargas.'),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(downloadSessionProvider);
                          ref.invalidate(downloadEntriesProvider);
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (all) {
                  final visible = all
                      .where(
                        (e) => e.record.state != DownloadState.pendingDeletion,
                      )
                      .toList();
                  final pending = all.where(
                    (e) => e.record.state == DownloadState.pendingDeletion,
                  );
                  final completed = visible
                      .where((e) => e.record.state == DownloadState.completed)
                      .length;
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const Text(
                        'TU BIBLIOTECA',
                        style: TextStyle(
                          color: DownloadTheme.accent,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mis descargas',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Todas'),
                            selected: !filter.completedOnly,
                            onSelected: (_) => ref
                                .read(downloadFilterProvider.notifier)
                                .showAll(),
                          ),
                          ChoiceChip(
                            label: const Text('Completadas'),
                            selected: filter.completedOnly,
                            onSelected: (_) => ref
                                .read(downloadFilterProvider.notifier)
                                .showCompleted(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Tu colección sin conexión',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              '$completed ${completed == 1 ? 'canción disponible' : 'canciones disponibles'}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (visible.isEmpty)
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            filter.completedOnly
                                ? 'No hay descargas completadas.'
                                : 'Tu próxima colección empieza aquí.\nLas canciones que descargues aparecerán en esta lista.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      for (final entry in visible)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              const DownloadCover(index: 0),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.song?.title ?? entry.record.songId,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (entry.song != null)
                                      Text(entry.song!.artist),
                                    if (entry.record.state ==
                                        DownloadState.completed)
                                      const Text(
                                        'Descargada',
                                        style: TextStyle(
                                          color: DownloadTheme.accent,
                                        ),
                                      ),
                                    if (entry.record.state ==
                                        DownloadState.queued)
                                      const Text('En cola'),
                                    if (entry.record.state ==
                                        DownloadState.downloading) ...[
                                      LinearProgressIndicator(
                                        value: entry.record.progress,
                                      ),
                                      Text(
                                        entry.record.progress == null
                                            ? 'Descargando…'
                                            : '${(entry.record.progress! * 100).round()} %',
                                      ),
                                    ],
                                    if (entry.record.state ==
                                        DownloadState.failed) ...[
                                      const Text(
                                        'Descarga no disponible. Puedes reintentar.',
                                      ),
                                      TextButton(
                                        onPressed: () => act(() async {
                                          final session = await ref.read(
                                            downloadSessionProvider.future,
                                          );
                                          await session!.repository.retry(
                                            entry.record.songId,
                                          );
                                        }),
                                        child: const Text('Reintentar'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if ([
                                DownloadState.completed,
                                DownloadState.failed,
                              ].contains(entry.record.state))
                                IconButton(
                                  tooltip:
                                      'Eliminar ${entry.song?.title ?? entry.record.songId}',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: () => act(() async {
                                    final session = await ref.read(
                                      downloadSessionProvider.future,
                                    );
                                    final duration = ref.read(
                                      downloadUndoDurationProvider,
                                    );
                                    await session!.repository.requestRemoval(
                                      entry.record.songId,
                                      undoUntil: DateTime.now().add(duration),
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          duration: duration,
                                          content: const Text(
                                            'Se ocultó la canción. Puedes deshacer la eliminación.',
                                          ),
                                          action: SnackBarAction(
                                            label: 'Deshacer',
                                            onPressed: () => act(
                                              () => session.repository
                                                  .undoRemoval(
                                                    entry.record.songId,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }),
                                ),
                            ],
                          ),
                        ),
                      for (final entry in pending)
                        if (entry.record.deletionDeadline?.isAfter(
                              DateTime.now(),
                            ) ??
                            false)
                          TextButton(
                            onPressed: () => act(() async {
                              final session = await ref.read(
                                downloadSessionProvider.future,
                              );
                              await session!.repository.undoRemoval(
                                entry.record.songId,
                              );
                            }),
                            child: Text(
                              'Deshacer eliminación de ${entry.song?.title ?? entry.record.songId}',
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
