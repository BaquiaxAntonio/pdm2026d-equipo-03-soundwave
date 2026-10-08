import 'player_song_local.dart';

// Datos mock offline, sin internet ni anuncios.
// Motivo: permite validar issue #7 en modo avión.
const List<PlayerSongLocal> mockPlayerSongs = [
  PlayerSongLocal(
    id: 'p1',
    title: 'Estudio tranquilo',
    artist: 'SoundWave Mock',
    durationSeconds: 180,
  ),
  PlayerSongLocal(
    id: 'p2',
    title: 'Viaje en bus',
    artist: 'SoundWave Mock',
    durationSeconds: 210,
  ),
  PlayerSongLocal(
    id: 'p3',
    title: 'Tareas focus',
    artist: 'SoundWave Mock',
    durationSeconds: 150,
  ),
];
