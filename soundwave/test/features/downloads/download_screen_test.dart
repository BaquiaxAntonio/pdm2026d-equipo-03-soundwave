import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/downloads/download_screen.dart';
import 'package:soundwave/features/downloads/download_store.dart';
import 'package:soundwave/features/downloads/mock_download_data.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';

void main() {
  test('La lista es inmutable y restaurar no duplica canciones', () {
    final container = ProviderContainer(
      overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
    );
    addTearDown(container.dispose);
    final store = container.read(downloadStoreProvider.notifier);
    expect(
      () => container.read(downloadStoreProvider).clear(),
      throwsUnsupportedError,
    );
    store.remove(mockDownloads.first.id);
    expect(container.read(downloadStoreProvider), hasLength(5));
    store.restore(mockDownloads.first);
    store.restore(mockDownloads.first);
    expect(container.read(downloadStoreProvider), orderedEquals(mockDownloads));
  });

  testWidgets('Eliminar, deshacer y conservar al desmontar la pantalla', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
    );
    addTearDown(container.dispose);
    Widget app(Widget screen) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: screen),
    );
    await tester.pumpWidget(app(const DownloadScreen()));
    await tester.tap(find.byTooltip('Eliminar Después de la lluvia'));
    await tester.pumpAndSettle();
    expect(container.read(downloadStoreProvider), hasLength(5));
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(container.read(downloadStoreProvider), hasLength(6));
    await tester.tap(find.byTooltip('Eliminar Después de la lluvia'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const Scaffold(body: Text('Otra pantalla'))));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const DownloadScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Después de la lluvia'), findsNothing);
    expect(container.read(downloadStoreProvider), hasLength(5));
  });

  for (final width in [320.0, 360.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Lista y vacío sin overflow: ancho $width, texto $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const DownloadScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final song in mockDownloads) {
          container.read(downloadStoreProvider.notifier).remove(song.id);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Restaurar ejemplos'), 200);
        await tester.pumpAndSettle();
        expect(find.text('Tu próxima colección empieza aquí'), findsOneWidget);
        await tester.tap(find.text('Restaurar ejemplos'));
        await tester.pumpAndSettle();
        expect(
          container.read(downloadStoreProvider),
          hasLength(mockDownloads.length),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
