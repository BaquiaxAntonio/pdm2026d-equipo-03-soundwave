import 'package:flutter/material.dart';

// Tema local de search: evita repetir colores/estilos por el código.
// Motivo: Fase 1 sin sistema global de diseño; fuente del sistema,
// sin dependencias ni descargas externas.
abstract final class SearchThemeLocal {
  // Paleta.
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF172235);
  static const surfaceElevated = Color(0xFF223047);
  static const accent = Color(0xFF2DD4BF);
  static const onAccent = Color(0xFF0B1220);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFFCBD5E1);
  static const error = Color(0xFFFCA5A5);

  // Espaciado (escala 4/8/12/16/24/32, margen habitual 24).
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  // Formas.
  static const double searchRadius = 16;
  static const double buttonRadius = 12;
  static const double coverRadius = 12;
  static const double coverSize = 56;

  // Tipografía con fuente del sistema; respeta el escalado del dispositivo
  // al no fijar textScaler ni alturas rígidas.
  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static const sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const songTitle = TextStyle(fontSize: 16, color: textPrimary);
  static const artist = TextStyle(fontSize: 14, color: textSecondary);
  static const auxiliary = TextStyle(fontSize: 12, color: textSecondary);

  static InputDecoration searchDecoration({required bool hasText}) {
    return InputDecoration(
      hintText: 'Busca una canción o artista',
      hintStyle: const TextStyle(fontSize: 16, color: textSecondary),
      prefixIcon: const Icon(Icons.search, color: textSecondary),
      suffixIcon: hasText
          ? const Icon(Icons.clear, color: textSecondary)
          : null,
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: space16,
        vertical: space12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(searchRadius),
        borderSide: const BorderSide(color: surfaceElevated),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(searchRadius),
        // Borde turquesa al foco + texto, no solo color, para el estado.
        borderSide: const BorderSide(color: accent, width: 2),
      ),
    );
  }
}
