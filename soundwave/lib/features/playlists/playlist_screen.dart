import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/playlist_refresh.dart';
import '../../core/contracts/playlist_repository.dart';
import '../../core/errors/repository_exception.dart';
import '../../core/models/playlist.dart';
import '../../core/providers/data_mode_provider.dart';
import 'add_songs_sheet.dart';
import 'playlist_detail_screen.dart';
import 'playlist_form.dart';
import 'playlist_providers.dart';

class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(dataModeProvider) == DataMode.demo) {
      return const _DemoNotice();
    }
    final entries = ref.watch(playlistEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Listas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _LoadError(
                onRetry: () => ref.invalidate(playlistEntriesProvider),
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
                final archived = all
                    .where(
                      (entry) =>
                          entry.playlist.archived &&
                          entry.playlist.id != favoritesPlaylistId,
                    )
                    .toList(growable: false);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                  children: [
                    const Text(
                      'TU BIBLIOTECA',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tus listas',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    _FavoritesTile(
                      songLabel: favorites?.songLabel ?? '0 canciones',
                      onOpen: () => _openDetail(
                        context,
                        favorites?.playlist ?? favoritesPlaylist,
                      ),
                    ),
                    if (active.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No tienes listas activas.'),
                      )
                    else
                      for (final entry in active)
                        _PlaylistTile(
                          key: ValueKey('playlist-${entry.playlist.id}'),
                          entry: entry,
                          onOpen: () => _openDetail(context, entry.playlist),
                          onAdd: () =>
                              showAddSongsSheet(context, entry.playlist),
                          onEdit: () =>
                              _openForm(context, ref, initial: entry.playlist),
                          onArchive: () => _setArchived(context, ref, entry),
                          onDelete: () => _delete(context, ref, entry),
                        ),
                    if (archived.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Archivadas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final entry in archived)
                        _PlaylistTile(
                          key: ValueKey('playlist-${entry.playlist.id}'),
                          entry: entry,
                          onOpen: () => _openDetail(context, entry.playlist),
                          onAdd: () =>
                              showAddSongsSheet(context, entry.playlist),
                          onEdit: () =>
                              _openForm(context, ref, initial: entry.playlist),
                          onArchive: () => _setArchived(
                            context,
                            ref,
                            entry,
                            archived: false,
                          ),
                          onDelete: () => _delete(context, ref, entry),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, Playlist playlist) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaylistDetailScreen(playlist: playlist),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Playlist? initial,
  }) async {
    PlaylistRepository? repository;
    try {
      repository = await ref.read(playlistRepositoryProvider.future);
    } catch (_) {
      if (context.mounted) _showMessage(context, _genericError);
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlaylistForm(
        initial: initial,
        onSave: (name) async {
          if (initial == null) {
            await repository!.create(name);
          } else {
            await repository!.rename(id: initial.id, name: name);
          }
          // The list is refreshed by invalidating the provider, never by
          // inserting the saved value by hand.
          invalidatePlaylistViews(ref);
        },
      ),
    );
  }

  Future<void> _setArchived(
    BuildContext context,
    WidgetRef ref,
    PlaylistEntry entry, {
    bool archived = true,
  }) async {
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      await repository.setArchived(id: entry.playlist.id, archived: archived);
      invalidatePlaylistViews(ref);
      if (context.mounted) {
        _showMessage(
          context,
          archived ? 'Lista archivada.' : 'Lista restaurada.',
        );
      }
    } on RepositoryException catch (error) {
      if (context.mounted) _showMessage(context, error.message);
    } catch (_) {
      if (context.mounted) _showMessage(context, _genericError);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PlaylistEntry entry,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('¿Eliminar «${entry.playlist.name}»?'),
        content: const Text('La lista dejará de aparecer en tu biblioteca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      await repository.delete(entry.playlist.id);
      invalidatePlaylistViews(ref);
      messenger.showSnackBar(const SnackBar(content: Text('Lista eliminada.')));
    } on RepositoryException catch (error) {
      if (error.code != RepositoryErrorCode.inUse) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      if (!context.mounted) return;
      final archive = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialog, true),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archivar'),
            ),
          ],
        ),
      );
      if (archive == true && context.mounted) {
        await _setArchived(context, ref, entry);
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos eliminar la lista.')),
      );
    }
  }

  static const _genericError =
      'No pudimos completar la operación. Inténtalo de nuevo.';

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _FavoritesTile extends StatelessWidget {
  const _FavoritesTile({required this.songLabel, required this.onOpen});

  final String songLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      leading: const CircleAvatar(
        backgroundColor: AppColors.surfaceElevated,
        child: Icon(Icons.favorite_rounded, color: AppColors.accent),
      ),
      title: const Text(favoritesPlaylistName),
      subtitle: Text('$songLabel · Lista automática'),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

enum _PlaylistAction { add, edit, archive, delete }

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onAdd,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final PlaylistEntry entry;
  final VoidCallback onOpen;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final archived = entry.playlist.archived;
    final name = entry.playlist.name;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onOpen,
      leading: CircleAvatar(
        backgroundColor: AppColors.surfaceElevated,
        child: Icon(
          archived ? Icons.archive_outlined : Icons.queue_music_rounded,
          color: AppColors.accent,
        ),
      ),
      title: Text(name),
      subtitle: Text(
        archived ? 'Archivada · ${entry.songLabel}' : entry.songLabel,
      ),
      trailing: PopupMenuButton<_PlaylistAction>(
        tooltip: 'Opciones de la lista $name',
        onSelected: (action) {
          switch (action) {
            case _PlaylistAction.add:
              onAdd();
            case _PlaylistAction.edit:
              onEdit();
            case _PlaylistAction.archive:
              onArchive();
            case _PlaylistAction.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: _PlaylistAction.add,
            child: Text('Agregar'),
          ),
          const PopupMenuItem(
            value: _PlaylistAction.edit,
            child: Text('Editar'),
          ),
          PopupMenuItem(
            value: _PlaylistAction.archive,
            child: Text(archived ? 'Desarchivar' : 'Archivar'),
          ),
          const PopupMenuItem(
            value: _PlaylistAction.delete,
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('No pudimos cargar tus listas'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listas')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Las listas se guardan en la base local del teléfono. '
              'Esta demostración no incluye esa base de datos.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
