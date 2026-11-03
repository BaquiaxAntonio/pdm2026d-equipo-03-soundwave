import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation_provider.dart';
import '../search/search_controller.dart';
import 'player_cover_local.dart';
import 'player_playlists_screen.dart';
import 'providers/player_provider.dart';
import 'providers/player_from_downloads_provider.dart';
import 'providers/player_queue_provider.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  String _time(Duration duration) =>
      '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerFromDownloadsProvider);
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final track = state.currentTrack;
    final song = track?.song;
    final filter = ref
        .watch(playerQueueFilterProvider)
        .text
        .trim()
        .toLowerCase();
    final playable = state.playableTracks;
    final currentIndex = playable.indexWhere((t) => t.id == track?.id);
    final ordered = currentIndex < 0
        ? playable
        : [...playable.skip(currentIndex), ...playable.take(currentIndex)];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reproductor',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Listas de reproducción',
                      icon: const Icon(Icons.queue_music),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PlayerPlaylistsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(state.error!),
                  if (track != null)
                    TextButton(
                      onPressed: controller.play,
                      child: const Text('Reintentar'),
                    ),
                ],
                if (song == null) ...[
                  const SizedBox(height: 24),
                  const Text('No hay canciones disponibles para reproducir.'),
                  FilledButton.icon(
                    onPressed: () => ref
                        .read(activeTabProvider.notifier)
                        .select(AppTab.search),
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar música libre'),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Center(child: PlayerCoverLocal(songId: song.id)),
                  const SizedBox(height: 16),
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(song.artist, textAlign: TextAlign.center),
                  Text(
                    track!.localPath == null
                        ? 'Reproducción por Internet'
                        : 'Archivo local · Sin conexión',
                    textAlign: TextAlign.center,
                  ),
                  if (state.isLoading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Cargando audio',
                    ),
                  Slider(
                    value: state.position.inMilliseconds.toDouble().clamp(
                      0,
                      state.duration.inMilliseconds.toDouble(),
                    ),
                    max: state.duration.inMilliseconds > 0
                        ? state.duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged:
                        state.duration > Duration.zero && !state.isLoading
                        ? (value) => controller.seek(
                            Duration(milliseconds: value.round()),
                          )
                        : null,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_time(state.position)),
                      Text(_time(state.duration)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Anterior',
                        onPressed: playable.isEmpty || state.isLoading
                            ? null
                            : controller.previous,
                        icon: const Icon(Icons.skip_previous),
                      ),
                      IconButton.filled(
                        tooltip: state.isPlaying ? 'Pausar' : 'Reproducir',
                        onPressed:
                            state.isLoading ||
                                state.blockedIds.contains(song.id)
                            ? null
                            : controller.toggle,
                        iconSize: 40,
                        icon: Icon(
                          state.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Siguiente',
                        onPressed: playable.isEmpty || state.isLoading
                            ? null
                            : controller.next,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ],
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: track.localPath == null
                            ? null
                            : () => controller.setBlocked(song.id, true),
                        icon: const Icon(Icons.block),
                        label: const Text('Bloquear canción'),
                      ),
                      TextButton.icon(
                        onPressed: track.localPath != null
                            ? null
                            : () async {
                                final result = await ref
                                    .read(
                                      searchDownloadControllerProvider.notifier,
                                    )
                                    .request(song);
                                if (context.mounted && result.message != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(result.message!)),
                                  );
                                }
                              },
                        icon: const Icon(Icons.download),
                        label: Text(
                          track.localPath != null ? 'Descargada' : 'Descargar',
                        ),
                      ),
                    ],
                  ),
                  if (song.license != null)
                    ExpansionTile(
                      title: Text('Créditos · ${song.license}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            '${song.title}\n${song.artist}\n${song.attribution ?? ''}\n${song.licenseUrl ?? ''}\n${song.sourceUrl ?? ''}',
                          ),
                        ),
                      ],
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Cola de reproducción',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text('Tus descargas y la canción online seleccionada'),
                TextFormField(
                  initialValue: ref.read(playerQueueFilterProvider).text,
                  decoration: const InputDecoration(
                    labelText: 'Filtrar por título o artista',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: ref
                      .read(playerQueueFilterProvider.notifier)
                      .setText,
                ),
                if (playable.isEmpty) const Text('La cola está vacía.'),
                for (final item in ordered.where(
                  (t) =>
                      t.title.toLowerCase().contains(filter) ||
                      t.artist.toLowerCase().contains(filter),
                ))
                  ListTile(
                    key: ValueKey(item.id),
                    selected: item.id == track?.id,
                    leading: Icon(
                      item.localPath == null ? Icons.cloud : Icons.offline_bolt,
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      item.id == track?.id
                          ? 'En reproducción · ${item.artist}'
                          : item.artist,
                    ),
                    onTap: () => controller.select(item.id),
                  ),
                if (state.blockedIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Canciones bloqueadas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final item in state.tracks.where(
                    (t) => state.blockedIds.contains(t.id),
                  ))
                    ListTile(
                      title: Text(item.title),
                      subtitle: Text(item.artist),
                      trailing: TextButton(
                        onPressed: () => controller.setBlocked(item.id, false),
                        child: const Text('Desbloquear'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
