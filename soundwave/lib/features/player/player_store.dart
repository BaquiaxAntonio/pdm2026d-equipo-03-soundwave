import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mock_player_data.dart';
import 'player_song_local.dart';

// Estado in-memory solo para player, sin dependencias externas.
// Motivo: persistencia en sesión sin esperar al estado global (issue #9).
class PlayerStore extends ChangeNotifier {
  PlayerStore({List<PlayerSongLocal>? songs}) : _songs = songs ?? mockPlayerSongs;

  final List<PlayerSongLocal> _songs;
  final Set<String> blockedIds = {};
  int _index = 0;
  bool isPlaying = false;
  int progressSeconds = 0;
  Timer? _timer;

  PlayerSongLocal? get currentSong {
    final list = playableSongs;
    if (list.isEmpty) return null;
    return list[_index % list.length];
  }

  List<PlayerSongLocal> get playableSongs =>
      _songs.where((s) => !blockedIds.contains(s.id)).toList();

  void play() {
    if (currentSong == null) return;
    isPlaying = true;
    _startTimer();
    notifyListeners();
  }

  void pause() {
    isPlaying = false;
    _timer?.cancel();
    notifyListeners();
  }

  void toggle() {
    if (isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void next() {
    final list = playableSongs;
    if (list.isEmpty) return;
    _index = (_index + 1) % list.length;
    progressSeconds = 0;
    notifyListeners();
  }

  void previous() {
    final list = playableSongs;
    if (list.isEmpty) return;
    _index = (_index - 1 + list.length) % list.length;
    progressSeconds = 0;
    notifyListeners();
  }

  // Issue #8: la bloqueada no vuelve a sonar en la sesión.
  void blockCurrent() {
    final song = currentSong;
    if (song == null) return;
    blockedIds.add(song.id);
    progressSeconds = 0;
    if (_index >= playableSongs.length) _index = 0;
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final song = currentSong;
      if (song == null || !isPlaying) return;
      if (progressSeconds >= song.durationSeconds) {
        next();
      } else {
        progressSeconds++;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
