import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:soundwave/core/models/song.dart';
import 'data/mock_songs.dart' hide Song;

/// Provider que simula un repositorio asíncrono para la pantalla Home.
/// En producción real, esto consultaría la API o base de datos local.
final homeSongsProvider = FutureProvider<List<Song>>((ref) async {
  // Simular latencia de red
  await Future.delayed(const Duration(milliseconds: 800));

  // Combinar todas las canciones mock
  final allSongs = <Song>[
    ...recentSongs.map((s) => Song(
          id: 'mock:${s.title.replaceAll(' ', '-').toLowerCase()}',
          title: s.title,
          artist: s.artist,
          provider: 'mock',
          sourceId: s.title.toLowerCase().replaceAll(' ', '-'),
          durationMs: _parseDuration(s.duration),
        )),
    ...favoriteSongs.map((s) => Song(
          id: 'mock:${s.title.replaceAll(' ', '-').toLowerCase()}',
          title: s.title,
          artist: s.artist,
          provider: 'mock',
          sourceId: s.title.toLowerCase().replaceAll(' ', '-'),
          durationMs: _parseDuration(s.duration),
        )),
    ...recommendedSongs.map((s) => Song(
          id: 'mock:${s.title.replaceAll(' ', '-').toLowerCase()}',
          title: s.title,
          artist: s.artist,
          provider: 'mock',
          sourceId: s.title.toLowerCase().replaceAll(' ', '-'),
          durationMs: _parseDuration(s.duration),
        )),
  ];

  return allSongs;
});

int? _parseDuration(String duration) {
  final parts = duration.split(':');
  if (parts.length != 2) return null;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return null;
  return (minutes * 60 + seconds) * 1000;
}

/// Provider para forzar error en pruebas (se usa con override en tests)
final homeSongsErrorProvider = FutureProvider<List<Song>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  throw Exception('No se pudo cargar el catálogo. Verifica tu conexión.');
});