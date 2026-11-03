import 'player_track.dart';

class PlayerState {
  const PlayerState({
    this.tracks = const [],
    this.blockedIds = const {},
    this.index = 0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.isLoading = false,
    this.error,
  });

  final List<PlayerTrack> tracks;
  final Set<String> blockedIds;
  final int index;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final bool isLoading;
  final String? error;

  PlayerTrack? get currentTrack => tracks.isEmpty ? null : tracks[index];
  List<PlayerTrack> get playableTracks =>
      tracks.where((t) => !blockedIds.contains(t.id)).toList();

  PlayerState copyWith({
    List<PlayerTrack>? tracks,
    Set<String>? blockedIds,
    int? index,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => PlayerState(
    tracks: tracks == null ? this.tracks : List.unmodifiable(tracks),
    blockedIds: blockedIds == null
        ? this.blockedIds
        : Set.unmodifiable(blockedIds),
    index: index ?? this.index,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    isPlaying: isPlaying ?? this.isPlaying,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
  );
}
