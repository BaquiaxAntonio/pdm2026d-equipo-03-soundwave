import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/models/playlist.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/features/playlists/add_songs_sheet.dart';
import 'package:soundwave/features/playlists/playlist_providers.dart';

const viaje = Playlist(id: 'list-0', name: 'Viaje');

const primera = Song(
  id: 'demo:1',
  title: 'Primera',
  artist: 'Artista A',
  provider: 'demo',
  sourceId: '1',
);
const segunda = Song(
  id: 'demo:2',
  title: 'Segunda',
  artist: 'Artista B',
  provider: 'demo',
  sourceId: '2',
);
const tercera = Song(
  id: 'demo:3',
  title: 'Tercera',
  artist: 'Artista C',
  provider: 'demo',
  sourceId: '3',
);

void main() {
  late _CatalogRepository repository;

  setUp(() {
    repository = _CatalogRepository({
      'list-0': [primera],
    });
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playlistRepositoryProvider.overrideWith((ref) async => repository),
          catalogSongsProvider.overrideWith(
            (ref) async => const [primera, segunda, tercera],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showAddSongsSheet(context, viaje),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('añade una canción sin cerrar la hoja', (tester) async {
    await openSheet(tester);

    expect(find.text('Agregar a «Viaje»'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('Añadir Segunda'));
    await tester.pumpAndSettle();

    expect(
      repository.songs['list-0']!.map((song) => song.id),
      containsAll(<String>['demo:1', 'demo:2']),
    );
    expect(find.text('«Segunda» añadida a «Viaje».'), findsOneWidget);
    expect(find.text('Agregar a «Viaje»'), findsOneWidget);
    expect(find.byTooltip('Añadir Segunda'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
  });

  testWidgets('filtra el catálogo por título o artista', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'artista c');
    await tester.pumpAndSettle();
    expect(find.text('Tercera'), findsOneWidget);
    expect(find.text('Primera'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados para «zzz».'), findsOneWidget);
  });
}

class _CatalogRepository implements PlaylistRepository {
  _CatalogRepository(Map<String, List<Song>> seed)
    : songs = {
        for (final entry in seed.entries) entry.key: [...entry.value],
      };

  final Map<String, List<Song>> songs;

  @override
  Future<List<Song>> loadSongs(String playlistId) async =>
      List.unmodifiable(songs[playlistId] ?? const <Song>[]);

  @override
  Future<bool> addSong({required String playlistId, required Song song}) async {
    final list = songs.putIfAbsent(playlistId, () => []);
    if (list.any((item) => item.id == song.id)) return false;
    list.add(song);
    return true;
  }

  @override
  Future<List<PlaylistEntry>> loadPlaylists() async => const [];

  @override
  Future<Playlist> create(String name) => throw UnimplementedError();

  @override
  Future<void> rename({required String id, required String name}) =>
      throw UnimplementedError();

  @override
  Future<void> setArchived({required String id, required bool archived}) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) => throw UnimplementedError();

  @override
  Future<void> removeSong({
    required String playlistId,
    required String songId,
  }) => throw UnimplementedError();

  @override
  Future<void> setFavorite({required Song song, required bool favorite}) =>
      throw UnimplementedError();
}
