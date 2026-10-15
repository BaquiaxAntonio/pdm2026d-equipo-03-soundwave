import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  }

  Future<void> searchFor(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
  }

  testWidgets('muestra sugerencias al iniciar', (tester) async {
    await pumpApp(tester);

    expect(find.text('Sugerencias para ti'), findsOneWidget);
    expect(find.text('Neon Horizon'), findsOneWidget);
  });

  testWidgets('busca por título', (tester) async {
    await pumpApp(tester);

    await searchFor(tester, 'Midnight');

    expect(find.text('1 resultado'), findsOneWidget);
    expect(find.text('Midnight Echo'), findsOneWidget);
    expect(find.text('Neon Horizon'), findsNothing);
  });

  testWidgets('busca por artista', (tester) async {
    await pumpApp(tester);

    await searchFor(tester, 'Atlas');

    expect(find.text('Midnight Echo'), findsOneWidget);
    expect(find.text('Atlas Bloom'), findsOneWidget);
  });

  testWidgets('ignora mayúsculas en la búsqueda', (tester) async {
    await pumpApp(tester);

    await searchFor(tester, 'NEON HORIZON');

    expect(find.text('Neon Horizon'), findsOneWidget);
  });

  testWidgets('ignora espacios externos en la consulta', (tester) async {
    await pumpApp(tester);

    await searchFor(tester, '  Quiet Thunder  ');

    expect(find.text('Quiet Thunder'), findsOneWidget);
    expect(find.text('1 resultado'), findsOneWidget);
  });

  testWidgets('una consulta de espacios mantiene las sugerencias', (
    tester,
  ) async {
    await pumpApp(tester);

    await searchFor(tester, '   ');

    expect(find.text('Sugerencias para ti'), findsOneWidget);
    expect(find.text('Neon Horizon'), findsOneWidget);
  });

  testWidgets('muestra el estado sin resultados', (tester) async {
    await pumpApp(tester);

    await searchFor(tester, 'Canción inexistente');

    expect(find.text('0 resultados'), findsOneWidget);
    expect(find.text('No encontramos canciones'), findsOneWidget);
    expect(find.text('Prueba con otro título o artista'), findsOneWidget);
  });

  testWidgets('limpiar restaura las sugerencias', (tester) async {
    await pumpApp(tester);
    await searchFor(tester, 'Neon Horizon');

    await tester.tap(find.byTooltip('Limpiar búsqueda'));
    await tester.pump();

    expect(find.text('Sugerencias para ti'), findsOneWidget);
    expect(find.text('Neon Horizon'), findsOneWidget);
    expect(find.byTooltip('Limpiar búsqueda'), findsNothing);
  });
}
