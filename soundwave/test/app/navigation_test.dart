import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/downloads/download_screen.dart';
import 'package:soundwave/features/downloads/downloads_screen.dart';
import 'package:soundwave/features/home/home_screen.dart';
import 'package:soundwave/features/home/home_providers.dart';
import 'package:soundwave/features/search/search_screen.dart';
import 'package:soundwave/main.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/app/navigation_provider.dart';
import '../support/test_songs.dart';

void main() {
  testWidgets('cada destino de la barra selecciona su pestaña', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
        child: const MyApp(),
      ),
    );

    for (final tab in AppTab.values) {
      await tester.tap(
        find.text(switch (tab) {
          AppTab.home => 'Inicio',
          AppTab.search => 'Buscar',
          AppTab.player => 'Reproductor',
          AppTab.downloads => 'Descargas',
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
        tab.index,
      );
    }
  });

  testWidgets(
    'seleccionar Descargas activa DownloadScreen y retira el placeholder',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
          child: const MyApp(),
        ),
      );

      final shell = find.byType(MainShell);
      expect(
        find.descendant(of: shell, matching: find.byType(HomeScreen)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IndexedStack>(
              find.descendant(of: shell, matching: find.byType(IndexedStack)),
            )
            .index,
        0,
      );

      await tester.tap(find.text('Descargas'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IndexedStack>(
              find.descendant(of: shell, matching: find.byType(IndexedStack)),
            )
            .index,
        3,
      );
      expect(find.byType(DownloadScreen), findsOneWidget);
      expect(find.byType(DownloadsScreen, skipOffstage: false), findsNothing);
    },
  );

  testWidgets('Ver todo desde Inicio abre el listado de Buscar por provider', (
    tester,
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
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver todo'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index,
      AppTab.search.index,
    );
  });

  testWidgets('cambiar de pestaña y regresar conserva el scroll de Inicio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
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

    final homeScroll = Scrollable.of(tester.element(find.text('Recientes')));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -360),
    );
    await tester.pumpAndSettle();
    final initialOffset = homeScroll.position.pixels;
    expect(initialOffset, greaterThan(0));

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();

    expect(homeScroll.position.pixels, initialOffset);
  });
}
