import 'package:flutter/material.dart';

/// App color palette with support for light, dark, and OLED dark modes
class AppColors {
  AppColors._();

  // ==========================================================================
  // PRIMARY BRAND COLORS
  // ==========================================================================

  /// Primary brand color - vivid yellow action accent
  static const Color primary = Color(0xFFFACC15);
  static const Color primaryLight = Color(0xFFFDE68A);
  static const Color primaryDark = Color(0xFFEAB308);

  /// Secondary accent color - deep navy anchor for yellow accents
  static const Color secondary = Color(0xFF0F172A);
  static const Color secondaryLight = Color(0xFF1E3A8A);
  static const Color secondaryDark = Color(0xFF0B1220);

  /// Accent gradient colors
  static const Color accentPurple = Color(0xFF9C27B0);
  static const Color accentPink = Color(0xFFE91E63);
  static const Color accentOrange = Color(0xFFFF9800);
  static const Color accentTeal = Color(0xFF009688);

  // ==========================================================================
  // LIGHT MODE COLORS
  // ==========================================================================

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightDivider = Color(0xFFE2E8F0);

  // Light mode text colors
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextTertiary = Color(0xFF9AA0A6);
  static const Color lightTextDisabled = Color(0xFF94A3B8);

  // ==========================================================================
  // DARK MODE COLORS (Standard)
  // ==========================================================================

