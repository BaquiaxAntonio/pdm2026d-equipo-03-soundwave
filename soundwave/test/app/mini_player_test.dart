import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundwave/app/mini_player.dart';
import 'package:soundwave/app/navigation_provider.dart';
import 'package:soundwave/features/player/providers/player_from_downloads_provider.dart';
import 'package:soundwave/features/player/providers/player_provider.dart';

import '../features/player/fake_playback_controller.dart';
import '../support/fake_repositories.dart';

void main() {
  testWidgets('el mini reproductor muestra y controla la canción actual', (
    tester,
  ) async {
    final engine = FakePlaybackController();
    final container = ProviderContainer(
      overrides: [
        playerFromDownloadsProvider.overrideWith((_) {}),
        playbackEngineProvider.overrideWithValue(engine),
        playbackPreferencesProvider.overrideWith(
          (_) async => FakePlaybackPreferencesRepository(),
        ),
        playbackSourceProvider.overrideWithValue(
          (track) async => Uri.file('/private/${track.localPath}'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(playerControllerProvider.notifier);
    await controller.load(testTracks);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(bottomNavigationBar: MiniPlayer()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Primera'), findsOneWidget);
    expect(find.byTooltip('Reproducir'), findsOneWidget);

    await tester.tap(find.byTooltip('Reproducir'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pausar'), findsOneWidget);

    await tester.tap(find.byTooltip('Siguiente canción'));
    await tester.pumpAndSettle();
    expect(controller.currentTrack?.id, testTracks.last.id);

    await tester.tap(find.text('Segunda'));
    await tester.pumpAndSettle();
    expect(container.read(activeTabProvider), AppTab.player);
  });
}
