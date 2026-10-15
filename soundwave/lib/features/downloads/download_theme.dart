import 'package:flutter/material.dart';

// Paleta del documento UX, local hasta consolidar el tema compartido.
abstract final class DownloadTheme {
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF172235);
  static const elevated = Color(0xFF223047);
  static const accent = Color(0xFF2DD4BF);
  static const primary = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);

  static ThemeData get data => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      onPrimary: background,
      surface: surface,
      onSurface: primary,
      error: Color(0xFFFCA5A5),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: primary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: secondary),
      bodySmall: TextStyle(fontSize: 12, color: secondary),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: elevated,
      contentTextStyle: TextStyle(color: primary),
      actionTextColor: accent,
    ),
  );
}
