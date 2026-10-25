import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_theme.dart';
import '../../core/models/song.dart';
import 'home_providers.dart';
import 'widgets/song_list_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSongs = ref.watch(homeSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SoundWave')),
      body: SafeArea(
        child: asyncSongs.when(
          loading: () => const _LoadingState(),
          error: (error, stackTrace) => _ErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(homeSongsProvider),
          ),
          data: (songs) {
            if (songs.isEmpty) {
              return const _EmptyState();
            }
            return _HomeContent(songs: songs);
          },
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Cargando catÃ¡logo...',
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'No pudimos cargar los datos.',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'AÃºn no hay datos.',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'No se encontraron canciones en el catÃ¡logo.',
              style: AppTextStyles.bodySecondary.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final List<Song> songs;

  const _HomeContent({required this.songs});

  @override
  Widget build(BuildContext context) {
    // Agrupar por secciones simuladas (usando provider como fuente)
    final recent = songs.take(4).toList();
    final favorites = songs.skip(4).take(4).toList();
    final recommended = songs.skip(8).take(4).toList();

    return SingleChildScrollView(
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
              SongListSection(title: 'Recientes', songs: recent),
              const SizedBox(height: AppSpacing.s32),
              SongListSection(title: 'Favoritos de ejemplo', songs: favorites),
              const SizedBox(height: AppSpacing.s32),
              SongListSection(
                title: 'Recomendados de ejemplo',
                songs: recommended,
              ),
              const SizedBox(height: AppSpacing.s24),
            ],
          ),
        ),
      ),
    );
  }
}
