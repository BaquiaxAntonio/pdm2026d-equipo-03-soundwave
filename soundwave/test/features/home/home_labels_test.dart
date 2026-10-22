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
];

void main() {
  testWidgets('Inicio muestra etiquetas honestas de listas de ejemplo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSongsProvider.overrideWith((ref) async => testSongs),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Favoritos de ejemplo'), findsOneWidget);
    expect(find.text('Recomendados de ejemplo'), findsOneWidget);
    expect(find.text('Favoritos'), findsNothing);
    expect(find.text('Recomendados'), findsNothing);
  });
}
