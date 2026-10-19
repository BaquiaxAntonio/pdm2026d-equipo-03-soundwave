import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';
import '../../../core/models/song.dart';
import 'song_card.dart';

class SongListSection extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const SongListSection({super.key, required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.textPrimary,
          ),
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
