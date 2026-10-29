import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/home/home_providers.dart';
import 'package:soundwave/features/home/home_screen.dart';

const testSongs = [
  Song(
    id: 'demo:blue-hour',
    title: 'Blue Hour',
    artist: 'The Soundwaves',
    durationMs: 205000,
    provider: 'demo',
    sourceId: 'blue-hour',
  ),
  Song(
    id: 'demo:quiet-city',
    title: 'Quiet City',
    artist: 'Luna Norte',
    durationMs: 189000,
    provider: 'demo',
    sourceId: 'quiet-city',
  ),
  Song(
    id: 'demo:open-road',
    title: 'Open Road',
    artist: 'The Soundwaves',
    durationMs: 240000,
    provider: 'demo',
    sourceId: 'open-road',
  ),
  Song(
    id: 'demo:midnight-drive',
    title: 'Midnight Drive',
    artist: 'Neon Dreams',
    durationMs: 210000,
    provider: 'demo',
    sourceId: 'midnight-drive',
  ),
  Song(
    id: 'demo:summer-vibes',
    title: 'Summer Vibes',
    artist: 'Coastline',
    durationMs: 195000,
    provider: 'demo',
    sourceId: 'summer-vibes',
  ),
  Song(
    id: 'demo:city-lights',
    title: 'City Lights',
    artist: 'Urban Echo',
    durationMs: 220000,
    provider: 'demo',
    sourceId: 'city-lights',
  ),
  Song(
    id: 'demo:lost-in-time',
    title: 'Lost in Time',
    artist: 'The Soundwaves',
    durationMs: 200000,
    provider: 'demo',
    sourceId: 'lost-in-time',
  ),
  Song(
    id: 'demo:neon-nights',
    title: 'Neon Nights',
    artist: 'Luna Norte',
    durationMs: 230000,
    provider: 'demo',
    sourceId: 'neon-nights',
  ),
  Song(
    id: 'demo:horizon',
    title: 'Horizon',
    artist: 'Coastline',
    durationMs: 180000,
    provider: 'demo',
    sourceId: 'horizon',
  ),
  Song(
    id: 'demo:retro-wave',
    title: 'Retro Wave',
    artist: 'Neon Dreams',
    durationMs: 210000,
    provider: 'demo',
    sourceId: 'retro-wave',
  ),
  Song(
    id: 'demo:electric-dreams',
    title: 'Electric Dreams',
    artist: 'Urban Echo',
    durationMs: 225000,
    provider: 'demo',
    sourceId: 'electric-dreams',
  ),
  Song(
    id: 'demo:sunset-boulevard',
    title: 'Sunset Boulevard',
    artist: 'The Soundwaves',
    durationMs: 240000,
    provider: 'demo',
    sourceId: 'sunset-boulevard',
  ),
  Song(
    id: 'demo:midnight-city',
    title: 'Midnight City',
    artist: 'Luna Norte',
    durationMs: 205000,
    provider: 'demo',
    sourceId: 'midnight-city',
  ),
  Song(
    id: 'demo:golden-hour',
    title: 'Golden Hour',
    artist: 'Coastline',
    durationMs: 190000,
    provider: 'demo',
    sourceId: 'golden-hour',
  ),
  Song(
    id: 'demo:solar-flare',
    title: 'Solar Flare',
    artist: 'Neon Dreams',
    durationMs: 215000,
    provider: 'demo',
    sourceId: 'solar-flare',
  ),
  Song(
    id: 'demo:starlight',
    title: 'Starlight',
    artist: 'Coastline',
    durationMs: 200000,
    provider: 'demo',
    sourceId: 'starlight',
  ),
  Song(
    id: 'demo:cosmic-dust',
    title: 'Cosmic Dust',
    artist: 'Urban Echo',
    durationMs: 225000,
    provider: 'demo',
    sourceId: 'cosmic-dust',
  ),
  Song(
    id: 'demo:aurora',
    title: 'Aurora',
    artist: 'The Soundwaves',
    durationMs: 240000,
    provider: 'demo',
    sourceId: 'aurora',
  ),
  Song(
    id: 'demo:eclipse',
    title: 'Eclipse',
    artist: 'Luna Norte',
    durationMs: 205000,
    provider: 'demo',
    sourceId: 'eclipse',
  ),
  Song(
    id: 'demo:zenith',
    title: 'Zenith',
    artist: 'Coastline',
    durationMs: 190000,
    provider: 'demo',
    sourceId: 'zenith',
  ),
];

void main() {
  testWidgets('Inicio muestra secciones con etiquetas correctas', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [homeSongsProvider.overrideWith((ref) async => testSongs)],
        child: MaterialApp(
          home: SizedBox(height: 1000, width: 400, child: const HomeScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    Future<void> scrollTo(String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        500,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }

    await scrollTo('Recientes');
    expect(find.text('Recientes'), findsOneWidget);

    await scrollTo('Favoritos');
    expect(find.text('Favoritos'), findsOneWidget);

    await scrollTo('Recomendados para ti');
    expect(find.text('Recomendados para ti'), findsOneWidget);

    await scrollTo('Artistas principales');
    expect(find.text('Artistas principales'), findsOneWidget);

    expect(find.text('Favoritos de ejemplo'), findsNothing);
    expect(find.text('Recomendados de ejemplo'), findsNothing);
  });
}
