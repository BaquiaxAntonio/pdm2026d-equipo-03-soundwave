import '../../core/models/song.dart';

// Lógica pura de filtrado por título y artista, sin widgets.
// Motivo: se prueba sin montar UI y la pantalla la reutiliza tal cual.
List<Song> filterSearchSongs(List<Song> songs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return songs;
  return songs
      .where(
        (s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q),
      )
      .toList();
}
