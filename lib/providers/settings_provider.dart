import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _restTimerKey = 'rest_timer_seconds';
  static const String _unitsKey = 'units';
  static const String _notificationsKey = 'notifications_enabled';
  static const String _usernameKey = 'username';
  static const String _languageCodeKey = 'language_code';
  static const String _aiFeatureEnabledKey = 'ai_feature_enabled';
  static const String _hasSeenAiSetupKey = 'has_seen_ai_setup';

  int _restTimerSeconds = 90;
  String _units = 'metric'; // 'metric' or 'imperial'
  bool _notificationsEnabled = true;
  String _username = 'Player';
  String _languageCode = 'en';
  bool _aiFeatureEnabled = false;
  bool _hasSeenAiSetup = false;

  // Getters
  int get restTimerSeconds => _restTimerSeconds;
  String get units => _units;
  bool get isMetric => _units == 'metric';
  bool get notificationsEnabled => _notificationsEnabled;
  String get weightUnit => isMetric ? 'kg' : 'lbs';
  String get distanceUnit => isMetric ? 'km' : 'mi';
  String get username => _username;
  String get languageCode => _languageCode;
  bool get aiFeatureEnabled => _aiFeatureEnabled;
  bool get hasSeenAiSetup => _hasSeenAiSetup;
  Locale get locale => Locale(_languageCode);
  String get languageNativeName =>
      AppLocalizations.nativeLanguageNames[_languageCode] ?? 'English';

  /// Formatted rest timer label (e.g. "90 seconds", "2 minutes")
  String get restTimerLabel {
    if (_restTimerSeconds < 60) {
      return '$_restTimerSeconds seconds';
    } else if (_restTimerSeconds == 60) {
      return '1 minute';
    } else if (_restTimerSeconds % 60 == 0) {
      return '${_restTimerSeconds ~/ 60} minutes';
    } else {
      final minutes = _restTimerSeconds ~/ 60;
      final seconds = _restTimerSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
  }

  /// Available rest timer options in seconds
  static const List<int> restTimerOptions = [30, 60, 90, 120, 180];

  /// Initialize and load saved settings
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedRestTimer = prefs.getInt(_restTimerKey);
      if (savedRestTimer != null) {
        _restTimerSeconds = savedRestTimer;
      }

      final savedUnits = prefs.getString(_unitsKey);
      if (savedUnits != null) {
        _units = savedUnits;
      }

      final savedNotifications = prefs.getBool(_notificationsKey);
      if (savedNotifications != null) {
        _notificationsEnabled = savedNotifications;
      }

      final savedUsername = prefs.getString(_usernameKey);
      if (savedUsername != null && savedUsername.trim().isNotEmpty) {
        _username = savedUsername.trim();
      }

      final savedLanguageCode = prefs.getString(_languageCodeKey);
      if (savedLanguageCode != null &&
          AppLocalizations.nativeLanguageNames.containsKey(savedLanguageCode)) {
        _languageCode = savedLanguageCode;
      }

      final savedAiEnabled = prefs.getBool(_aiFeatureEnabledKey);
      if (savedAiEnabled != null) {
        _aiFeatureEnabled = savedAiEnabled;
      }

      final savedSeenAi = prefs.getBool(_hasSeenAiSetupKey);
      if (savedSeenAi != null) {
        _hasSeenAiSetup = savedSeenAi;
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }

    notifyListeners();
  }

  /// Set rest timer duration in seconds
  Future<void> setRestTimerSeconds(int seconds) async {
    if (_restTimerSeconds == seconds) return;

    _restTimerSeconds = seconds;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_restTimerKey, seconds);
    } catch (e) {
      debugPrint('Error saving rest timer: $e');
    }
  }

  /// Set units preference
  Future<void> setUnits(String units) async {
    if (_units == units) return;

    _units = units;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_unitsKey, units);
    } catch (e) {
      debugPrint('Error saving units: $e');
    }
  }

  /// Toggle notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;

    _notificationsEnabled = enabled;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsKey, enabled);
    } catch (e) {
      debugPrint('Error saving notifications setting: $e');
    }
  }

  /// Set display username used across home/profile surfaces.
  Future<void> setUsername(String username) async {
    final sanitized = username.trim();
    if (sanitized.isEmpty || _username == sanitized) return;

    _username = sanitized;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usernameKey, sanitized);
    } catch (e) {
      debugPrint('Error saving username: $e');
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (_languageCode == code ||
        !AppLocalizations.nativeLanguageNames.containsKey(code)) {
      return;
    }

    _languageCode = code;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageCodeKey, code);
    } catch (e) {
      debugPrint('Error saving language code: $e');
    }
  }

  Future<void> setAiFeatureEnabled(bool enabled) async {
    if (_aiFeatureEnabled == enabled) return;
    _aiFeatureEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_aiFeatureEnabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving AI feature enabled: $e');
    }
  }

  Future<void> setHasSeenAiSetup(bool seen) async {
    if (_hasSeenAiSetup == seen) return;
    _hasSeenAiSetup = seen;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasSeenAiSetupKey, seen);
    } catch (e) {
      debugPrint('Error saving has seen AI setup: $e');
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _restTimerSeconds = 90;
    _units = 'metric';
    _notificationsEnabled = true;
    _username = 'Player';
    _languageCode = 'en';
    _aiFeatureEnabled = false;
    _hasSeenAiSetup = false;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_restTimerKey);
      await prefs.remove(_unitsKey);
      await prefs.remove(_notificationsKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_languageCodeKey);
      await prefs.remove(_aiFeatureEnabledKey);
      await prefs.remove(_hasSeenAiSetupKey);
    } catch (e) {
      debugPrint('Error resetting settings: $e');
    }
  }
}
