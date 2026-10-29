import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/navigation_provider.dart';
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

    Future<bool> remove(DownloadEntry entry) async {
      await act(() async {
        final session = await ref.read(downloadSessionProvider.future);
        final duration = ref.read(downloadUndoDurationProvider);
        await session!.repository.requestRemoval(
          entry.record.songId,
          undoUntil: DateTime.now().add(duration),
        );
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        // The latest removal gets the SnackBar; earlier ones retain their
        // per-record Undo button and their own persisted deadline.
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            duration: duration,
            content: const Text('Descarga eliminada.'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => act(
                () => session.repository.undoRemoval(entry.record.songId),
              ),
            ),
          ),
        );
      });
      // The repository stream removes the row after the database write.
      // Never leave a dismissed widget waiting for an asynchronous refresh.
      // On failure the unchanged row slides back into place.
      return false;
    }

    // The Future owns initial loading/errors; the unfiltered stream keeps its
    // snapshot current after download, removal and Undo mutations.
    ref.listen(downloadEntriesProvider, (previous, next) {
      if (previous?.hasValue == true && next.hasValue && !next.isLoading) {
        ref.invalidate(downloadEntriesFutureProvider);
      }
    });
    final filter = ref.watch(downloadFilterProvider);
    final entries = ref.watch(downloadEntriesFutureProvider);
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
                      const Text('No pudimos cargar tus descargas'),
                      FilledButton(
                        onPressed: () {
                          if (ref.read(downloadSessionProvider).hasError) {
                            ref.invalidate(downloadSessionProvider);
                          }
                          ref.invalidate(downloadEntriesFutureProvider);
                          if (ref.read(downloadEntriesProvider).hasError) {
                            ref.invalidate(downloadEntriesProvider);
                          }
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
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                filter.completedOnly
                                    ? 'No hay descargas completadas.'
                                    : 'Aún no tienes canciones descargadas.\nLas canciones que descargues aparecerán en esta lista.',
                                textAlign: TextAlign.center,
                              ),
                              FilledButton(
                                onPressed: () => ref
                                    .read(activeTabProvider.notifier)
                                    .select(AppTab.search),
                                child: const Text('Explorar música'),
                              ),
                            ],
                          ),
                        ),
                      for (final entry in visible)
                        Dismissible(
                          key: ValueKey(entry.record.songId),
                          direction:
                              [
                                DownloadState.completed,
                                DownloadState.failed,
                              ].contains(entry.record.state)
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          confirmDismiss: (_) => remove(entry),
                          background: Container(
                            color: Theme.of(context).colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.all(16),
                            child: const Icon(Icons.delete_outline_rounded),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                const DownloadCover(index: 0),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.song?.title ??
                                            entry.record.songId,
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
                                    onPressed: () => remove(entry),
                                  ),
                              ],
                            ),
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
