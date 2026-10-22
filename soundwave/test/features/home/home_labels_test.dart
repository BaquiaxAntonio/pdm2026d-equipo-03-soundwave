import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/home/home_screen.dart';

void main() {
  testWidgets('Inicio muestra etiquetas honestas de listas de ejemplo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Recientes'), findsOneWidget);
    expect(find.text('Favoritos de ejemplo'), findsOneWidget);
    expect(find.text('Recomendados de ejemplo'), findsOneWidget);
    expect(find.text('Favoritos'), findsNothing);
    expect(find.text('Recomendados'), findsNothing);
  });
}
