import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/downloads/download_screen.dart';
import 'package:soundwave/features/downloads/downloads_screen.dart';
import 'package:soundwave/features/home/home_screen.dart';
import 'package:soundwave/main.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';

void main() {
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
}
