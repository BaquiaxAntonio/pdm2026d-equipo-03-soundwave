import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/features/player/player_song_local.dart';
import 'package:soundwave/features/player/player_store.dart';

const testSongs = [
  PlayerSongLocal(
    id: 'p1',
    title: 'Estudio tranquilo',
    artist: 'SoundWave Mock',
    durationSeconds: 180,
  ),
  PlayerSongLocal(
    id: 'p2',
    title: 'Viaje en bus',
    artist: 'SoundWave Mock',
    durationSeconds: 210,
  ),
  PlayerSongLocal(
    id: 'p3',
    title: 'Tareas focus',
    artist: 'SoundWave Mock',
    durationSeconds: 150,
  ),
];

PlayerStore createStore() => PlayerStore(songs: List.of(testSongs));

void main() {
  test('blockCurrent oculta la canción en la sesión (issue #8)', () {
    final store = createStore();
    addTearDown(store.dispose);

    final blockedId = store.currentSong!.id;
    store.blockCurrent();

    expect(store.blockedIds, contains(blockedId));
    expect(store.playableSongs.any((s) => s.id == blockedId), isFalse);
  });

  test('next/previous saltan bloqueadas (issue #8)', () {
    final store = createStore();
    addTearDown(store.dispose);

    // Bloquea p1, la actual debe pasar a p2.
    expect(store.currentSong!.id, 'p1');
    store.blockCurrent();
    expect(store.currentSong!.id, 'p2');

    store.next();
    expect(store.currentSong!.id, 'p3');

    store.next();
    expect(store.currentSong!.id, 'p2');
  });

  test('todo bloqueado deja currentSong en null (issue #8)', () {
    final store = createStore();
    addTearDown(store.dispose);

    store.blockCurrent();
    store.blockCurrent();
    store.blockCurrent();

    expect(store.playableSongs, isEmpty);
    expect(store.currentSong, isNull);
  });

  test('toggle cambia isPlaying sin internet (issue #7 mock)', () {
    final store = createStore();
    addTearDown(store.dispose);

    expect(store.isPlaying, isFalse);
    store.toggle();
    expect(store.isPlaying, isTrue);
    store.toggle();
    expect(store.isPlaying, isFalse);
  });
}
