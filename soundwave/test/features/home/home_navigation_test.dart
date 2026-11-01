import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/app/navigation_provider.dart';
import 'package:soundwave/app/song_selection.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/home/home_providers.dart';
import 'package:soundwave/features/search/mock_search_data.dart';
import 'package:soundwave/main.dart';

import '../../support/test_songs.dart';

void main() {
  test(
    'Inicio usa el catálogo de demostración compartido con Buscar',
    () async {
      final container = ProviderContainer(
        overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
      );
      addTearDown(container.dispose);

      final songs = await container.read(homeSongsProvider.future);

      expect(
        songs.map((song) => song.id),
        mockSearchSongs.map((song) => song.id),
      );
      expect(songs.any((song) => song.id.startsWith('mock:')), isFalse);
    },
  );

  testWidgets(
    'tocar una tarjeta de Inicio abre el Reproductor con el ID estable',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dataModeProvider.overrideWithValue(DataMode.demo),
            homeSongsProvider.overrideWith((ref) async => testSongs),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Quiet City'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Quiet City'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainShell)),
      );
      expect(container.read(selectedSongIdProvider), 'demo:quiet-city');
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        AppTab.player.index,
      );
    },
  );

  testWidgets('el estado vacío de Inicio lleva a Buscar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.demo),
          homeSongsProvider.overrideWith((ref) async => []),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu biblioteca está vacía.'), findsOneWidget);
    await tester.tap(find.text('Buscar música'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      AppTab.search.index,
    );
  });
}
