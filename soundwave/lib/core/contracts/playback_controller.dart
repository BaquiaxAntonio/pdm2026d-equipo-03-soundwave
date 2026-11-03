abstract interface class PlaybackController {
  Stream<PlaybackEvent> get events;
  Future<void> load(Uri uri);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class PlaybackEvent {
  const PlaybackEvent({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.completed = false,
    this.error,
  });

  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final bool completed;
  final String? error;
}
