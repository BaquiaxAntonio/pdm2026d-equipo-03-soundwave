import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download_status.dart';
import 'mock_download_data.dart';

// Sin autoDispose: sobrevive al desmontaje de DownloadScreen mientras viva
// el ProviderScope raíz. Un reinicio de la app vuelve a cargar los mocks.
final downloadStoreProvider =
    NotifierProvider<DownloadStore, List<DownloadStatus>>(DownloadStore.new);

class DownloadStore extends Notifier<List<DownloadStatus>> {
  @override
  List<DownloadStatus> build() => List.unmodifiable(mockDownloads);

  void remove(String id) {
    state = List.unmodifiable(state.where((song) => song.id != id));
  }

  /// Recupera un registro eliminado sin duplicarlo, en el orden de los mocks.
  void restore(DownloadStatus song) {
    if (state.any((item) => item.id == song.id)) return;
    final order = {
      for (var i = 0; i < mockDownloads.length; i++) mockDownloads[i].id: i,
    };
    final restored = [...state, song]
      ..sort(
        (a, b) => (order[a.id] ?? order.length).compareTo(
          order[b.id] ?? order.length,
        ),
      );
    state = List.unmodifiable(restored);
  }

  void resetDemo() => state = List.unmodifiable(mockDownloads);
}
