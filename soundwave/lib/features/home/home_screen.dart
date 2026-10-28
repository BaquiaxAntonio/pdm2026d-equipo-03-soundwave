import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_theme.dart';
import '../../core/models/song.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSongs = ref.watch(homeSongsProvider);

    return Scaffold(
      appBar: _buildAppBar(context),
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

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: Text(
        'SoundWave',
        style: AppTextStyles.screenTitle.copyWith(color: AppColors.textPrimary),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {},
          tooltip: 'Buscar',
        ),
        const SizedBox(width: AppSpacing.s8),
      ],
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
            'Cargando catálogo...',
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
              'Aún no hay datos.',
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'No se encontraron canciones en el catálogo.',
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final isTablet = width >= 600 && width < 800;

    final recent = songs.take(6).toList();
    final favorites = songs.skip(6).take(6).toList();
    final recommended = songs.skip(12).take(6).toList();
    final topArtists = songs.skip(18).take(4).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            _HeroSection(
              recentSong: recent.isNotEmpty ? recent.first : null,
              onPlayRecent: () {},
            ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.horizontalMargin(context),
                vertical: AppSpacing.s16,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _SectionHeader(title: 'Recientes', onSeeAll: () {}),
                  const SizedBox(height: AppSpacing.s12),
                  _ResponsiveSongGrid(
                    songs: recent,
                    crossAxisCount: isDesktop
                        ? 4
                        : isTablet
                        ? 3
                        : 2,
                    childAspectRatio: 0.7,
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  _SectionHeader(title: 'Favoritos', onSeeAll: () {}),
                  const SizedBox(height: AppSpacing.s12),
                  _ResponsiveSongGrid(
                    songs: favorites,
                    crossAxisCount: isDesktop
                        ? 4
                        : isTablet
                        ? 3
                        : 2,
                    childAspectRatio: 0.7,
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  _SectionHeader(
                    title: 'Recomendados para ti',
                    onSeeAll: () {},
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _ResponsiveSongGrid(
                    songs: recommended,
                    crossAxisCount: isDesktop
                        ? 4
                        : isTablet
                        ? 3
                        : 2,
                    childAspectRatio: 0.7,
                  ),
                  if (topArtists.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s32),
                    _SectionHeader(
                      title: 'Artistas principales',
                      onSeeAll: () {},
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _ArtistGrid(
                      songs: topArtists,
                      crossAxisCount: isDesktop
                          ? 4
                          : isTablet
                          ? 3
                          : 2,
                      childAspectRatio: 0.65,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s32),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Song? recentSong;
  final VoidCallback onPlayRecent;

  const _HeroSection({required this.recentSong, required this.onPlayRecent});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;
    final horizontalMargin = AppSpacing.horizontalMargin(context);

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: horizontalMargin,
          vertical: AppSpacing.s16,
        ),
        padding: EdgeInsets.all(isDesktop ? AppSpacing.s32 : AppSpacing.s24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceElevated.withValues(alpha: 0.8),
              AppColors.surface.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: _HeroContent(
                      recentSong: recentSong,
                      onPlayRecent: onPlayRecent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s24),
                  Expanded(
                    flex: 2,
                    child: _HeroArtwork(recentSong: recentSong),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroContent(
                    recentSong: recentSong,
                    onPlayRecent: onPlayRecent,
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  _HeroArtwork(recentSong: recentSong),
                ],
              ),
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  final Song? recentSong;
  final VoidCallback onPlayRecent;

  const _HeroContent({required this.recentSong, required this.onPlayRecent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buenos días',
          style: AppTextStyles.bodySecondary.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          'Qué quieres escuchar hoy?',
          style: AppTextStyles.screenTitle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        _buildContinueListeningSection(context, recentSong),
      ],
    );
  }

  Widget _buildContinueListeningSection(
    BuildContext context,
    Song? recentSong,
  ) {
    if (recentSong != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continuar escuchando',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.s12),
          _RecentSongCard(song: recentSong, onTap: onPlayRecent),
        ],
      );
    }
    return FilledButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('Explorar catálogo'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s24,
          vertical: AppSpacing.s16,
        ),
      ),
    );
  }
}

class _HeroArtwork extends StatelessWidget {
  final Song? recentSong;

  const _HeroArtwork({required this.recentSong});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accent.withValues(alpha: 0.3),
              AppColors.surfaceElevated,
            ],
          ),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (recentSong?.artworkUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  recentSong!.artworkUrl!.toString(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildPlaceholder(),
                ),
              )
            else
              _buildPlaceholder(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: AppSpacing.s16,
              left: AppSpacing.s16,
              right: AppSpacing.s16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recentSong != null) ...[
                    Text(
                      recentSong!.title,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      recentSong!.artist,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    Text(
                      'Descubre nueva música',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 80,
        color: AppColors.accent.withValues(alpha: 0.5),
      ),
    );
  }
}

class _RecentSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _RecentSongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceElevated),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.surfaceElevated,
              ),
              child: song.artworkUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        song.artworkUrl!.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.music_note,
                          color: AppColors.accent,
                        ),
                      ),
                    )
                  : const Icon(Icons.music_note, color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    song.artist,
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.onAccent,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _SectionHeader({required this.title, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.sectionTitle.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: onSeeAll,
          child: Text(
            'Ver todo',
            style: AppTextStyles.body.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponsiveSongGrid extends StatelessWidget {
  final List<Song> songs;
  final int crossAxisCount;
  final double childAspectRatio;

  const _ResponsiveSongGrid({
    required this.songs,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.s12,
        mainAxisSpacing: AppSpacing.s12,
      ),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return _GridSongCard(song: song, onTap: () {});
      },
    );
  }
}

class _GridSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _GridSongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surfaceElevated,
                  ),
                  child: song.artworkUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            song.artworkUrl!.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholder(),
                          ),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              Positioned(
                bottom: AppSpacing.s8,
                right: AppSpacing.s8,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.onAccent,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  song.artist,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.music_note_rounded,
        size: 40,
        color: AppColors.accent.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ArtistGrid extends StatelessWidget {
  final List<Song> songs;
  final int crossAxisCount;
  final double childAspectRatio;

  const _ArtistGrid({
    required this.songs,
    required this.crossAxisCount,
    required this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    // Group by artist
    final artistMap = <String, List<Song>>{};
    for (final song in songs) {
      artistMap.putIfAbsent(song.artist, () => []).add(song);
    }
    final artists = artistMap.keys.take(crossAxisCount).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: AppSpacing.s12,
        mainAxisSpacing: AppSpacing.s12,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final artistSongs = artistMap[artist]!;
        return _ArtistCard(
          artistName: artist,
          songCount: artistSongs.length,
          artworkUrl: artistSongs.first.artworkUrl,
          onTap: () {},
        );
      },
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final String artistName;
  final int songCount;
  final Uri? artworkUrl;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.artistName,
    required this.songCount,
    required this.artworkUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: AppColors.surfaceElevated,
                border: Border.all(color: AppColors.surfaceElevated),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: artworkUrl != null
                    ? Image.network(
                        artworkUrl!.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  artistName,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  '$songCount canciones',
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: 40,
        color: AppColors.accent.withValues(alpha: 0.5),
      ),
    );
  }
}
