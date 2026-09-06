import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _useOledKey = 'use_oled';
  static const String _accentColorKey = 'accent_color';

  /// 7 fixed preset accent colors tested for contrast in both light and dark modes:
  /// 1. Volt Yellow (Original Repp primary)
  /// 2. Lime Pulse (High energy athletic)
  /// 3. Cyan Flare (Electric aqua)
  /// 4. Coral Ember (Vibrant warm red-orange)
  /// 5. Sunset Orange (Warm energetic)
  /// 6. Royal Violet (Bold purple)
  /// 7. Hot Fuchsia (Neon magenta)
  static const List<Color> presetAccentColors = [
    Color(0xFFFACC15), // Volt Yellow
    Color(0xFF10B981), // Emerald Mint
    Color(0xFF06B6D4), // Electric Cyan
    Color(0xFF3B82F6), // Azure Blue
    Color(0xFF8B5CF6), // Royal Violet
    Color(0xFFEC4899), // Hot Fuchsia
    Color(0xFFF97316), // Sunset Orange
  ];

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _useOledDark = true;
  Color _accentColor = const Color(0xFFFACC15);
  bool _isInitialized = false;

  AppThemeMode get themeMode => _themeMode;
  bool get useOledDark => _useOledDark;
  Color get accentColor => _accentColor;
  bool get useGlassmorphism => true;
  bool get isInitialized => _isInitialized;

  /// Get the actual theme mode considering system preference
  ThemeMode get effectiveThemeMode {
    switch (_themeMode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  /// Check if the current effective theme is dark
  bool get isDarkMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.system:
        final brightness =
            SchedulerBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark;
    }
  }

  /// Get theme mode display name
  String get themeModeDisplayName {
    switch (_themeMode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  /// Initialize the provider by loading saved preferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load theme mode
      final savedThemeMode = prefs.getString(_themeModeKey);
      if (savedThemeMode != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.name == savedThemeMode,
          orElse: () => AppThemeMode.system,
        );
      }

      // Load OLED preference
      _useOledDark = prefs.getBool(_useOledKey) ?? true;

      // Load accent color preference
      final savedAccentColor = prefs.getInt(_accentColorKey);
      if (savedAccentColor != null) {
        _accentColor = Color(savedAccentColor);
      }

      // One-time cleanup for removed glass toggle preference.
      await prefs.remove('use_glass');

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      // If preferences fail to load, use defaults
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Set custom accent color
  Future<void> setAccentColor(Color color) async {
    if (_accentColor.toARGB32() == color.toARGB32()) return;

    _accentColor = color;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_accentColorKey, color.toARGB32());
    } catch (e) {
      // Silently fail - the in-memory state is still updated
    }
  }

  /// Set the theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (e) {
      // Silently fail - the in-memory state is still updated
    }
  }

  /// Toggle between light and dark mode (skipping system)
  Future<void> toggleTheme() async {
    final newMode = isDarkMode ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Set OLED dark mode preference
  Future<void> setUseOledDark(bool value) async {
    if (_useOledDark == value) return;

    _useOledDark = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useOledKey, value);
    } catch (e) {
      // Silently fail
    }
  }

  /// Cycle through theme modes: System -> Light -> Dark -> System
  Future<void> cycleThemeMode() async {
    final nextMode = AppThemeMode
        .values[(_themeMode.index + 1) % AppThemeMode.values.length];
    await setThemeMode(nextMode);
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    _themeMode = AppThemeMode.system;
    _useOledDark = true;
    _accentColor = const Color(0xFFFACC15);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_themeModeKey);
      await prefs.remove(_useOledKey);
      await prefs.remove(_accentColorKey);
      await prefs.remove('use_glass');
    } catch (e) {
      // Silently fail
    }
  }
}
