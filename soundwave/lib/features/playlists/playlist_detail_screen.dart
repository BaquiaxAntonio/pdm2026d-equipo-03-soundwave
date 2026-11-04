import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/navigation_provider.dart';
import '../../app/playlist_refresh.dart';
import '../../app/song_selection.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import '../search/cover_placeholder_local.dart';
import 'playlist_providers.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(playlistSongsProvider(playlist.id));
    final favorites = isFavoritesPlaylist(playlist.id);
    return Scaffold(
      appBar: AppBar(title: Text(playlist.name)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: songs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No pudimos cargar las canciones.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          ref.invalidate(playlistSongsProvider(playlist.id)),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyDetail(
                    favorites: favorites,
                    onExplore: () {
                      Navigator.of(context).pop();
                      ref
                          .read(activeTabProvider.notifier)
                          .select(AppTab.search);
                    },
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.surfaceElevated,
                          child: Icon(
                            favorites
                                ? Icons.favorite_rounded
                                : Icons.queue_music_rounded,
                            color: AppColors.accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${items.length} ${items.length == 1 ? 'canción' : 'canciones'}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                favorites
                                    ? 'Lista automática'
                                    : 'Lista personalizada',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toca una canción para reproducirla.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    for (final song in items)
                      _DetailSongTile(
                        key: ValueKey('playlist-song-${song.id}'),
                        song: song,
                        onPlay: () => _play(context, ref, song),
                        onRemove: () => _remove(context, ref, song),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _play(BuildContext context, WidgetRef ref, Song song) {
    openSongInPlayer(ref, song.id);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Song song) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('¿Borrar «${song.title}»?'),
        content: const Text('La canción se quitará de esta lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      await repository.removeSong(playlistId: playlist.id, songId: song.id);
      invalidatePlaylistViews(ref);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('«${song.title}» borrada de la lista.'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => _undoRemove(ref, song),
            ),
          ),
        );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo borrar la canción.')),
      );
    }
  }

  Future<void> _undoRemove(WidgetRef ref, Song song) async {
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      await repository.addSong(playlistId: playlist.id, song: song);
      invalidatePlaylistViews(ref);
    } catch (_) {
      // The snackbar is already gone; the next read shows the real state.
    }
  }
}

class _DetailSongTile extends StatelessWidget {
  const _DetailSongTile({
    super.key,
    required this.song,
    required this.onPlay,
    required this.onRemove,
  });

  final Song song;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onPlay,
      leading: CoverPlaceholderLocal(songId: song.id),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${song.artist} · ${song.formattedDuration}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Quitar ${song.title} de la lista',
        onPressed: onRemove,
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.favorites, required this.onExplore});

  final bool favorites;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surfaceElevated,
              child: Icon(
                favorites
                    ? Icons.favorite_border_rounded
                    : Icons.queue_music_rounded,
                size: 36,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              favorites
                  ? 'Aún no tienes canciones favoritas'
                  : 'Esta lista aún no tiene canciones',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              favorites
                  ? 'Marca el corazón de una canción desde su menú y aparecerá aquí.'
                  : 'Añádelas desde el menú de cualquier canción en Buscar o Descargas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Explorar música'),
            ),
          ],
        ),
      ),
    );
  }
}
