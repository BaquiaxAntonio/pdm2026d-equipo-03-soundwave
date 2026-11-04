import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/core/contracts/playlist_repository.dart';
import 'package:soundwave/core/models/playlist.dart';
import 'package:soundwave/core/models/song.dart';
import 'package:soundwave/core/providers/data_mode_provider.dart';
import 'package:soundwave/features/player/player_screen.dart';
import 'package:soundwave/features/player/providers/player_queue_provider.dart';
import 'package:soundwave/features/playlists/playlist_providers.dart';
import 'package:soundwave/features/playlists/playlist_screen.dart';

void main() {
  testWidgets('the player opens the Listas screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dataModeProvider.overrideWithValue(DataMode.localSqlite),
          playlistRepositoryProvider.overrideWith(
            (ref) async => _EmptyPlaylistRepository(),
          ),
          catalogSongsProvider.overrideWith((ref) async => const []),
          fullPlayerQueueProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: PlayerScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Listas'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistScreen), findsOneWidget);
    expect(find.text('Tus listas'), findsOneWidget);
  });
}

class _EmptyPlaylistRepository implements PlaylistRepository {
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
  Future<List<Song>> loadSongs(String playlistId) async => const [];

  @override
  Future<bool> addSong({required String playlistId, required Song song}) =>
      throw UnimplementedError();

  @override
  Future<void> removeSong({
    required String playlistId,
    required String songId,
  }) => throw UnimplementedError();

  @override
  Future<void> setFavorite({required Song song, required bool favorite}) =>
      throw UnimplementedError();
}
