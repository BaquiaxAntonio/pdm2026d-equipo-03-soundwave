// Modelo Song local y mínimo, solo para features/player.
// Motivo: independencia en Fase 1, no depende de search/downloads.
// Se unificará en core/models/ en la Fase 2 (issue #11).
class PlayerSongLocal {
  final String id;
  final String title;
  final String artist;
  final int durationSeconds;

  const PlayerSongLocal({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
  });
}
