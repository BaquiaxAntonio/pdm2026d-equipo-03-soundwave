import 'dart:async';
import '../models/player_track.dart';

abstract class PlaybackController {
  Future<void> load(List<PlayerTrack> tracks);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> seekTo(int index);
  Stream<PlaybackEvent> get events;
  void dispose();
}

class PlaybackEvent {
  const PlaybackEvent({
    required this.position,
    required this.duration,
    required this.isPlaying,
    this.index,
    this.error,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final int? index;
  final String? error;
}

class LocalPlaybackController implements PlaybackController {
  final _controller = StreamController<PlaybackEvent>.broadcast();
  List<PlayerTrack> _tracks = const [];
  int _index = 0;
  bool _playing = false;
  Duration _position = Duration.zero;
  Timer? _timer;

  @override
  Future<void> load(List<PlayerTrack> tracks) async {
    _tracks = tracks;
    _index = 0;
    _position = Duration.zero;
    _emit();
  }

  @override
  Future<void> play() async {
    if (_tracks.isEmpty) return;
    _playing = true;
    _startTimer();
    _emit();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _timer?.cancel();
    _emit();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _timer?.cancel();
    _position = Duration.zero;
    _emit();
  }

  @override
  Future<void> seek(Duration position) async {
    final track = _currentTrack;
    if (track == null) return;
    if (position < Duration.zero) {
      _position = Duration.zero;
    } else if (position > track.duration) {
      _position = track.duration;
    } else {
      _position = position;
    }
    _emit();
  }

  @override
  Future<void> seekTo(int index) async {
    if (_tracks.isEmpty) return;
    _index = index.clamp(0, _tracks.length - 1);
    _position = Duration.zero;
    _emit();
  }

  @override
  Stream<PlaybackEvent> get events => _controller.stream;

  PlayerTrack? get _currentTrack => _tracks.isEmpty ? null : _tracks[_index];

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_playing) return;
      final track = _currentTrack;
      if (track == null) return;
      _position += const Duration(milliseconds: 500);
      if (_position >= track.duration) {
        _position = track.duration;
        _playing = false;
        _timer?.cancel();
      }
      _emit();
    });
  }

  void _emit() {
    final track = _currentTrack;
    _controller.add(
      PlaybackEvent(
        position: _position,
        duration: track?.duration ?? Duration.zero,
        isPlaying: _playing,
        index: _tracks.isEmpty ? null : _index,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

class PlayerState {
  const PlayerState({
    required this.tracks,
    required this.index,
    required this.position,
    required this.isPlaying,
    this.controller,
  });

  final List<PlayerTrack> tracks;
  final int index;
  final Duration position;
  final bool isPlaying;
  final LocalPlaybackController? controller;

  factory PlayerState.initial() => const PlayerState(
    tracks: [],
    index: 0,
    position: Duration.zero,
    isPlaying: false,
  );

  PlayerState copyWith({
    List<PlayerTrack>? tracks,
    int? index,
    Duration? position,
    bool? isPlaying,
    LocalPlaybackController? controller,
  }) {
    return PlayerState(
      tracks: tracks ?? this.tracks,
      index: index ?? this.index,
      position: position ?? this.position,
      isPlaying: isPlaying ?? this.isPlaying,
      controller: controller ?? this.controller,
    );
  }

  PlayerState stop() {
    controller?.stop();
    return copyWith(isPlaying: false, position: Duration.zero);
  }
}
