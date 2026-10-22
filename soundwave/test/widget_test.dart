import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/main.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';

void main() {
  testWidgets('Home screen shows navigation buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
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
        overrides: [dataModeProvider.overrideWithValue(DataMode.demo)],
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
