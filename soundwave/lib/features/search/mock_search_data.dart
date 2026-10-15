import 'search_song_local.dart';

// Mocks locales para sugerencias y búsqueda inmediata, sin red.
// Motivo: permite validar la pantalla sin depender de otros features.
const List<SearchSongLocal> mockSearchSongs = [
  SearchSongLocal(
    id: 'song-001',
    title: 'Neon Horizon',
    artist: 'Luna Vega',
    durationSeconds: 224,
  ),
  SearchSongLocal(
    id: 'song-002',
    title: 'Midnight Echo',
    artist: 'Atlas Bloom',
    durationSeconds: 198,
  ),
  SearchSongLocal(
    id: 'song-003',
    title: 'Ocean Letters',
    artist: 'Marina Sol',
    durationSeconds: 251,
  ),
  SearchSongLocal(
    id: 'song-004',
    title: 'Paper Satellites',
    artist: 'Theo North',
    durationSeconds: 187,
  ),
  SearchSongLocal(
    id: 'song-005',
    title: 'City in Reverse',
    artist: 'Velvet Roads',
    durationSeconds: 236,
  ),
  SearchSongLocal(
    id: 'song-006',
    title: 'Quiet Thunder',
    artist: 'Nova Lane',
    durationSeconds: 209,
  ),
  SearchSongLocal(
    id: 'song-007',
    title: 'Afterglow Avenue',
    artist: 'Iris Vale',
    durationSeconds: 245,
  ),
  SearchSongLocal(
    id: 'song-008',
    title: 'Copper Skies',
    artist: 'Milo Dawn',
    durationSeconds: 193,
  ),
  SearchSongLocal(
    id: 'song-009',
    title: 'Dancing Comets',
    artist: 'Aurora Field',
    durationSeconds: 218,
  ),
  SearchSongLocal(
    id: 'song-010',
    title: 'Last Train Home',
    artist: 'Echo Harbor',
    durationSeconds: 262,
  ),
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
