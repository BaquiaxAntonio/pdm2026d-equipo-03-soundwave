import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../app/playlist_refresh.dart';
import '../../core/errors/repository_exception.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
import 'playlist_providers.dart';

/// Fills [playlist] with songs the app already knows. The sheet stays open
/// after each addition so several songs can be added in a single visit; a
/// caption inside the sheet reports each result because a SnackBar would be
/// hidden behind this modal route.
Future<void> showAddSongsSheet(BuildContext context, Playlist playlist) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _AddSongsSheet(playlist: playlist),
  );
}

class _AddSongsSheet extends ConsumerStatefulWidget {
  const _AddSongsSheet({required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<_AddSongsSheet> {
  String _query = '';
  String? _status;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogSongsProvider);
    final current = ref.watch(playlistSongsProvider(widget.playlist.id));
    final existing = current.asData?.value ?? const <Song>[];
    final existingIds = {for (final song in existing) song.id};
    final query = _query.trim().toLowerCase();
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
                Expanded(
                  child: Text(
                    'Agregar a «${widget.playlist.name}»',
                    style: const TextStyle(
                      fontSize: 20,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar por título o artista',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() {
                _query = value;
                _status = null;
              }),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _status!,
                  style: const TextStyle(color: AppColors.accent, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Flexible(
            child: catalog.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (_, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No pudimos cargar tus canciones.'),
              ),
              data: (songs) {
                final filtered = query.isEmpty
                    ? songs
                    : songs
                          .where(
                            (song) =>
                                song.title.toLowerCase().contains(query) ||
                                song.artist.toLowerCase().contains(query),
                          )
                          .toList(growable: false);
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      songs.isEmpty
                          ? 'Aún no tienes canciones guardadas.'
                          : 'Sin resultados para «$_query».',
                    ),
                  );
                }
                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final song in filtered)
                      ListTile(
                        key: ValueKey('add-song-${song.id}'),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: existingIds.contains(song.id)
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.accent,
                                semanticLabel: 'Ya está en la lista',
                              )
                            : IconButton(
                                tooltip: 'Añadir ${song.title}',
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _add(song),
                              ),
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

  Future<void> _add(Song song) async {
    try {
      final repository = await ref.read(playlistRepositoryProvider.future);
      final added = await repository.addSong(
        playlistId: widget.playlist.id,
        song: song,
      );
      invalidatePlaylistViews(ref);
      if (!mounted) return;
      setState(() {
        _status = added
            ? '«${song.title}» añadida a «${widget.playlist.name}».'
            : '«${song.title}» ya estaba en «${widget.playlist.name}».';
      });
    } on RepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _status = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = 'No se pudo añadir la canción.');
    }
  }
}
