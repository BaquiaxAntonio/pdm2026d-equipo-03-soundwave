import 'package:flutter/material.dart';

import 'search_theme_local.dart';

// Placeholder local 56x56 con icono musical y variación discreta de color.
// Motivo: sin descargas ni paquetes; el color es determinista por id para
// mantener el mismo placeholder al filtrar.
class CoverPlaceholderLocal extends StatelessWidget {
  final String songId;

  const CoverPlaceholderLocal({super.key, required this.songId});

  static const _tones = [
    Color(0xFF223047),
    Color(0xFF1E3A4C),
    Color(0xFF2A3550),
    Color(0xFF234039),
  ];

  Color _toneFor(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) % 0x7FFFFFFF;
    }
    return _tones[hash % _tones.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: SearchThemeLocal.coverSize,
      height: SearchThemeLocal.coverSize,
      decoration: BoxDecoration(
        color: _toneFor(songId),
        borderRadius: BorderRadius.circular(SearchThemeLocal.coverRadius),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.music_note,
        color: SearchThemeLocal.textSecondary,
        semanticLabel: 'Portada de canción',
      ),
    );
  }
}
