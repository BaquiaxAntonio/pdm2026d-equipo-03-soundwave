import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app_theme.dart';
import 'app/mini_player.dart';
import 'app/navigation_provider.dart';
import 'features/downloads/download_screen.dart';
import 'features/home/home_screen.dart';
import 'features/player/player_screen.dart';
import 'app/playback_integration.dart';
import 'features/downloads/download_providers.dart';
import 'features/player/providers/player_can_delete.dart';
import 'features/playlists/playlist_screen.dart';
import 'features/search/search_screen.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        canDeleteAudioProvider.overrideWith(
          (ref) =>
              (songId) =>
                  ref.read(playerDeletionGuardProvider).canDelete(songId),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundWave',
      theme: AppTheme.dark,
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Composition point: keep the real playback controller fed from the
    // completed downloads instead of relying on test overrides.
    ref.watch(playbackIntegrationProvider);
    final activeTab = ref.watch(activeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: activeTab.index,
        children: [
          const HomeScreen(),
          const SearchScreen(),
          const PlayerScreen(),
          const DownloadScreen(),
          // Playlists load from the database, so they are built the first time
          // the tab is opened instead of at startup.
          _LazyTab(
            active: activeTab == AppTab.playlists,
            builder: (_) => const PlaylistScreen(),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: activeTab.index,
            onDestinationSelected: (index) => ref
                .read(activeTabProvider.notifier)
                .select(AppTab.values[index]),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: 'Buscar',
              ),
              NavigationDestination(
                icon: Icon(Icons.play_circle_outline),
                selectedIcon: Icon(Icons.play_circle),
                label: 'Reproductor',
              ),
              NavigationDestination(
                icon: Icon(Icons.download_outlined),
                selectedIcon: Icon(Icons.download),
                label: 'Descargas',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music),
                label: 'Listas',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Builds its child once, the first time [active] becomes true, and keeps it
/// alive afterwards so tab state is not lost.
class _LazyTab extends StatefulWidget {
  const _LazyTab({required this.active, required this.builder});

  final bool active;
  final WidgetBuilder builder;

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  late bool _started = widget.active;

  @override
  void didUpdateWidget(_LazyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) _started = true;
  }

  @override
  Widget build(BuildContext context) =>
      _started ? widget.builder(context) : const SizedBox.shrink();
}
