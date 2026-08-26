import 'package:flutter/material.dart';

class DjassaMotion {
  static const Duration micro = Duration(milliseconds: 160);
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 520);
  static const Duration routeForward = Duration(milliseconds: 380);
  static const Duration routeReverse = Duration(milliseconds: 280);

  static const Curve emphasized = Curves.easeOutQuart;
  static const Curve entrance = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve soft = Curves.easeInOutCubic;
}

/// Thème premium pour l'application Djassa
/// Couleurs principales : Noir élégant, Blanc pur, Orange accent
class DjassaTheme {
  // Couleurs principales
  static const Color primaryBlack = Color(0xFF0D0D0F);
  static const Color secondaryBlack = Color(0xFF202124);
  static const Color primaryWhite = Color(0xFFFFFFFF);
  static const Color secondaryWhite = Color(0xFFF6F6F6);
  static const Color accentOrange = Color(0xFFFF4B0B);
  static const Color accentGreen = Color(0xFF4CAF50);

  // Couleurs par profil
  static const Color clientPrimary = Color(0xFFFF4B0B);
  static const Color clientSoft = Color(0xFFFFEFE8);
  static const Color vendorPrimary = Color(0xFF5B3FE8);
  static const Color vendorDark = Color(0xFF1B1642);
  static const Color vendorSoft = Color(0xFFF0EDFF);
  static const Color courierPrimary = Color(0xFF00A676);
  static const Color courierDark = Color(0xFF083C35);
  static const Color courierSoft = Color(0xFFE8F8F2);

  // Couleurs de texte
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF737373);
  static const Color textLight = Color(0xFFBDBDBD);

  // Couleurs de fond
  static const Color backgroundPrimary = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF7F7F8);
  static const Color backgroundDark = Color(0xFF0D0D0F);

  // Couleurs de bordure
  static const Color borderLight = Color(0xFFE8E8EA);
  static const Color borderMedium = Color(0xFFEDEDEF);

  // Opacités
  static const double disabledOpacity = 0.5;
  static const double hoverOpacity = 0.8;

  // Rayons
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 14.0;
  static const double radiusXLarge = 18.0;

  // Ombres
  static List<BoxShadow> get shadowLight => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get shadowHeavy => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 34,
          offset: const Offset(0, 18),
        ),
      ];

  /// Thème Material léger (clair)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundSecondary,
      primaryColor: primaryBlack,
      colorScheme: const ColorScheme.light(
        primary: primaryBlack,
        secondary: accentOrange,
        surface: backgroundPrimary,
        error: Colors.red,
        onPrimary: primaryWhite,
        onSecondary: primaryWhite,
        onSurface: textPrimary,
        onError: primaryWhite,
      ),
      fontFamily: 'Cabin',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'Cabin',
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          fontFamily: 'Cabin',
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          fontFamily: 'Cabin',
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          fontFamily: 'Cabin',
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Cabin',
          color: primaryWhite,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundSecondary,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Hemi Head',
          letterSpacing: 0,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: primaryWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cabin',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlack,
          side: const BorderSide(color: primaryBlack, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cabin',
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundPrimary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: primaryBlack, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          borderSide: const BorderSide(color: Colors.red),
        ),
        hintStyle: const TextStyle(
          fontSize: 14,
          fontFamily: 'Cabin',
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: backgroundPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
          side: const BorderSide(color: borderMedium),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundPrimary,
        selectedItemColor: primaryBlack,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlack,
        foregroundColor: primaryWhite,
        elevation: 4,
      ),
      dividerTheme: const DividerThemeData(
        color: borderMedium,
        thickness: 1,
        space: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryBlack;
          }
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    );
  }

  /// Thème Material sombre (optionnel)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundDark,
      primaryColor: primaryWhite,
      colorScheme: const ColorScheme.dark(
        primary: primaryWhite,
        secondary: accentOrange,
        surface: secondaryBlack,
        error: Colors.red,
        onPrimary: primaryBlack,
        onSecondary: primaryBlack,
        onSurface: primaryWhite,
        onError: primaryWhite,
      ),
      fontFamily: 'Cabin',
      // ... configuration similaire adaptée au mode sombre
    );
  }
}
