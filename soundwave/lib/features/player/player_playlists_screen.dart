import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/player_playlist_repository.dart';
import 'models/player_playlist.dart';
import 'player_song_local.dart';
import 'providers/player_playlists_provider.dart';
import 'providers/player_queue_provider.dart';
import 'widgets/player_playlist_form.dart';

class PlayerPlaylistsScreen extends ConsumerWidget {
  const PlayerPlaylistsScreen({super.key});

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    PlayerPlaylist? initial,
  ]) async {
    // Una copia estable: la cola puede cambiar mientras el formulario está abierto.
    final queueSongs =
        ref
            .read(fullPlayerQueueProvider)
            .asData
            ?.value
            .map((entry) => entry.song)
            .toList() ??
        <PlayerSongLocal>[];
    List<PlayerSongLocal> savedSongs;
    try {
      if (initial == null) {
        savedSongs = [];
      } else {
        final repository = await ref.read(
          playerPlaylistRepositoryProvider.future,
        );
        savedSongs = await repository.songs(initial.id);
      }
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          'No se pudieron cargar las canciones de la lista. Intenta de nuevo.',
        );
      }
      return;
    }
    if (!context.mounted) return;
    final availableSongs = {
      for (final song in savedSongs) song.id: song,
      for (final song in queueSongs) song.id: song,
    }.values.toList();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PlayerPlaylistForm(
        initial: initial,
        availableSongs: availableSongs,
        initialSongIds: savedSongs.map((song) => song.id).toList(),
        onSave: (name, songIds) async {
          try {
            final repository = await ref.read(
              playerPlaylistRepositoryProvider.future,
            );
            await repository.save(
              id: initial?.id,
              name: name,
              songIds: songIds,
            );
            ref.invalidate(playerPlaylistsProvider);
            return null;
          } on PlayerPlaylistException catch (error) {
            return error.message;
          } catch (_) {
            return 'No se pudo guardar la lista. Intenta de nuevo.';
          }
        },
      ),
    );
  }

  void _message(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    PlayerPlaylist entry,
  ) async {
    try {
      final repository = await ref.read(
        playerPlaylistRepositoryProvider.future,
      );
      await repository.setArchived(entry.id, !entry.archived);
      ref.invalidate(playerPlaylistsProvider);
      if (context.mounted) {
        _message(
          context,
          entry.archived ? 'Lista restaurada.' : 'Lista archivada.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _message(context, 'No se pudo actualizar la lista. Intenta de nuevo.');
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PlayerPlaylist entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Eliminar «${entry.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final repository = await ref.read(
        playerPlaylistRepositoryProvider.future,
      );
      await repository.delete(entry.id);
      ref.invalidate(playerPlaylistsProvider);
      if (context.mounted) _message(context, 'Lista eliminada.');
    } on PlayerPlaylistException catch (error) {
      if (!context.mounted) return;
      if (!error.inUse) {
        _message(context, error.message);
        return;
      }
      final archive = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista en uso'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cerrar'),
            ),
            if (!entry.archived)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Archivar'),
              ),
          ],
        ),
      );
      if (archive == true && context.mounted) {
        await _archive(context, ref, entry);
      }
    } catch (_) {
      if (context.mounted) {
        _message(context, 'No se pudo eliminar la lista. Intenta de nuevo.');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fullPlayerQueueProvider);
    final playlists = ref.watch(playerPlaylistsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Listas de reproducción')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
      ),
      body: playlists.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No se pudieron cargar las listas.'),
              TextButton(
                onPressed: () {
                  ref.invalidate(playerPlaylistRepositoryProvider);
                  ref.invalidate(playerPlaylistsProvider);
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (entries) => entries.isEmpty
            ? const Center(
                child: Text('No tienes listas. Crea tu primera lista.'),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final archived in [false, true]) ...[
                    if (entries.any((entry) => entry.archived == archived))
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          archived ? 'Archivadas' : 'Mis listas',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    for (final entry in entries.where(
                      (entry) => entry.archived == archived,
                    ))
                      ListTile(
                        key: ValueKey(entry.id),
                        title: Text(entry.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.songCount} ${entry.songCount == 1 ? 'canción' : 'canciones'}${entry.archived ? ' · archivada' : ''}',
                            ),
                            TextButton(
                              onPressed: () => _edit(context, ref, entry),
                              child: const Text('Editar lista'),
                            ),
                          ],
                        ),
                        onTap: () => _edit(context, ref, entry),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opciones de ${entry.name}',
                          onSelected: (action) {
                            if (action == 'delete') {
                              _delete(context, ref, entry);
                            } else {
                              _archive(context, ref, entry);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(
                                entry.archived ? 'Restaurar' : 'Archivar',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
