import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/home/home_providers.dart';
import 'package:soundwave/features/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen muestra estado de error con botÃ³n Reintentar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSongsProvider.overrideWith((ref) async {
            throw Exception('Error de red simulado');
          }),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // Esperar a que se muestre el estado de error
    await tester.pumpAndSettle();

    // Verificar que se muestra el mensaje de error
    expect(find.text('No pudimos cargar los datos.'), findsOneWidget);
    expect(find.textContaining('Error de red simulado'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    // Verificar que el botÃ³n Reintentar es interactuable
    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    // El botÃ³n deberÃ­a responder al toque (no lanza error)
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('HomeScreen muestra estado de datos cuando provider tiene Ã©xito', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSongsProvider.overrideWith((ref) async => [
            Song(
              id: 'demo:test-song',
              title: 'Test Song',
              artist: 'Test Artist',
              durationMs: 180000,
              provider: 'demo',
              sourceId: 'test-song',
            ),
          ]),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verificar estado de datos
    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });
}