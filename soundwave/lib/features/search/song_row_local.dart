import 'package:flutter/material.dart';

import 'cover_placeholder_local.dart';
import 'search_song_local.dart';
import 'search_theme_local.dart';

// Fila limpia sin tarjeta: portada + centro flexible + duración.
// Motivo: evita tarjeta-dentro-de-tarjeta y desbordes con títulos largos
// o texto ampliado (Expanded + ellipsis). Sin onTap ni efecto ripple
// porque la fila no reproduce ni navega todavía.
class SongRowLocal extends StatelessWidget {
  final SearchSongLocal song;

  const SongRowLocal({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: SearchThemeLocal.space16,
        vertical: SearchThemeLocal.space8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CoverPlaceholderLocal(songId: song.id),
          const SizedBox(width: SearchThemeLocal.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.title,
                  style: SearchThemeLocal.songTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SearchThemeLocal.space4),
                Text(
                  song.artist,
                  style: SearchThemeLocal.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: SearchThemeLocal.space12),
          Text(
            song.formattedDuration,
            style: SearchThemeLocal.auxiliary,
            semanticsLabel:
                'Duración ${song.formattedDuration.replaceAll(':', ' minutos ')} segundos',
          ),
        ],
      ),
    );
  }
}
