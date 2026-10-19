import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/home/home_providers.dart';
import 'package:soundwave/main.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';

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
  testWidgets('Home screen shows navigation buttons', (
    WidgetTester tester,
  ) async {
await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.demo),
          homeSongsProvider.overrideWith((ref) async => testSongs),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.text('SoundWave'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Reproductor'), findsOneWidget);
    expect(find.text('Descargas'), findsOneWidget);
  });

  testWidgets('Home screen handles large text scale without overflow', (
    WidgetTester tester,
  ) async {
await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.demo),
          homeSongsProvider.overrideWith((ref) async => testSongs),
        ],
        child: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(1.5),
            size: Size(320, 600),
          ),
          child: const MyApp(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SoundWave'), findsOneWidget);
    expect(find.text('Buscar'), findsWidgets);
    expect(find.text('Reproductor'), findsWidgets);
    expect(find.text('Descargas'), findsWidgets);
  });
}
