import 'package:flutter/material.dart';

/// Tema de marca Pazilda: terracota, salmón y tinta cálida sobre
/// superficies blancas (logo de la empresa).
class AppTheme {
  AppTheme._();

  static const Color coral = Color(0xFFC04818);
  static const Color coralDark = Color(0xFF9E3A12);
  static const Color salmon = Color(0xFFF0A890);
  static const Color salmonSoft = Color(0xFFFBF1EB);
  static const Color ink = Color(0xFF2B2118);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: coral,
    ).copyWith(
      primary: coral,
      onPrimary: Colors.white,
      primaryContainer: salmonSoft,
      onPrimaryContainer: coralDark,
      secondary: salmon,
      onSecondary: ink,
      secondaryContainer: salmonSoft,
      onSecondaryContainer: coralDark,
      surface: Colors.white,
      onSurface: ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: salmonSoft,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: salmon.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: coral,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: coralDark,
          side: const BorderSide(color: salmon),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: coralDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: salmon),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: salmon.withValues(alpha: 0.7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coral, width: 2),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        indicatorColor: salmon.withValues(alpha: 0.45),
        selectedIconTheme: const IconThemeData(color: coral),
        unselectedIconTheme: IconThemeData(color: ink.withValues(alpha: 0.55)),
        selectedLabelTextStyle: const TextStyle(
          color: coralDark,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: ink.withValues(alpha: 0.6)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: salmon.withValues(alpha: 0.8)),
        ),
        backgroundColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: salmon.withValues(alpha: 0.5)),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
