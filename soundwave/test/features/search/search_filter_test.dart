import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/search/mock_search_data.dart';
import 'package:soundwave/features/search/search_filter_local.dart';

// Conserva las comprobaciones de comportamiento de búsqueda
// tras el cambio de interfaz: filtrado por título y artista.
void main() {
  test('consulta vacía devuelve sugerencias completas', () {
    expect(filterSearchSongs(mockSearchSongs, ''), mockSearchSongs);
    expect(filterSearchSongs(mockSearchSongs, '   '), mockSearchSongs);
  });

  test('filtra por título sin distinguir mayúsculas', () {
    final results = filterSearchSongs(mockSearchSongs, 'NOCHE');
    expect(results.map((s) => s.id), ['s4']);
  });

  test('filtra por artista', () {
    final results = filterSearchSongs(mockSearchSongs, 'campus');
    expect(results.map((s) => s.id), ['s2', 's5']);
  });

  test('sin coincidencias devuelve lista vacía', () {
    expect(filterSearchSongs(mockSearchSongs, 'xyz-nada'), isEmpty);
  });
}
