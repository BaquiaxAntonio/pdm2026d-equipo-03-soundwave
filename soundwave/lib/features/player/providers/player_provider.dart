import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/playback_preferences_repository.dart';
import '../../../core/database/dao_providers.dart';
import '../../../core/models/song.dart';
import '../../../core/models/download_record.dart';
import '../../../core/providers/data_mode_provider.dart';
import '../../downloads/download_providers.dart';
import '../../search/data/commons_api_client.dart';
import '../../search/data/commons_catalog_repository.dart';
import '../controller/local_playback_controller.dart';
import '../data/playback_preferences_repository_impl.dart';
import '../models/player_state.dart';
import '../models/player_track.dart';
export '../models/player_state.dart';

final playbackEngineProvider = Provider<PlaybackController>(
  (ref) => LocalPlaybackController(),
);

final playbackPreferencesProvider =
    FutureProvider<PlaybackPreferencesRepository?>((ref) async {
      if (ref.watch(dataModeProvider) == DataMode.demo) return null;
      return SqlitePlaybackPreferencesRepository(
        await ref.watch(blockedSongDaoProvider.future),
      );
    });

final playbackSourceProvider = Provider<Future<Uri> Function(PlayerTrack)>((
  ref,
) {
  return (track) async {
    if (track.localPath != null) {
      final session = await ref.read(downloadSessionProvider.future);
      if (session?.localAudioUri == null) {
        throw StateError('No se pudo abrir la biblioteca local.');
      }
      return session!.localAudioUri!(track.localPath!);
    }
    final resolution = await CommonsAudioResolver(
      ref.read(commonsApiClientProvider),
    ).resolve(track.song);
    return resolution.uri;
  };
});

final playerControllerProvider =
    NotifierProvider<PlayerControllerNotifier, PlayerState>(
      PlayerControllerNotifier.new,
    );

class PlayerControllerNotifier extends Notifier<PlayerState> {
  PlaybackController? _engine;
  bool _acceptEvents = false;
  bool _completed = false;
  bool _loaded = false;
  Future<void> _pending = Future.value();

  @override
  PlayerState build() {
    ref.onDispose(() {
      final engine = _engine;
      if (engine != null) unawaited(engine.dispose());
    });
    return const PlayerState();
  }

  PlaybackController get _controller {
    if (_engine != null) return _engine!;
    final engine = ref.read(playbackEngineProvider);
    final subscription = engine.events.listen(_onEvent);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return _engine = engine;
  }

  void _onEvent(PlaybackEvent event) {
    if (!ref.mounted || !_acceptEvents) return;
    if (event.error != null) {
      unawaited(
        _run(() async {
          throw StateError(event.error!);
        }),
      );
      return;
    }
    state = state.copyWith(
      position: event.position,
      duration: event.duration,
      isPlaying: event.isPlaying,
      isLoading: event.isLoading,
      error: event.error,
    );
    if (event.completed && !_completed) {
      _completed = true;
      unawaited(
        _run(() async {
          final playable = state.playableTracks;
          final index = playable.indexWhere((t) => t.id == currentTrack?.id);
          if (index >= 0 && index + 1 < playable.length) {
            await _select(playable[index + 1].id, autoplay: true);
          } else {
            await _engine?.pause();
            state = state.copyWith(isPlaying: false);
          }
        }),
      );
    }
  }

  // Serialize source changes, download refreshes and deletion: no stale load may
  // reopen an audio file after the deletion guard has released it.
  Future<void> _run(Future<void> Function() action) {
    final result = _pending.then((_) async {
      if (!ref.mounted) return;
      try {
        await action();
      } catch (error) {
        if (!ref.mounted) return;
        _acceptEvents = false;
        _loaded = false;
        try {
          await _engine?.stop();
        } catch (_) {
          // A failed release never grants deletion; a later action can retry.
        }
        if (ref.mounted) {
          state = state.copyWith(
            isPlaying: false,
            isLoading: false,
            error: _message(error),
          );
        }
      }
    });
    _pending = result;
    return result;
  }

