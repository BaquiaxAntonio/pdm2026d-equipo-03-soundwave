import 'dart:async';

import 'package:just_audio/just_audio.dart' hide PlaybackEvent;

import '../../../core/contracts/playback_controller.dart';
export '../../../core/contracts/playback_controller.dart';

/// One decoder, owned by the root Riverpod provider, never by a screen.
class LocalPlaybackController implements PlaybackController {
  final AudioPlayer _player = AudioPlayer(
    userAgent:
        'SoundWave-Academic/0.1 '
        '(https://github.com/BaquiaxAntonio/pdm2026d-equipo-03-soundwave)',
    useProxyForRequestHeaders: false,
  );
  final _events = StreamController<PlaybackEvent>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;

  LocalPlaybackController() {
    _subscriptions.addAll([
      _player.positionStream.listen((_) => _emit()),
      _player.durationStream.listen((_) => _emit()),
      _player.playerStateStream.listen((_) => _emit()),
      _player.errorStream.listen(
        (_) => _emit(
          error:
              'No se pudo leer el audio. Comprueba el archivo o la conexión.',
        ),
      ),
    ]);
  }

  @override
  Stream<PlaybackEvent> get events => _events.stream;

  void _emit({String? error}) {
    if (_disposed) return;
    final processing = _player.processingState;
    _events.add(
      PlaybackEvent(
        position: _player.position,
        duration: _player.duration ?? Duration.zero,
        isPlaying: _player.playing && processing != ProcessingState.completed,
        isLoading:
            processing == ProcessingState.loading ||
            processing == ProcessingState.buffering,
        completed: processing == ProcessingState.completed,
        error: error,
      ),
    );
  }

  @override
  Future<void> load(Uri uri) async {
    await _player.setAudioSource(AudioSource.uri(uri));
  }

  @override
  Future<void> play() async {
    // just_audio's play future completes at pause/end, not at playback start.
    unawaited(
      _player.play().catchError((Object _) {
        _emit(error: 'No se pudo reproducir el audio. Intenta de nuevo.');
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _events.close();
  }
}
