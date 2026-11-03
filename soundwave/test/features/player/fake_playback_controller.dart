import 'dart:async';
import 'package:soundwave/core/contracts/playback_controller.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/player/models/player_track.dart';

const testTracks = [
  PlayerTrack(
    song: Song(
      id: 'commons:1',
      title: 'Primera',
      artist: 'Artista',
      provider: 'commons',
      sourceId: '1',
    ),
    localPath: 'first.ogg',
  ),
  PlayerTrack(
    song: Song(
      id: 'commons:2',
      title: 'Segunda',
      artist: 'Artista',
      provider: 'commons',
      sourceId: '2',
    ),
    localPath: 'second.wav',
  ),
];

class FakePlaybackController implements PlaybackController {
  final _events = StreamController<PlaybackEvent>.broadcast(sync: true);
  final loaded = <Uri>[];
  bool playing = false;
  bool failLoad = false;
  int stops = 0;
  bool disposed = false;
  Completer<void>? stopGate;
  Completer<void>? loadGate;
  Duration position = Duration.zero;

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  void emit({bool completed = false, String? error}) {
    _events.add(
      PlaybackEvent(
        position: position,
        duration: const Duration(minutes: 4),
        isPlaying: playing,
        completed: completed,
        error: error,
      ),
    );
  }

  @override
  Future<void> load(Uri uri) async {
    if (failLoad) throw StateError('El archivo descargado ya no existe.');
    await loadGate?.future;
    loaded.add(uri);
    position = Duration.zero;
    playing = false;
    emit();
  }

  @override
  Future<void> play() async {
    playing = true;
    emit();
  }

  @override
  Future<void> pause() async {
    playing = false;
    emit();
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    emit();
  }

  @override
  Future<void> stop() async {
    await stopGate?.future;
    stops++;
    playing = false;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _events.close();
  }
}
