import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/playlist_refresh.dart';
import '../../core/errors/repository_exception.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import 'playlist_providers.dart';

Future<void> showAddToPlaylistSheet(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _AddToPlaylistSheet(song: song),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(playlistEntriesProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Añadir a lista',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: entries.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No pudimos cargar tus listas.'),
              ),
              data: (all) {
                final favorites = all
                    .where((entry) => entry.playlist.id == favoritesPlaylistId)
                    .firstOrNull;
                final active = all
                    .where(
                      (entry) =>
                          !entry.playlist.archived &&
                          entry.playlist.id != favoritesPlaylistId,
                    )
                    .toList(growable: false);
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.accent,
                      ),
                      title: const Text(favoritesPlaylistName),
                      subtitle: Text(
                        favorites == null
                            ? 'Lista automática'
                            : 'Lista automática · ${favorites.songLabel}',
                      ),
                      onTap: () => _favorite(context, ref),
                    ),
                    for (final entry in active)
                      ListTile(
                        leading: const Icon(
                          Icons.queue_music_rounded,
                          color: AppColors.accent,
                        ),
                        title: Text(entry.playlist.name),
                        subtitle: Text(entry.songLabel),
                        onTap: () => _add(context, ref, entry),
                      ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(
                        Icons.add_rounded,
                        color: AppColors.accent,
                      ),
                      title: const Text('Nueva lista'),
                      onTap: () => _create(context, ref),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _favorite(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      await repository.setFavorite(song: song, favorite: true);
      invalidatePlaylistViews(ref);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Guardada en «Música que me gusta».')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar en favoritos.')),
      );
    }
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    PlaylistEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      final added = await repository.addSong(
        playlistId: entry.playlist.id,
        song: song,
      );
      invalidatePlaylistViews(ref);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added
                ? '«${song.title}» añadida a «${entry.playlist.name}».'
                : '«${song.title}» ya estaba en «${entry.playlist.name}».',
          ),
        ),
      );
    } on RepositoryException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo añadir la canción.')),
      );
    }
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    var name = '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Nueva lista'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre de la lista'),
          onChanged: (value) => name = value,
          onSubmitted: (value) => Navigator.of(dialog).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(name),
            child: const Text('Crear lista'),
          ),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      final playlist = await repository.create(result);
      await repository.addSong(playlistId: playlist.id, song: song);
      invalidatePlaylistViews(ref);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('«${song.title}» añadida a «${playlist.name}».'),
        ),
      );
    } on RepositoryException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo crear la lista.')),
      );
    }
  }
}
