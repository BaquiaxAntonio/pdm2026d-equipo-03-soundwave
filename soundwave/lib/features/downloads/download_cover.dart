import 'package:flutter/material.dart';

/// Portadas geométricas locales: sin imágenes remotas ni assets adicionales.
class DownloadCover extends StatelessWidget {
  const DownloadCover({super.key, required this.index});

  final int index;

  static const _colors = [
    Color(0xFF335B65),
    Color(0xFF615080),
    Color(0xFF276477),
    Color(0xFF8A5145),
    Color(0xFF596B44),
    Color(0xFF3D5180),
  ];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.square(
          dimension: 56,
          child: ColoredBox(
            color: _colors[index % _colors.length],
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  right: -14,
                  top: -12,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 12),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: index * 0.5,
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
