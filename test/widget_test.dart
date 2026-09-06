import 'package:flutter_test/flutter_test.dart';
import 'package:repp/models/models.dart';
import 'package:repp/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Language selection persists and restores', () async {
    SharedPreferences.setMockInitialValues({'language_code': 'ta'});

    final settingsProvider = SettingsProvider();
    await settingsProvider.initialize();
    expect(settingsProvider.languageCode, 'ta');

    await settingsProvider.setLanguageCode('en');
    expect(settingsProvider.languageCode, 'en');
    expect(settingsProvider.languageNativeName, 'English');
  });

  test('Workout duration calculation deducts pausedSeconds accurately', () {
    final start = DateTime(2026, 1, 1, 10, 0, 0);
    final end = DateTime(2026, 1, 1, 10, 30, 0); // 30 minutes = 1800s total

    final workoutWithPause = Workout(
      name: 'Leg Day',
      startTime: start,
      endTime: end,
      pausedSeconds: 300, // 5 minutes post-rest idle/paused
    );

    // Should equal 25 minutes = 1500 seconds
    expect(workoutWithPause.duration, const Duration(minutes: 25));
    expect(workoutWithPause.durationString, '25m 0s');
  });
}
