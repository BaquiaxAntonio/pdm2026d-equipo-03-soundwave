// Modelo Song local y mínimo, solo para features/search.
// Motivo: independencia en Fase 1; no depende de player/downloads/core.
// Se unificará en core/models/ en la Fase 2 (issue #11).
class SearchSongLocal {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;

  const SearchSongLocal({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
  });

  /// Duración en formato m:ss para la fila de resultados.
  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