  static const Color darkBackground = Color(0xFF020617);
  static const Color darkSurface = Color(0xFF0F172A);
  static const Color darkSurfaceVariant = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF0F172A);
  static const Color darkDivider = Color(0xFF1E293B);

  // Dark mode text colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF9AA0A6);
  static const Color darkTextDisabled = Color(0xFF475569);

  // ==========================================================================
  // OLED DARK MODE COLORS (True black for AMOLED screens)
  // ==========================================================================

  static const Color oledBackground = Color(0xFF000000);
  static const Color oledSurface = Color(0xFF0F172A);
  static const Color oledSurfaceVariant = Color(0xFF1E293B);
  static const Color oledCard = Color(0xFF0F172A);
  static const Color oledDivider = Color(0xFF1E293B);

  // OLED mode uses same text colors as dark mode
  static const Color oledTextPrimary = darkTextPrimary;
  static const Color oledTextSecondary = darkTextSecondary;
  static const Color oledTextTertiary = darkTextTertiary;
  static const Color oledTextDisabled = darkTextDisabled;

  // ==========================================================================
  // GLASSMORPHISM COLORS
  // ==========================================================================

  // Light mode glass
  static const Color lightGlassBackground = Color(0xB3FFFFFF);
  static const Color lightGlassBorder = Color(0x66FFFFFF);
  static const Color lightGlassShadow = Color(0x24000000);

  // Dark mode glass
  static const Color darkGlassBackground = Color(0x36FFFFFF);
  static const Color darkGlassBorder = Color(0x42FFFFFF);
  static const Color darkGlassShadow = Color(0x52000000);

  // OLED mode glass (slightly more transparent for true black)
  static const Color oledGlassBackground = Color(0x2EFFFFFF);
  static const Color oledGlassBorder = Color(0x30FFFFFF);
  static const Color oledGlassShadow = Color(0x66000000);

  // ==========================================================================
  // SEMANTIC COLORS
  // ==========================================================================

  // Success colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF81C784);
  static const Color successDark = Color(0xFF388E3C);
  static const Color successBackground = Color(0xFFE8F5E9);
  static const Color successBackgroundDark = Color(0xFF1B3D1E);

  // Warning colors
  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFD54F);
  static const Color warningDark = Color(0xFFFFA000);
  static const Color warningBackground = Color(0xFFFFF8E1);
  static const Color warningBackgroundDark = Color(0xFF3D3215);

  // Error colors
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFE57373);
  static const Color errorDark = Color(0xFFD32F2F);
  static const Color errorBackground = Color(0xFFFFEBEE);
  static const Color errorBackgroundDark = Color(0xFF3D1515);

  // Info colors
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFF64B5F6);
  static const Color infoDark = Color(0xFF1976D2);
  static const Color infoBackground = Color(0xFFE3F2FD);
  static const Color infoBackgroundDark = Color(0xFF152A3D);

  // ==========================================================================
  // EXERCISE / MUSCLE GROUP COLORS
  // ==========================================================================

  static const Color muscleChest = Color(0xFFE91E63);
  static const Color muscleBack = Color(0xFF3F51B5);
  static const Color muscleShoulders = Color(0xFF9C27B0);
  static const Color muscleArms = Color(0xFFFF5722);
  static const Color muscleLegs = Color(0xFF4CAF50);
  static const Color muscleCore = Color(0xFF00BCD4);
  static const Color muscleCardio = Color(0xFFF44336);
  static const Color muscleFullBody = Color(0xFF607D8B);

  // ==========================================================================
  // GRADIENT DEFINITIONS
  // ==========================================================================

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [accentOrange, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [primary, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================================================
  // SOLO LEVELING / GAMIFICATION COLORS
  // ==========================================================================

  /// System glow accent — soft yellow
  static const Color systemBlue = primary;
  static const Color systemBlueDark = primaryDark;

  /// XP / Level-up gold
  static const Color systemGold = Color(0xFFFFD54F);
  static const Color systemGoldDark = Color(0xFFFFA000);

  /// Rank accent — purple
  static const Color systemPurple = Color(0xFFB388FF);

  /// XP gain flash — green
  static const Color xpGreen = Color(0xFF69F0AE);

  /// System panel gradient (dark floating notification)
  static const LinearGradient systemPanelGradient = LinearGradient(
    colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// XP bar gradient
  static const LinearGradient xpBarGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Level-up glow gradient
  static const LinearGradient levelUpGradient = LinearGradient(
    colors: [Color(0xFFFFD54F), Color(0xFFFF9800)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkOverlay = LinearGradient(
    colors: [Color(0x00000000), Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient lightOverlay = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x80FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Glassmorphism gradients
  static const LinearGradient glassGradientLight = LinearGradient(
    colors: [Color(0xCCFFFFFF), Color(0x7AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientDark = LinearGradient(
    colors: [Color(0x55FFFFFF), Color(0x24FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradientOled = LinearGradient(
    colors: [Color(0x20FFFFFF), Color(0x08FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  /// Get background color based on theme mode
  static Color getBackground({required bool isDark, required bool isOled}) {
    if (!isDark) return lightBackground;
    return isOled ? oledBackground : darkBackground;
  }

  /// Get surface color based on theme mode
  static Color getSurface({required bool isDark, required bool isOled}) {
    if (!isDark) return lightSurface;
    return isOled ? oledSurface : darkSurface;
  }

  /// Get card color based on theme mode
  static Color getCard({required bool isDark, required bool isOled}) {
    if (!isDark) return lightCard;
    return isOled ? oledCard : darkCard;
  }

  /// Get glass background color based on theme mode
  static Color getGlassBackground({
    required bool isDark,
    required bool isOled,
  }) {
    if (!isDark) return lightGlassBackground;
    return isOled ? oledGlassBackground : darkGlassBackground;
  }

  /// Get glass border color based on theme mode
  static Color getGlassBorder({required bool isDark, required bool isOled}) {
    if (!isDark) return lightGlassBorder;
    return isOled ? oledGlassBorder : darkGlassBorder;
  }

  /// Get primary text color based on theme mode
  static Color getTextPrimary({required bool isDark}) {
    return isDark ? darkTextPrimary : lightTextPrimary;
  }

  /// Get secondary text color based on theme mode
  static Color getTextSecondary({required bool isDark}) {
    return isDark ? darkTextSecondary : lightTextSecondary;
  }

  /// Get divider color based on theme mode
  static Color getDivider({required bool isDark, required bool isOled}) {
    if (!isDark) return lightDivider;
    return isOled ? oledDivider : darkDivider;
  }

  /// Get muscle group color by name
  static Color getMuscleColor(String muscle) {
    final lowerMuscle = muscle.toLowerCase();
    if (lowerMuscle.contains('chest') || lowerMuscle.contains('pec')) {
      return muscleChest;
    } else if (lowerMuscle.contains('back') || lowerMuscle.contains('lat')) {
      return muscleBack;
    } else if (lowerMuscle.contains('shoulder') ||
        lowerMuscle.contains('delt')) {
      return muscleShoulders;
    } else if (lowerMuscle.contains('bicep') ||
        lowerMuscle.contains('tricep') ||
        lowerMuscle.contains('arm') ||
        lowerMuscle.contains('forearm')) {
      return muscleArms;
    } else if (lowerMuscle.contains('leg') ||
        lowerMuscle.contains('quad') ||
        lowerMuscle.contains('hamstring') ||
        lowerMuscle.contains('glute') ||
        lowerMuscle.contains('calf')) {
      return muscleLegs;
    } else if (lowerMuscle.contains('core') ||
        lowerMuscle.contains('ab') ||
        lowerMuscle.contains('oblique')) {
      return muscleCore;
    } else if (lowerMuscle.contains('cardio')) {
      return muscleCardio;
    }
    return muscleFullBody;
  }
}
