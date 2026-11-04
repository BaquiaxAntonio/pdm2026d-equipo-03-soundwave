import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/player/models/player_track.dart';
import '../features/player/providers/player_provider.dart';
import 'app_theme.dart';
import 'navigation_provider.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeTabProvider);
    final state = ref.watch(playerControllerProvider);
    final track = state.currentTrack;
    if (activeTab == AppTab.player || track == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(playerControllerProvider.notifier);
    final progress = state.duration.inMilliseconds == 0
        ? 0.0
        : (state.position.inMilliseconds / state.duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => ref.read(activeTabProvider.notifier).select(AppTab.player),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.accent,
              semanticsLabel: 'Progreso de la canción actual',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              child: Row(
                children: [
                  _MiniCover(track: track),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Canción anterior',
                    onPressed: controller.previous,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton(
                    tooltip: state.isPlaying ? 'Pausar' : 'Reproducir',
                    onPressed: controller.toggle,
                    color: AppColors.accent,
                    icon: Icon(
                      state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Siguiente canción',
                    onPressed: controller.next,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.track});

  final PlayerTrack track;

  @override
  Widget build(BuildContext context) {
    final artworkUrl = track.song.artworkUrl;
    return Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceElevated),
      ),
      child: artworkUrl == null
          ? const Icon(Icons.music_note, color: AppColors.accent, size: 22)
          : Image.network(
              artworkUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.music_note,
                color: AppColors.accent,
                size: 22,
              ),
            ),
    );
  }
}
