import 'package:flutter/material.dart';

import 'player_cover_local.dart';
import 'player_store.dart';
import 'player_theme_local.dart';

// Pantalla del reproductor offline mock (issues #7 y #8) con el
// sistema visual SoundWave: fondo oscuro, turquesa de acento,
// portada protagonista y bloquear diferenciado del control principal.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerStore store;

  @override
  void initState() {
    super.initState();
    store = PlayerStore();
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

  @override
  Widget build(BuildContext context) {
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
                      return _BlockedEmptyState(horizontal: horizontal);
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
                        Text(
                          song.title,
                          style: PlayerThemeLocal.songTitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                            onPressed: store.blockCurrent,
                          ),
                        ),
                        const SizedBox(height: PlayerThemeLocal.space8),
                        Text(
                          'Bloqueadas en sesión: ${store.blockedIds.length}',
                          style: PlayerThemeLocal.auxiliary,
                          textAlign: TextAlign.center,
                        ),
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

class _BlockedEmptyState extends StatelessWidget {
  final double horizontal;

  const _BlockedEmptyState({required this.horizontal});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(horizontal),
      children: const [
        SizedBox(height: PlayerThemeLocal.space32),
        Icon(
          Icons.block,
          size: 48,
          color: PlayerThemeLocal.textSecondary,
          semanticLabel: 'Todo bloqueado',
        ),
        SizedBox(height: PlayerThemeLocal.space16),
        Text(
          'Todas bloqueadas en esta sesión',
          style: PlayerThemeLocal.songTitle,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