  String _message(Object error) {
    if (error is CommonsAudioResolutionException) return error.message;
    if (error is CommonsApiException) {
      return 'No se pudo consultar Commons. Comprueba tu conexión e intenta de nuevo.';
    }
    if (error is StateError) return error.message.toString();
    return 'No se pudo reproducir el audio. El archivo puede faltar o estar dañado.';
  }

  PlayerTrack? get currentTrack => state.currentTrack;

  Future<void> _readBlocks() async {
    final repository = await ref.read(playbackPreferencesProvider.future);
    final ids = await repository?.blockedSongIds('offline') ?? <String>{};
    if (ref.mounted) state = state.copyWith(blockedIds: ids);
  }

  Future<void> load(List<PlayerTrack> tracks, {int startIndex = 0}) => _run(
    () async {
      await _readBlocks();
      if (!ref.mounted) return;
      final old = currentTrack;
      // Keep an explicitly selected online song alongside the offline library.
      final merged = [...tracks];
      if (old != null &&
          old.localPath == null &&
          !merged.any((t) => t.id == old.id)) {
        merged.insert(0, old);
      }
      final preserved = merged.indexWhere((t) => t.id == old?.id);
      if (preserved < 0 && _loaded) await _stop();
      state = state.copyWith(
        tracks: merged,
        index: preserved >= 0
            ? preserved
            : (merged.isEmpty ? 0 : startIndex.clamp(0, merged.length - 1)),
      );
      if (currentTrack != null && state.blockedIds.contains(currentTrack!.id)) {
        await _stop();
        final playable = state.playableTracks;
        if (playable.isNotEmpty) {
          state = state.copyWith(index: state.tracks.indexOf(playable.first));
        } else {
          await _stop();
        }
      }
    },
  );

  Future<void> openSong(Song song) => _run(() async {
    await _readBlocks();
    if (!state.tracks.any((t) => t.id == song.id)) {
      state = state.copyWith(
        tracks: [
          ...state.tracks,
          PlayerTrack(song: song, localPath: null),
        ],
      );
    }
    await _select(song.id, autoplay: true);
  });

  Future<void> openById(String songId) => _run(() async {
    if (ref.read(dataModeProvider) == DataMode.demo) {
      throw StateError('La reproducción real está disponible en Android.');
    }
    await _readBlocks();
    // A tap can arrive before the downloads stream's first snapshot. Query the
    // record as well, so a downloaded song never needs the network to open.
    final session = await ref.read(downloadSessionProvider.future);
    final record = await session?.repository.findBySongId(songId);
    if (record?.state == DownloadState.pendingDeletion) {
      throw StateError(
        'Restaura esta canción desde Descargas antes de reproducirla.',
      );
    }
    if (record?.state == DownloadState.completed && record?.localPath != null) {
      final song = await session!.findSong(songId);
      if (song != null) {
        final local = PlayerTrack.fromDownload(song, record!);
        final tracks = [...state.tracks];
        final index = tracks.indexWhere((t) => t.id == songId);
        if (index < 0) {
          tracks.add(local);
        } else {
          tracks[index] = local;
        }
        state = state.copyWith(tracks: tracks);
      }
    }
    if (!state.tracks.any((t) => t.id == songId)) {
      final catalog = await ref.read(commonsCatalogRepositoryProvider.future);
      final song = await catalog.findById(songId);
      if (song == null) {
        throw StateError('No se encontró la canción seleccionada.');
      }
      state = state.copyWith(
        tracks: [
          ...state.tracks,
          PlayerTrack(song: song, localPath: null),
        ],
      );
    }
    await _select(songId, autoplay: true);
  });

  Future<void> select(String songId) =>
      _run(() => _select(songId, autoplay: true));

