import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/main.dart';

void main() {
  testWidgets('Home screen shows navigation buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('SoundWave'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Reproductor'), findsOneWidget);
    expect(find.text('Descargas'), findsOneWidget);
  });
}
