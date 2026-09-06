import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Dark theme configuration for Repp app
/// Supports both standard dark and OLED (true black) modes
/// Includes glassmorphism-ready styling with translucent surfaces
class DarkTheme {
  DarkTheme._();

  /// Build the complete dark theme
  /// [useOled] - Use true black backgrounds for AMOLED screens
  /// [useGlassmorphism] - Enable glassmorphism effects
  static ThemeData build({
    Color? primaryColor,
    bool useOled = true,
    bool useGlassmorphism = true,
  }) {
    final activePrimary = primaryColor ?? AppColors.primary;
    final onPrimaryTextColor =
        ThemeData.estimateBrightnessForColor(activePrimary) == Brightness.dark
            ? Colors.white
            : const Color(0xFF1A1A1A);

    // Select colors based on OLED mode
    final backgroundColor = useOled
        ? AppColors.oledBackground
        : AppColors.darkBackground;
    final surfaceColor = useOled
        ? AppColors.oledSurface
        : AppColors.darkSurface;
    final cardColor = useOled ? AppColors.oledCard : AppColors.darkCard;
    final surfaceVariant = useOled
        ? AppColors.oledSurfaceVariant
        : AppColors.darkSurfaceVariant;
    final dividerColor = useOled
        ? AppColors.oledDivider
        : AppColors.darkDivider;
    final glassBorder = useOled
        ? AppColors.oledGlassBorder
        : AppColors.darkGlassBorder;
    final glassShadow = useOled
        ? AppColors.oledGlassShadow
        : AppColors.darkGlassShadow;

    final colorScheme = ColorScheme.dark(
      primary: activePrimary,
      onPrimary: onPrimaryTextColor,
      primaryContainer: activePrimary.withValues(alpha: 0.3),
      onPrimaryContainer: activePrimary,
      secondary: AppColors.secondary,
      onSecondary: const Color(0xFF1A1A1A),
      secondaryContainer: AppColors.secondaryDark.withValues(alpha: 0.3),
      onSecondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.accentPurple,
      onTertiary: Colors.white,
      error: AppColors.errorLight,
      onError: Colors.white,
      errorContainer: AppColors.errorBackgroundDark,
      onErrorContainer: AppColors.errorLight,
      surface: surfaceColor,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: surfaceVariant,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: dividerColor,
      outlineVariant: dividerColor.withValues(alpha: 0.5),
      shadow: glassShadow,
      scrim: Colors.black87,
      inverseSurface: AppColors.lightSurface,
      onInverseSurface: AppColors.lightTextPrimary,
      inversePrimary: AppColors.primaryDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      // Visual density for compact UI
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: useGlassmorphism
            ? surfaceColor.withValues(alpha: 0.85)
            : surfaceColor,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: useGlassmorphism ? 0 : 1,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.darkTextPrimary,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: useGlassmorphism ? cardColor.withValues(alpha: 0.6) : cardColor,
        elevation: useGlassmorphism ? 0 : 2,
        shadowColor: glassShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: useGlassmorphism
              ? BorderSide(color: glassBorder, width: 1.5)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activePrimary,
          foregroundColor: const Color(0xFF1A1A1A),
          disabledBackgroundColor: AppColors.darkTextDisabled,
          disabledForegroundColor: Colors.white38,
          elevation: useGlassmorphism ? 0 : 4,
          shadowColor: activePrimary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),

      // Filled Button Theme (Material 3)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: activePrimary,
          foregroundColor: const Color(0xFF1A1A1A),
          disabledBackgroundColor: AppColors.darkTextDisabled,
          disabledForegroundColor: Colors.white38,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkTextPrimary,
          disabledForegroundColor: AppColors.darkTextDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: useGlassmorphism ? glassBorder : dividerColor,
            width: 1.5,
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: activePrimary,
          disabledForegroundColor: AppColors.darkTextDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          animationDuration: const Duration(milliseconds: 140),
        ),
      ),

      // Icon Button Theme
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.darkTextSecondary,
          disabledForegroundColor: AppColors.darkTextDisabled,
          highlightColor: activePrimary.withValues(alpha: 0.15),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: activePrimary,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: useGlassmorphism ? 2 : 6,
        focusElevation: useGlassmorphism ? 4 : 8,
        hoverElevation: useGlassmorphism ? 4 : 8,
        highlightElevation: useGlassmorphism ? 6 : 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: useGlassmorphism
            ? surfaceVariant.withValues(alpha: 0.4)
            : surfaceVariant,
        hoverColor: surfaceVariant.withValues(alpha: 0.6),
        focusColor: activePrimary.withValues(alpha: 0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: useGlassmorphism
              ? BorderSide(color: glassBorder, width: 1)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorLight, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorLight, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(
          color: AppColors.darkTextTertiary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: activePrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: AppColors.errorLight,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        prefixIconColor: AppColors.darkTextSecondary,
        suffixIconColor: AppColors.darkTextSecondary,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: useGlassmorphism
            ? surfaceVariant.withValues(alpha: 0.4)
            : surfaceVariant,
        deleteIconColor: AppColors.darkTextSecondary,
        disabledColor: surfaceVariant.withValues(alpha: 0.3),
        selectedColor: activePrimary,
        secondarySelectedColor: activePrimary.withValues(alpha: 0.3),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: useGlassmorphism
              ? BorderSide(color: glassBorder, width: 1)
              : BorderSide.none,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        brightness: Brightness.dark,
      ),

      // Navigation Bar Theme (Bottom Navigation)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: useGlassmorphism
            ? surfaceColor.withValues(alpha: 0.85)
            : surfaceColor,
        elevation: 0,
        indicatorColor: activePrimary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: activePrimary,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: activePrimary, size: 24);
          }
          return IconThemeData(color: AppColors.darkTextSecondary, size: 24);
        }),
        surfaceTintColor: Colors.transparent,
        shadowColor: glassShadow,
      ),

      // Bottom Navigation Bar Theme (Legacy)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: useGlassmorphism
            ? surfaceColor.withValues(alpha: 0.85)
            : surfaceColor,
        selectedItemColor: activePrimary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: useGlassmorphism ? 0 : 8,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: useGlassmorphism
            ? surfaceColor.withValues(alpha: 0.95)
            : surfaceColor,
        modalBackgroundColor: useGlassmorphism
            ? surfaceColor.withValues(alpha: 0.95)
            : surfaceColor,
        elevation: useGlassmorphism ? 0 : 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: dividerColor,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: useGlassmorphism
            ? surfaceColor.withValues(alpha: 0.95)
            : surfaceColor,
        elevation: useGlassmorphism ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: useGlassmorphism
              ? BorderSide(color: glassBorder, width: 1)
              : BorderSide.none,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextSecondary,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceVariant,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
        actionTextColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.darkTextSecondary,
        textColor: AppColors.darkTextPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.transparent,
        selectedTileColor: activePrimary.withValues(alpha: 0.15),
        selectedColor: activePrimary,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return AppColors.darkTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return activePrimary.withValues(alpha: 0.5);
          }
          return dividerColor;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: BorderSide(color: AppColors.darkTextSecondary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return AppColors.darkTextSecondary;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: activePrimary,
        inactiveTrackColor: activePrimary.withValues(alpha: 0.3),
        thumbColor: activePrimary,
        overlayColor: activePrimary.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: activePrimary,
        linearTrackColor: activePrimary.withValues(alpha: 0.3),
        circularTrackColor: activePrimary.withValues(alpha: 0.3),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: activePrimary,
        unselectedLabelColor: AppColors.darkTextSecondary,
        indicatorColor: activePrimary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
      ),

      // Popup Menu Theme
      popupMenuTheme: PopupMenuThemeData(
        color: useGlassmorphism ? surfaceColor.withValues(alpha: 0.95) : surfaceColor,
        elevation: useGlassmorphism ? 2 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: useGlassmorphism
              ? BorderSide(color: glassBorder, width: 1)
              : BorderSide.none,
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceVariant.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: glassBorder),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
          letterSpacing: -0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextPrimary,
          letterSpacing: 0.15,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextSecondary,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextTertiary,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextSecondary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextTertiary,
          letterSpacing: 0.5,
        ),
      ),

      // Primary Text Theme (for on primary color surfaces)
      primaryTextTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
        bodySmall: TextStyle(color: Colors.white60),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),

      // Extensions for glassmorphism (custom theme extensions can be added)
      extensions: const <ThemeExtension<dynamic>>[],
    );
  }
}
