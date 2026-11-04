import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/playlist_refresh.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import 'add_to_playlist_sheet.dart';
import 'playlist_providers.dart';

enum _SongAction { addToPlaylist, toggleFavorite }

class SongPlaylistMenu extends ConsumerWidget {
  const SongPlaylistMenu({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorite =
        ref.watch(favoriteSongIdsProvider).asData?.value.contains(song.id) ??
        false;
    return IconButton(
      tooltip: 'Opciones de ${song.title}',
      icon: const Icon(Icons.more_vert_rounded),
      onPressed: () => _open(context, ref, favorite),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, bool favorite) async {
    final action = await showModalBottomSheet<_SongAction>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _SongActions(song: song, favorite: favorite),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _SongAction.addToPlaylist:
        await showAddToPlaylistSheet(context, song);
      case _SongAction.toggleFavorite:
        await _toggleFavorite(context, ref, favorite);
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    bool favorite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      await repository.setFavorite(song: song, favorite: !favorite);
      invalidatePlaylistViews(ref);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            favorite
                ? 'Quitada de «$favoritesPlaylistName».'
                : 'Guardada en «$favoritesPlaylistName».',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar tus favoritos.')),
      );
    }
  }
}

class _SongActions extends StatelessWidget {
  const _SongActions({required this.song, required this.favorite});

  final Song song;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          ListTile(
            leading: const Icon(
              Icons.playlist_add_rounded,
              color: AppColors.accent,
            ),
            title: const Text('Añadir a lista de reproducción'),
            onTap: () => Navigator.of(context).pop(_SongAction.addToPlaylist),
          ),
          ListTile(
            leading: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: AppColors.accent,
            ),
            title: Text(
              favorite ? 'Quitar de «$favoritesPlaylistName»' : 'Me gusta',
            ),
            onTap: () => Navigator.of(context).pop(_SongAction.toggleFavorite),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
