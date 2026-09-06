import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

/// Light theme configuration for Repp app
/// Includes glassmorphism-ready styling with translucent surfaces
class LightTheme {
  LightTheme._();

  static const Color _backgroundColor = AppColors.lightBackground;
  static const Color _surfaceColor = AppColors.lightSurface;
  static const Color _cardColor = AppColors.lightCard;

  /// Build the complete light theme
  static ThemeData build({Color? primaryColor, bool useGlassmorphism = true}) {
    final activePrimary = primaryColor ?? AppColors.primary;
    final onPrimaryTextColor =
        ThemeData.estimateBrightnessForColor(activePrimary) == Brightness.dark
            ? Colors.white
            : const Color(0xFF1A1A1A);

    final colorScheme = ColorScheme.light(
      primary: activePrimary,
      onPrimary: onPrimaryTextColor,
      primaryContainer: activePrimary.withValues(alpha: 0.2),
      onPrimaryContainer: activePrimary,
      secondary: AppColors.secondary,
      onSecondary: const Color(0xFF1A1A1A),
      secondaryContainer: AppColors.secondaryLight.withValues(alpha: 0.2),
      onSecondaryContainer: AppColors.secondaryDark,
      tertiary: AppColors.accentPurple,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorBackground,
      onErrorContainer: AppColors.errorDark,
      surface: _surfaceColor,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      onSurfaceVariant: AppColors.lightTextSecondary,
      outline: AppColors.lightDivider,
      outlineVariant: AppColors.lightDivider.withValues(alpha: 0.5),
      shadow: AppColors.lightGlassShadow,
      scrim: Colors.black54,
      inverseSurface: AppColors.darkSurface,
      onInverseSurface: AppColors.darkTextPrimary,
      inversePrimary: AppColors.primaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _backgroundColor,
      canvasColor: _backgroundColor,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      // Visual density for compact UI
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: useGlassmorphism
            ? _surfaceColor.withValues(alpha: 0.85)
            : _surfaceColor,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: useGlassmorphism ? 0 : 1,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: const TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.lightTextPrimary,
          size: 24,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: useGlassmorphism ? _cardColor.withValues(alpha: 0.8) : _cardColor,
        elevation: useGlassmorphism ? 0 : 1,
        shadowColor: AppColors.lightGlassShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: useGlassmorphism
              ? BorderSide(color: AppColors.lightGlassBorder, width: 1.5)
              : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: activePrimary,
          foregroundColor: const Color(0xFF1A1A1A),
          disabledBackgroundColor: AppColors.lightTextDisabled,
          disabledForegroundColor: Colors.white70,
          elevation: useGlassmorphism ? 0 : 2,
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
          disabledBackgroundColor: AppColors.lightTextDisabled,
          disabledForegroundColor: Colors.white70,
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
          foregroundColor: AppColors.lightTextPrimary,
          disabledForegroundColor: AppColors.lightTextDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: useGlassmorphism
                ? AppColors.lightDivider.withValues(alpha: 0.8)
                : AppColors.lightDivider,
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
          disabledForegroundColor: AppColors.lightTextDisabled,
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
          foregroundColor: AppColors.lightTextSecondary,
          disabledForegroundColor: AppColors.lightTextDisabled,
          highlightColor: activePrimary.withValues(alpha: 0.1),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: activePrimary,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: useGlassmorphism ? 2 : 4,
        focusElevation: useGlassmorphism ? 4 : 6,
        hoverElevation: useGlassmorphism ? 4 : 6,
        highlightElevation: useGlassmorphism ? 6 : 8,
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
            ? AppColors.lightSurfaceVariant.withValues(alpha: 0.6)
            : AppColors.lightSurfaceVariant,
        hoverColor: AppColors.lightSurfaceVariant,
        focusColor: activePrimary.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: useGlassmorphism
              ? BorderSide(color: AppColors.lightGlassBorder, width: 1)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
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
          color: AppColors.lightTextTertiary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: activePrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        prefixIconColor: AppColors.lightTextSecondary,
        suffixIconColor: AppColors.lightTextSecondary,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: useGlassmorphism
            ? AppColors.lightSurfaceVariant.withValues(alpha: 0.6)
            : AppColors.lightSurfaceVariant,
        deleteIconColor: AppColors.lightTextSecondary,
        disabledColor: AppColors.lightSurfaceVariant.withValues(alpha: 0.5),
        selectedColor: activePrimary,
        secondarySelectedColor: activePrimary.withValues(alpha: 0.2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: useGlassmorphism
              ? BorderSide(color: AppColors.lightGlassBorder, width: 1)
              : BorderSide.none,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextPrimary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        brightness: Brightness.light,
      ),

      // Navigation Bar Theme (Bottom Navigation)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: useGlassmorphism
            ? _surfaceColor.withValues(alpha: 0.85)
            : _surfaceColor,
        elevation: 0,
        indicatorColor: activePrimary.withValues(alpha: 0.15),
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
            color: AppColors.lightTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: activePrimary, size: 24);
          }
          return IconThemeData(color: AppColors.lightTextSecondary, size: 24);
        }),
        surfaceTintColor: Colors.transparent,
        shadowColor: AppColors.lightGlassShadow,
      ),

      // Bottom Navigation Bar Theme (Legacy)
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: useGlassmorphism
            ? _surfaceColor.withValues(alpha: 0.85)
            : _surfaceColor,
        selectedItemColor: activePrimary,
        unselectedItemColor: AppColors.lightTextSecondary,
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
            ? _surfaceColor.withValues(alpha: 0.95)
            : _surfaceColor,
        modalBackgroundColor: useGlassmorphism
            ? _surfaceColor.withValues(alpha: 0.95)
            : _surfaceColor,
        elevation: useGlassmorphism ? 0 : 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: AppColors.lightDivider,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: useGlassmorphism
            ? _surfaceColor.withValues(alpha: 0.95)
            : _surfaceColor,
        elevation: useGlassmorphism ? 0 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: useGlassmorphism
              ? BorderSide(color: AppColors.lightGlassBorder, width: 1)
              : BorderSide.none,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextSecondary,
        ),
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        actionTextColor: AppColors.primaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 1,
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.lightTextSecondary,
        textColor: AppColors.lightTextPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.transparent,
        selectedTileColor: activePrimary.withValues(alpha: 0.1),
        selectedColor: activePrimary,
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return AppColors.lightSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return activePrimary.withValues(alpha: 0.5);
          }
          return AppColors.lightDivider;
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
        side: BorderSide(color: AppColors.lightDivider, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return activePrimary;
          return AppColors.lightTextSecondary;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: activePrimary,
        inactiveTrackColor: activePrimary.withValues(alpha: 0.2),
        thumbColor: activePrimary,
        overlayColor: activePrimary.withValues(alpha: 0.1),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: activePrimary,
        linearTrackColor: activePrimary.withValues(alpha: 0.2),
        circularTrackColor: activePrimary.withValues(alpha: 0.2),
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: activePrimary,
        unselectedLabelColor: AppColors.lightTextSecondary,
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
        color: useGlassmorphism
            ? _surfaceColor.withValues(alpha: 0.95)
            : _surfaceColor,
        elevation: useGlassmorphism ? 2 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: useGlassmorphism
              ? BorderSide(color: AppColors.lightGlassBorder, width: 1)
              : BorderSide.none,
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextPrimary,
        ),
      ),

      // Tooltip Theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.darkSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
          letterSpacing: -0.1,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
          letterSpacing: 0.1,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextPrimary,
          letterSpacing: 0.15,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextSecondary,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextTertiary,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextSecondary,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextTertiary,
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
