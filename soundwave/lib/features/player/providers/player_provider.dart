import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controller/local_playback_controller.dart';
import '../models/player_track.dart';

final playerControllerProvider =
    NotifierProvider<PlayerControllerNotifier, PlayerState>(
      PlayerControllerNotifier.new,
    );

class PlayerControllerNotifier extends Notifier<PlayerState> {
  LocalPlaybackController? _playback;

  @override
  PlayerState build() {
    ref.onDispose(() {
      _playback?.dispose();
      _playback = null;
    });
    return PlayerState.initial();
  }

  LocalPlaybackController get _controller {
    final existing = _playback;
    if (existing != null) return existing;
    final created = LocalPlaybackController()..load(state.tracks);
    _playback = created;
    return created;
  }

  void load(List<PlayerTrack> tracks, {int startIndex = 0}) {
    _playback?.dispose();
    final controller = LocalPlaybackController();
    _playback = controller;
    final next = state.copyWith(
      tracks: tracks,
      index: startIndex.clamp(0, tracks.isEmpty ? 0 : tracks.length - 1),
      controller: controller,
      position: Duration.zero,
      isPlaying: false,
    );
    state = next;
    controller.load(tracks);
  }

  Future<void> play() async {
    if (state.tracks.isEmpty) return;
    final controller = _controller;
    await controller.play();
    state = state.copyWith(controller: controller, isPlaying: true);
  }

  Future<void> pause() async {
    final controller = _controller;
    await controller.pause();
    state = state.copyWith(controller: controller, isPlaying: false);
  }

  Future<void> toggle() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> next() async {
    if (state.tracks.isEmpty) return;
    final nextIndex = (state.index + 1) % state.tracks.length;
    final controller = _controller;
    await controller.seekTo(nextIndex);
    state = state.copyWith(
      controller: controller,
      index: nextIndex,
      position: Duration.zero,
    );
  }

  Future<void> previous() async {
    if (state.tracks.isEmpty) return;
    final prevIndex =
        (state.index - 1 + state.tracks.length) % state.tracks.length;
    final controller = _controller;
    await controller.seekTo(prevIndex);
    state = state.copyWith(
      controller: controller,
      index: prevIndex,
      position: Duration.zero,
    );
  }

  Future<void> seek(Duration position) async {
    final controller = _controller;
    await controller.seek(position);
    state = state.copyWith(controller: controller, position: position);
  }

  PlayerTrack? get currentTrack =>
      state.tracks.isEmpty ? null : state.tracks[state.index];
}
