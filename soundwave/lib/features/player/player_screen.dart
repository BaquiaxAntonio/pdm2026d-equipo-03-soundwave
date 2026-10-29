import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/player_queue_repository.dart';
import 'player_cover_local.dart';
import 'player_queue_view.dart';
import 'player_store.dart';
import 'player_theme_local.dart';
import 'providers/player_download_provider.dart';
import 'providers/player_queue_provider.dart';

// Pantalla del reproductor offline mock (issues #7 y #8) con el
// sistema visual SoundWave: fondo oscuro, turquesa de acento,
// portada protagonista y bloquear diferenciado del control principal.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late PlayerStore store;
  final _queueKey = GlobalKey();
  bool _requestingDownload = false;

  @override
  void initState() {
    super.initState();
    store = PlayerStore(songs: []);
  }

  // El filtro solo cambia las filas visibles, nunca la cola reproducible.
  void _syncQueue(List<PlayerQueueEntry> entries) {
    final currentId = store.currentSong?.id;
    final progress = store.progressSeconds;
    final wasPlaying = store.isPlaying;
    final blocked = Set<String>.of(store.blockedIds);
    store.dispose();
    store = PlayerStore(songs: entries.map((entry) => entry.song).toList());
    store.blockedIds.addAll(blocked);
    if (store.playableSongs.any((song) => song.id == currentId)) {
      while (store.currentSong?.id != currentId) {
        store.next();
      }
      store.seek(progress);
    }
    if (wasPlaying) store.play();
    setState(() {});
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  String formatTime(int total) {
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _blockCurrent() {
    final song = store.currentSong;
    final snapshot = store.blockCurrent();
    if (song == null || snapshot == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        persist: false,
        showCloseIcon: true,
        content: Text('${song.title}: canción bloqueada'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            if (!mounted) return;
            // Usa el store vigente: la cola puede haberse actualizado.
            if (!store.undoBlock(snapshot)) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'La canción ya no está bloqueada o salió de la cola.',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _downloadCurrent() async {
    final song = store.currentSong;
    if (song == null || _requestingDownload) return;
    setState(() => _requestingDownload = true);
    String message;
    try {
      message = await ref.read(playerDownloadProvider)(song.id);
    } catch (_) {
      message = 'No se pudo descargar la canción. Intenta de nuevo.';
    }
    if (!mounted) return;
    setState(() => _requestingDownload = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(fullPlayerQueueProvider, (_, next) {
      next.whenData(_syncQueue);
    });
    ref.watch(fullPlayerQueueProvider);
    return Scaffold(
      backgroundColor: PlayerThemeLocal.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = constraints.maxWidth < 360
                ? PlayerThemeLocal.space16
                : PlayerThemeLocal.space24;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: AnimatedBuilder(
                  animation: store,
                  builder: (context, _) {
                    final song = store.currentSong;
                    if (song == null) {
                      return ListView(
                        padding: EdgeInsets.all(horizontal),
                        children: [
                          const Text(
                            'No hay canciones disponibles para reproducir.',
                          ),
                          const SizedBox(height: PlayerThemeLocal.space24),
                          PlayerQueueView(key: _queueKey),
                        ],
                      );
                    }
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        PlayerThemeLocal.space16,
                        horizontal,
                        PlayerThemeLocal.space32,
                      ),
                      children: [
                        const Text(
                          'Reproductor offline',
                          style: PlayerThemeLocal.screenTitle,
                        ),
                        const SizedBox(height: PlayerThemeLocal.space4),
                        const Row(
                          children: [
                            Icon(
                              Icons.offline_bolt,
                              size: 16,
                              color: PlayerThemeLocal.textSecondary,
                            ),
                            SizedBox(width: PlayerThemeLocal.space4),
                            Text(
                              'Sin internet y sin anuncios',
                              style: PlayerThemeLocal.auxiliary,
                            ),
                          ],
                        ),
                        const SizedBox(height: PlayerThemeLocal.space24),
                        // Portada como protagonista, sin tarjeta anidada.
                        Center(child: PlayerCoverLocal(songId: song.id)),
                        const SizedBox(height: PlayerThemeLocal.space16),
                        Row(
                          children: [
                            const SizedBox(width: 48),
                            Expanded(
                              child: Text(
                                song.title,
                                style: PlayerThemeLocal.songTitle,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: _requestingDownload
                                  ? 'Solicitando descarga'
                                  : 'Descargar canción',
                              color: PlayerThemeLocal.accent,
                              icon: Icon(
                                _requestingDownload
                                    ? Icons.hourglass_top
                                    : Icons.download_outlined,
                              ),
                              onPressed: _requestingDownload
                                  ? null
                                  : _downloadCurrent,
                            ),
                          ],
                        ),
                        const SizedBox(height: PlayerThemeLocal.space4),
                        Text(
                          song.artist,
                          style: PlayerThemeLocal.artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: PlayerThemeLocal.space16),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: PlayerThemeLocal.accent,
                            inactiveTrackColor:
                                PlayerThemeLocal.surfaceElevated,
                            thumbColor: PlayerThemeLocal.accent,
                          ),
                          child: Slider(
                            value: store.progressSeconds.toDouble().clamp(
                              0,
                              song.durationSeconds.toDouble(),
                            ),
                            max: song.durationSeconds.toDouble(),
                            onChanged: (v) => store.seek(v.round()),
                          ),
                        ),
                        Text(
                          '${formatTime(store.progressSeconds)} / ${formatTime(song.durationSeconds)}',
                          style: PlayerThemeLocal.auxiliary,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: PlayerThemeLocal.space16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Anterior',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(Icons.skip_previous),
                              color: PlayerThemeLocal.textPrimary,
                              iconSize: 32,
                              onPressed: store.previous,
                            ),
                            const SizedBox(width: PlayerThemeLocal.space16),
                            // Control principal: círculo turquesa grande.
                            SizedBox(
                              width: 72,
                              height: 72,
                              child: Tooltip(
                                message: store.isPlaying
                                    ? 'Pausar'
                                    : 'Reproducir',
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: PlayerThemeLocal.accent,
                                    foregroundColor: PlayerThemeLocal.onAccent,
                                    shape: const CircleBorder(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: store.toggle,
                                  child: Icon(
                                    store.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: PlayerThemeLocal.space16),
                            IconButton(
                              tooltip: 'Siguiente',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: const Icon(Icons.skip_next),
                              color: PlayerThemeLocal.textPrimary,
                              iconSize: 32,
                              onPressed: store.next,
                            ),
                          ],
                        ),
                        const SizedBox(height: PlayerThemeLocal.space24),
                        // Bloquear diferenciado: contorno en error, no
                        // turquesa, separado del control principal.
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: PlayerThemeLocal.error,
                              side: const BorderSide(
                                color: PlayerThemeLocal.error,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  PlayerThemeLocal.buttonRadius,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.block),
                            label: const Text('Bloquear canción'),
                            onPressed: _blockCurrent,
                          ),
                        ),
                        const SizedBox(height: PlayerThemeLocal.space8),
                        Text(
                          'Bloqueadas en sesión: ${store.blockedIds.length}',
                          style: PlayerThemeLocal.auxiliary,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: PlayerThemeLocal.space24),
                        PlayerQueueView(key: _queueKey),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
