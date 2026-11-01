import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/download_record.dart';
import '../../core/models/song.dart';
import '../../core/providers/data_mode_provider.dart';
import '../downloads/download_providers.dart';
import '../search/mock_search_data.dart';

/// Songs shown by Inicio.
///
/// On Android it reads the shared library (completed downloads) from the same
/// repository used by Descargas, Buscar and the Reproductor. The demo target
/// uses the shared demo catalog of Buscar, so Inicio never keeps its own
/// fixture and a song tapped here is the same song everywhere else.
final homeSongsProvider = FutureProvider<List<Song>>((ref) async {
  if (ref.watch(dataModeProvider) == DataMode.demo) {
    return mockSearchSongs;
  }
  final entries = await ref.watch(downloadEntriesProvider.future);
  return List.unmodifiable([
    for (final entry in entries)
      if (entry.record.state == DownloadState.completed &&
          entry.record.localPath != null &&
          entry.song != null)
        entry.song!,
  ]);
});
