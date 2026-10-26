import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/app_theme.dart';
import '../../../app/navigation_provider.dart';
import '../../../core/models/song.dart';
import 'song_card.dart';

class SongListSection extends ConsumerWidget {
  final String title;
  final List<Song> songs;
  final bool showViewAll;

  const SongListSection({
    super.key,
    required this.title,
    required this.songs,
    this.showViewAll = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (showViewAll)
              TextButton(
                onPressed: () =>
                    ref.read(activeTabProvider.notifier).select(AppTab.search),
                child: const Text('Ver todo'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s12),
            itemBuilder: (context, index) {
              final song = songs[index];
              return SongCard(song: song, onTap: () {});
            },
          ),
        ),
      ],
    );
  }
}
