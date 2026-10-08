import 'package:flutter/material.dart';

import 'player_store.dart';

// Pantalla del reproductor offline mock (issues #7 y #8).
// Motivo: UI aislada, sin rutas ni estado global, funciona en modo avión.
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
      appBar: AppBar(title: const Text('Reproductor offline')),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final song = store.currentSong;
          if (song == null) {
            return const Center(child: Text('Todas bloqueadas en esta sesión'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.offline_bolt),
                  title: Text('Modo avión mock'),
                  subtitle: Text('Sin internet y sin anuncios'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                song.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(song.artist),
              const SizedBox(height: 8),
              Slider(
                value: store.progressSeconds.toDouble().clamp(
                  0,
                  song.durationSeconds.toDouble(),
                ),
                max: song.durationSeconds.toDouble(),
                onChanged: (_) {},
              ),
              Text(
                '${formatTime(store.progressSeconds)} / ${formatTime(song.durationSeconds)}',
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: store.previous,
                  ),
                  IconButton(
                    icon: Icon(
                      store.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    iconSize: 48,
                    onPressed: store.toggle,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: store.next,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.block),
                label: const Text('Bloquear canción'),
                onPressed: store.blockCurrent,
              ),
              Text('Bloqueadas en sesión: ${store.blockedIds.length}'),
            ],
          );
        },
      ),
    );
  }
}