  Future<void> _select(String songId, {required bool autoplay}) async {
    final index = state.tracks.indexWhere((t) => t.id == songId);
    if (index < 0) {
      throw StateError('La canción ya no está disponible en la cola.');
    }
    if (state.blockedIds.contains(songId)) {
      throw StateError(
        'Esta canción está bloqueada. Desbloquéala para reproducirla.',
      );
    }
    await _stop();
    state = state.copyWith(
      index: index,
      position: Duration.zero,
      duration: Duration.zero,
      isLoading: true,
      clearError: true,
    );
    final uri = await ref.read(playbackSourceProvider)(state.tracks[index]);
    if (!ref.mounted) return;
    _completed = false;
    _acceptEvents = true;
    await _controller.load(uri);
    if (!ref.mounted) return;
    _loaded = true;
    state = state.copyWith(isLoading: false);
    if (autoplay) await _controller.play();
  }

  Future<void> _stop() async {
    _acceptEvents = false;
    _loaded = false;
    await _engine?.stop();
    if (ref.mounted) {
      state = state.copyWith(
        isPlaying: false,
        isLoading: false,
        position: Duration.zero,
        duration: Duration.zero,
      );
    }
  }

  Future<void> play() => _run(() async {
    final track = currentTrack;
    if (track == null) return;
    if (!_loaded || state.error != null) {
      await _select(track.id, autoplay: true);
    } else {
      if (_completed) {
        _completed = false;
        await _controller.seek(Duration.zero);
      }
      await _controller.play();
    }
  });

  Future<void> pause() => _run(() async {
    await _engine?.pause();
  });
  Future<void> toggle() => state.isPlaying ? pause() : play();
  Future<void> stop() => _run(_stop);
  Future<void> next() => _move(1);
  Future<void> previous() => _move(-1);

  Future<void> _move(int offset) => _run(() async {
    final tracks = state.playableTracks;
    if (tracks.isEmpty) return;
    final current = tracks.indexWhere((t) => t.id == currentTrack?.id);
    final next = (current + offset) % tracks.length;
    await _select(tracks[next].id, autoplay: state.isPlaying);
  });

  Future<void> seek(Duration position) => _run(() async {
    if (!_loaded || state.duration == Duration.zero) return;
    final target = Duration(
      milliseconds: position.inMilliseconds.clamp(
        0,
        state.duration.inMilliseconds,
      ),
    );
    _completed = false;
    await _controller.seek(target);
  });

  Future<void> setBlocked(String songId, bool blocked) => _run(() async {
    final track = state.tracks.where((t) => t.id == songId).firstOrNull;
    if (track?.localPath == null) {
      throw StateError(
        'Descarga la canción antes de bloquearla en tu biblioteca offline.',
      );
    }
    final repository = await ref.read(playbackPreferencesProvider.future);
    if (repository == null) {
      throw StateError(
        'El bloqueo persistente requiere la biblioteca Android.',
      );
    }
    await repository.setBlocked(
      collectionId: 'offline',
      songId: songId,
      blocked: blocked,
    );
    state = state.copyWith(
      blockedIds: {...state.blockedIds}
        ..remove(songId)
        ..addAll(blocked ? [songId] : []),
    );
    if (blocked && currentTrack?.id == songId) {
      final playing = state.isPlaying;
      await _stop();
      final playable = state.playableTracks;
      if (playable.isNotEmpty) {
        await _select(playable.first.id, autoplay: playing);
      }
    }
  });

  Future<bool> releaseForDeletion(String songId) async {
    // Startup recovery can call the guard before DownloadSession is ready.
    // With no decoder and no queued track there is no file to release.
    if (_engine == null && !state.tracks.any((t) => t.id == songId)) {
      return true;
    }
    var released = false;
    await _run(() async {
      if (currentTrack?.id == songId) await _stop();
      final id = currentTrack?.id;
      final remaining = state.tracks.where((t) => t.id != songId).toList();
      final index = remaining.indexWhere((t) => t.id == id);
      state = state.copyWith(tracks: remaining, index: index < 0 ? 0 : index);
      released = true;
    });
    return released;
  }
}
