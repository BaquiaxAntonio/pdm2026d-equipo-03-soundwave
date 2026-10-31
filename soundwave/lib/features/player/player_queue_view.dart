import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/player_queue_repository.dart';
import 'providers/player_queue_provider.dart';

class PlayerQueueView extends ConsumerStatefulWidget {
  const PlayerQueueView({super.key, this.currentSongId, this.playbackOrder});

  final String? currentSongId;
  final List<String>? playbackOrder;

  @override
  ConsumerState<PlayerQueueView> createState() => _PlayerQueueViewState();
}

class _PlayerQueueViewState extends ConsumerState<PlayerQueueView> {
  final _removedIds = <String>{};

  void _refresh() {
    ref.invalidate(playerQueueProvider);
    ref.invalidate(fullPlayerQueueProvider);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _remove(PlayerQueueEntry entry) async {
    try {
      final repository = await ref.read(playerQueueRepositoryProvider.future);
      await repository.remove(entry);
      if (!mounted) return false;
      return true;
    } catch (_) {
      if (mounted) {
        _showError('No se pudo quitar la canción. Intenta de nuevo.');
      }
      return false;
    }
  }

  void _onRemoved(PlayerQueueEntry entry) {
    setState(() => _removedIds.add(entry.song.id));
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${entry.song.title} quitada de la cola'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            try {
              final repository = await ref.read(
                playerQueueRepositoryProvider.future,
              );
              await repository.restore(entry);
              if (!mounted) return;
              setState(() => _removedIds.remove(entry.song.id));
              _refresh();
            } catch (_) {
              if (mounted) _showError('No se pudo restaurar la canción.');
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playerQueueProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Cola de reproducción',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: ref.read(playerQueueFilterProvider).text,
          decoration: const InputDecoration(
            labelText: 'Filtrar por título o artista',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: ref.read(playerQueueFilterProvider.notifier).setText,
        ),
        const SizedBox(height: 12),
        queue.when(
          skipLoadingOnRefresh: false,
          loading: () => const Text('Cargando cola…'),
          error: (_, _) => Column(
            children: [
              const Text('No se pudo cargar la cola.'),
              TextButton(
                onPressed: () {
                  ref.invalidate(playerQueueRepositoryProvider);
                  _refresh();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (entries) {
            final order = widget.playbackOrder;
            final positions = order == null
                ? null
                : {for (var i = 0; i < order.length; i++) order[i]: i};
            final visible = entries
                .where(
                  (e) =>
                      !_removedIds.contains(e.song.id) &&
                      (positions == null || positions.containsKey(e.song.id)),
                )
                .toList();
            if (positions != null) {
              visible.sort(
                (a, b) =>
                    positions[a.song.id]!.compareTo(positions[b.song.id]!),
              );
            }
            if (visible.isEmpty) {
              return Text(
                ref.watch(playerQueueFilterProvider).text.trim().isEmpty
                    ? 'La cola está vacía.'
                    : 'No hay canciones para este filtro.',
              );
            }
            return Column(
              children: [
                for (final entry in visible)
                  Dismissible(
                    key: ValueKey(entry.song.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => _remove(entry),
                    onDismissed: (_) => _onRemoved(entry),
                    background: Container(
                      color: Theme.of(context).colorScheme.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.all(16),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: ListTile(
                      selected: entry.song.id == widget.currentSongId,
                      title: Text(entry.song.title),
                      subtitle: Text(
                        entry.song.id == widget.currentSongId
                            ? 'En reproducción · ${entry.song.artist}'
                            : entry.song.artist,
                      ),
                      trailing: Text(
                        '${entry.song.durationSeconds ~/ 60}:${(entry.song.durationSeconds % 60).toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
