import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import 'data/mock_songs.dart';
import 'widgets/song_list_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SoundWave'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.horizontalMargin(context),
                vertical: AppSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.s16),
                  SongListSection(
                    title: 'Recientes',
                    songs: recentSongs,
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  SongListSection(
                    title: 'Favoritos',
                    songs: favoriteSongs,
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  SongListSection(
                    title: 'Recomendados',
                    songs: recommendedSongs,
                  ),
                  const SizedBox(height: AppSpacing.s24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
