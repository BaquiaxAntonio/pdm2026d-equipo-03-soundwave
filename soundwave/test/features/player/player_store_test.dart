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

  test('deshacer recupera por ID la canción pausada y su progreso', () {
    final store = createStore();
    addTearDown(store.dispose);
    store.next();
    store.seek(73);
    final snapshot = store.blockCurrent()!;
    store.next();

    expect(store.undoBlock(snapshot), isTrue);
    expect(store.currentSong, same(testSongs[1]));
    expect(store.progressSeconds, 73);
    expect(store.isPlaying, isFalse);
    expect(store.blockedIds, isNot(contains('p2')));
    expect(store.undoBlock(snapshot), isFalse);
  });

  test('deshacer la última bloqueada recupera la reproducción y el tiempo', () {
    final store = PlayerStore(songs: [testSongs.first]);
    addTearDown(store.dispose);
    store.seek(42);
    store.play();
    final snapshot = store.blockCurrent()!;

    expect(store.currentSong, isNull);
    expect(store.isPlaying, isFalse);
    expect(store.undoBlock(snapshot), isTrue);
    expect(store.currentSong?.id, 'p1');
    expect(store.progressSeconds, 42);
    expect(store.isPlaying, isTrue);
  });

  test('deshacer no reinserta una canción quitada de la cola', () {
    final songs = List.of(testSongs);
    final store = PlayerStore(songs: songs);
    addTearDown(store.dispose);
    final snapshot = store.blockCurrent()!;
    songs.removeWhere((song) => song.id == snapshot.songId);

    expect(store.undoBlock(snapshot), isFalse);
    expect(
      store.playableSongs.any((song) => song.id == snapshot.songId),
      isFalse,
    );
  });
}
