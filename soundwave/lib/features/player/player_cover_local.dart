import 'package:flutter/material.dart';

import 'player_theme_local.dart';

// Portada protagonista del reproductor, placeholder local.
// Motivo: sin descargas ni paquetes; color determinista por id.
class PlayerCoverLocal extends StatelessWidget {
  final String songId;
  final double size;

  const PlayerCoverLocal({super.key, required this.songId, this.size = 232});

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
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _toneFor(songId),
        borderRadius: BorderRadius.circular(PlayerThemeLocal.coverRadius),
        border: Border.all(color: PlayerThemeLocal.surfaceElevated),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note,
        size: 72,
        color: PlayerThemeLocal.textSecondary,
        semanticLabel: 'Portada de la canción actual',
      ),
    );
  }
}
