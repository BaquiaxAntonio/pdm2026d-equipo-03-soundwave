import '../../core/models/song.dart';

// Mocks locales para sugerencias y búsqueda inmediata, sin red.
// Motivo: permite validar la pantalla sin depender de otros features.
const List<Song> mockSearchSongs = [
  Song(
    id: 'demo:s1',
    title: 'Estudio tranquilo',
    artist: 'SoundWave Mock',
    durationMs: 180000,
    provider: 'demo',
    sourceId: 's1',
  ),
  Song(
    id: 'demo:s2',
    title: 'Viaje en bus bajo la lluvia de ideas interminables',
    artist: 'Sonidos del Campus',
    durationMs: 210000,
    provider: 'demo',
    sourceId: 's2',
  ),
  Song(
    id: 'demo:s3',
    title: 'Tareas focus',
    artist: 'SoundWave Mock',
    durationMs: 150000,
    provider: 'demo',
    sourceId: 's3',
  ),
  Song(
    id: 'demo:s4',
    title: 'Noche de código',
    artist: 'Los Compiladores',
    durationMs: 244000,
    provider: 'demo',
    sourceId: 's4',
  ),
  Song(
    id: 'demo:s5',
    title: 'Café y apuntes',
    artist: 'Sonidos del Campus',
    durationMs: 197000,
    provider: 'demo',
    sourceId: 's5',
  ),
];
