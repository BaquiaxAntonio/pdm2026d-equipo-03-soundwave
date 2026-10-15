import 'package:flutter/material.dart';

// Tema local de player, duplicado a propósito desde search.
// Motivo: Fase 1 sin sistema global; cada feature es dueña de su
// carpeta y no importa de otras (se unifica en Fase 2).
abstract final class PlayerThemeLocal {
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF172235);
  static const surfaceElevated = Color(0xFF223047);
  static const accent = Color(0xFF2DD4BF);
  static const onAccent = Color(0xFF0B1220);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFFCBD5E1);
  static const error = Color(0xFFFCA5A5);

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double buttonRadius = 12;
  static const double coverRadius = 12;

  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );
  static const songTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const artist = TextStyle(fontSize: 14, color: textSecondary);
  static const auxiliary = TextStyle(fontSize: 12, color: textSecondary);
}
