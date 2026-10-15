import 'search_song_local.dart';

// Mocks locales para sugerencias y búsqueda inmediata, sin red.
// Motivo: permite validar la pantalla sin depender de otros features.
const List<SearchSongLocal> mockSearchSongs = [
  SearchSongLocal(
    id: 's1',
    title: 'Estudio tranquilo',
    artist: 'SoundWave Mock',
    durationSeconds: 180,
  ),
  SearchSongLocal(
    id: 's2',
    title: 'Viaje en bus bajo la lluvia de ideas interminables',
    artist: 'Sonidos del Campus',
    durationSeconds: 210,
  ),
  SearchSongLocal(
    id: 's3',
    title: 'Tareas focus',
    artist: 'SoundWave Mock',
    durationSeconds: 150,
  ),
  SearchSongLocal(
    id: 's4',
    title: 'Noche de código',
    artist: 'Los Compiladores',
    durationSeconds: 244,
  ),
  SearchSongLocal(
    id: 's5',
    title: 'Café y apuntes',
    artist: 'Sonidos del Campus',
    durationSeconds: 197,
  ),
];
