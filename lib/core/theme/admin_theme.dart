import 'package:flutter/material.dart';

abstract final class AdminTheme {
  static const Color primary = Color(0xFF0679D8);
  static const Color navy = Color(0xFF16264D);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF5F8FC);
  static const Color border = Color(0xFFDCE6ED);
  static const Color muted = Color(0xFF66758A);
  static const Color success = Color(0xFF18A65A);
  static const Color warning = Color(0xFFE99A24);
  static const Color danger = Color(0xFFD74747);

  static ThemeData get data => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          surface: surface,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          foregroundColor: navy,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.4),
          ),
        ),
      );
}
