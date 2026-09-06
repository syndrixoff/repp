import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../providers/player_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/workout_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../services/database_service.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../ai/local_llm_service.dart';
import 'home_screen.dart';
import 'player_profile_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final playerProvider = context.watch<PlayerProvider>();
    final streakInfo = historyProvider.getStreakInfo();
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined),
            tooltip: 'Hunter Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlayerProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Profile Hero Card
          _ProfileHeader(player: playerProvider, settings: settingsProvider),
          const SizedBox(height: 16),

          // Streak & All-Time Stats
          _StreakAndStatsSection(
            currentStreak: streakInfo['current'] ?? 0,
            longestStreak: streakInfo['longest'] ?? 0,
            totalWorkouts: historyProvider.totalWorkouts,
            totalVolume: historyProvider.totalVolume,
            totalSets: historyProvider.totalSets,
          ),
          const SizedBox(height: 24),

          // Section 1: Appearance
          _SectionHeader(
            title: l10n.appearance.toUpperCase(),
            icon: Icons.palette_outlined,
          ),
          const SizedBox(height: 8),
          const _AppearanceCard(),
          const SizedBox(height: 24),

          // Section 2: Preferences
          _SectionHeader(
            title: l10n.settings.toUpperCase(),
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: Icons.straighten_rounded,
                iconColor: const Color(0xFF38BDF8),
                title: l10n.units,
                subtitle: settingsProvider.isMetric ? 'Metric (kg, km)' : 'Imperial (lbs, mi)',
                valueBadge: settingsProvider.isMetric ? 'kg' : 'lbs',
                onTap: () => _showUnitsDialog(context),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.timer_rounded,
                iconColor: const Color(0xFFFBBF24),
                title: l10n.restTimer,
                subtitle: 'Automatic countdown between workout sets',
                valueBadge: settingsProvider.restTimerLabel,
                onTap: () => _showRestTimerDialog(context),
              ),
              const _GroupDivider(),
              _SettingsSwitchTile(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFFFB923C),
                title: l10n.notifications,
                subtitle: 'Rest timer sound & workout reminders',
                value: settingsProvider.notificationsEnabled,
                onChanged: (val) => settingsProvider.setNotificationsEnabled(val),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.translate_rounded,
                iconColor: const Color(0xFF34D399),
                title: l10n.language,
                subtitle: 'App display language',
                valueBadge: settingsProvider.languageNativeName,
                onTap: () => _showLanguageDialog(context),
              ),
              const _GroupDivider(),
              StreamBuilder<ModelDownloadProgress>(
                stream: ModelDownloadService().progressStream,
                initialData: ModelDownloadService().lastProgress,
                builder: (context, snapshot) {
                  final prog = snapshot.data;
                  final isDownloading =
                      prog?.isDownloading ?? ModelDownloadService().isDownloading;
                  final isDownloaded =
                      prog?.isCompleted == true || ModelDownloadService().isDownloaded;

                  String subtitle = 'On-device multimodal coach & routine creator';
                  if (isDownloading) {
                    final pct = ((prog?.progress ?? 0) * 100).toInt();
                    subtitle = 'Downloading suite ($pct% · ${prog?.currentModelName ?? "In progress"})';
                  } else if (isDownloaded) {
                    subtitle = '4 on-device models ready offline';
                  } else if (settingsProvider.aiFeatureEnabled) {
                    subtitle = 'AI Coach tab active in navigation bar';
                  }

                  return _SettingsSwitchTile(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: const Color(0xFFA78BFA),
                    title: 'AI Coach Feature',
                    subtitle: subtitle,
                    value: settingsProvider.aiFeatureEnabled,
                    onChanged: (val) async {
                      await settingsProvider.setAiFeatureEnabled(val);
                      await settingsProvider.setHasSeenAiSetup(true);

                      if (val && !isDownloaded && !isDownloading) {
                        ModelDownloadService().startDownload();
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            content: Text(
                              val
                                  ? 'AI Coach tab added to navigation bar'
                                  : 'AI Coach tab hidden',
                            ),
                            action: val
                                ? SnackBarAction(
                                    label: 'Open Coach',
                                    textColor: AppColors.primary,
                                    onPressed: () {
                                      HomeScreen.switchToAiTab();
                                    },
                                  )
                                : null,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 3: Data & Storage
          _SectionHeader(
            title: l10n.data.toUpperCase(),
            icon: Icons.folder_shared_outlined,
          ),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: Icons.cloud_upload_outlined,
                iconColor: const Color(0xFF60A5FA),
                title: l10n.exportData,
                subtitle: l10n.exportDataSubtitle,
                onTap: () => _exportData(context),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.cloud_download_outlined,
                iconColor: const Color(0xFF818CF8),
                title: l10n.importData,
                subtitle: l10n.importDataSubtitle,
                onTap: () => _importData(context),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.error,
                title: l10n.clearAllData,
                subtitle: l10n.clearAllDataSubtitle,
                isDestructive: true,
                onTap: () => _showClearDataDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 4: About
          _SectionHeader(
            title: l10n.about.toUpperCase(),
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 8),
          _SettingsGroupCard(
            children: [
              _SettingsTile(
                icon: Icons.fitness_center_rounded,
                iconColor: AppColors.primary,
                title: l10n.aboutRepp,
                subtitle: 'Offline-first, gamified workout assistant',
                valueBadge: 'v1.0.0',
                onTap: () => _showAboutDialog(context),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFF94A3B8),
                title: l10n.privacyPolicy,
                onTap: () => _showPrivacyPolicy(context),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: const Color(0xFF94A3B8),
                title: l10n.terms,
                onTap: () => _showTermsOfService(context),
              ),
              const _GroupDivider(),
              _SettingsTile(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFFBBF24),
                title: l10n.rateApp,
                onTap: () => _rateApp(context),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // App Branding Footer
          Center(
            child: Column(
              children: [
                Text(
                  'REPP — Level Up Your Strength',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (Build 1)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnitsDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        String currentUnit = settings.units;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.straighten_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.units, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _UnitSelectionTile(
                    title: 'Metric',
                    subtitle: 'Kilograms (kg), Kilometers (km)',
                    icon: Icons.fitness_center_rounded,
                    isSelected: currentUnit == 'metric',
                    isDark: isDark,
                    onTap: () async {
                      setDialogState(() => currentUnit = 'metric');
                      await settings.setUnits('metric');
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                  ),
                  const SizedBox(height: 10),
                  _UnitSelectionTile(
                    title: 'Imperial',
                    subtitle: 'Pounds (lbs), Miles (mi)',
                    icon: Icons.scale_rounded,
                    isSelected: currentUnit == 'imperial',
                    isDark: isDark,
                    onTap: () async {
                      setDialogState(() => currentUnit = 'imperial');
                      await settings.setUnits('imperial');
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(l10n.cancel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRestTimerDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final initialSeconds = settingsProvider.restTimerSeconds;
    final initialMinutes = initialSeconds ~/ 60;
    final initialSecs = initialSeconds % 60;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          int selectedMinutes = initialMinutes;
          int selectedSeconds = initialSecs;

          final minutesController = FixedExtentScrollController(initialItem: initialMinutes);
          final secondsController = FixedExtentScrollController(initialItem: (initialSecs ~/ 5).clamp(0, 11));

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_rounded, color: Color(0xFFFBBF24), size: 20),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.defaultRestTimer, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick preset pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [30, 60, 90, 120, 180].map((presetSecs) {
                    final label = presetSecs < 60
                        ? '${presetSecs}s'
                        : presetSecs % 60 == 0
                            ? '${presetSecs ~/ 60}m'
                            : '${presetSecs ~/ 60}m ${presetSecs % 60}s';
                    final isCurrent = (selectedMinutes * 60 + selectedSeconds) == presetSecs;
                    return ChoiceChip(
                      label: Text(label, style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent ? Colors.black : null,
                      )),
                      selected: isCurrent,
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                      onSelected: (selected) {
                        if (selected) {
                          setDialogState(() {
                            selectedMinutes = presetSecs ~/ 60;
                            selectedSeconds = presetSecs % 60;
                            minutesController.jumpToItem(selectedMinutes);
                            secondsController.jumpToItem(selectedSeconds ~/ 5);
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Live Display Timer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${selectedMinutes.toString().padLeft(2, '0')}:${selectedSeconds.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Scroll wheel pickers
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minutes
                    Expanded(
                      child: Column(
                        children: [
                          Text('MINUTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 130,
                            child: ListWheelScrollView(
                              controller: minutesController,
                              itemExtent: 38,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setDialogState(() => selectedMinutes = index);
                              },
                              children: List.generate(
                                11,
                                (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    // Seconds
                    Expanded(
                      child: Column(
                        children: [
                          Text('SECONDS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 130,
                            child: ListWheelScrollView(
                              controller: secondsController,
                              itemExtent: 38,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setDialogState(() => selectedSeconds = index * 5);
                              },
                              children: List.generate(
                                12,
                                (index) => Center(
                                  child: Text(
                                    (index * 5).toString().padLeft(2, '0'),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final totalSeconds = selectedMinutes * 60 + selectedSeconds;
                  settingsProvider.setRestTimerSeconds(totalSeconds == 0 ? 30 : totalSeconds);
                  Navigator.pop(dialogContext);
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _exportData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(context.l10n.comingSoonExport)),
          ],
        ),
      ),
    );
  }

  void _importData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(context.l10n.comingSoonImport)),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF34D399).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.translate_rounded, color: Color(0xFF34D399), size: 20),
            ),
            const SizedBox(width: 12),
            Text(l10n.selectLanguage, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: AppLocalizations.supportedLocales.map((locale) {
                final code = locale.languageCode;
                final english = l10n.languageName(code);
                final native = AppLocalizations.nativeLanguageNames[code] ?? english;
                final isSelected = settings.languageCode == code;

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    await settings.setLanguageCode(code);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                          : (isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.4) : AppColors.lightSurfaceVariant),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                native,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                              if (native != english)
                                Text(
                                  english,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.clearDataTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(
          l10n.clearDataBody,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _clearAllAppData(context);
            },
            child: Text(l10n.clearAll, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllAppData(BuildContext context) async {
    final workoutProvider = context.read<WorkoutProvider>();
    final routineProvider = context.read<RoutineProvider>();
    final historyProvider = context.read<HistoryProvider>();
    final playerProvider = context.read<PlayerProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final themeProvider = context.read<ThemeProvider>();
    final dailyQuestProvider = context.read<DailyQuestProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await DatabaseService().clearAllData();
      await Future.wait([
        settingsProvider.resetToDefaults(),
        themeProvider.resetToDefaults(),
        dailyQuestProvider.reset(),
      ]);

      await Future.wait([
        workoutProvider.initialize(),
        routineProvider.loadRoutines(),
        historyProvider.refresh(),
        playerProvider.refresh(),
        ExerciseService().reload(),
      ]);

      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.success,
          content: Text(context.l10n.clearDataSuccess),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: AppColors.error,
          content: Text('${context.l10n.clearDataFailed} $e'),
        ),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Repp',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.fitness_center_rounded, color: Colors.black, size: 28),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Repp is a mobile-only, offline-first workout tracking app powered by on-device AI form analysis, gamified Solo-Leveling hunter ranks, and interactive stick-figure visual guides.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
    );
  }

  void _showTermsOfService(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
    );
  }

  void _rateApp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(context.l10n.thanksSupport),
      ),
    );
  }
}

/// Category section header with uppercase label and subtle icon
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero Profile Card with Hunter Level & Edit Button
class _ProfileHeader extends StatelessWidget {
  final PlayerProvider player;
  final SettingsProvider settings;

  const _ProfileHeader({required this.player, required this.settings});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightDivider,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Level Ring
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          primary,
                          primary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.person_rounded, size: 36, color: onPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primary, width: 1.5),
                    ),
                    child: Text(
                      'L${player.level}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Name & Hunter Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            settings.username,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Edit Name',
                          onPressed: () => _showEditNameDialog(context, settings),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Hunter rank badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'Rank ${player.rankLetter}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          player.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // View Hunter Profile Button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                tooltip: 'Hunter Profile & Stats',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayerProfileScreen()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 14),
          // XP Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: player.progressPercent.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(primary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'XP: ${player.xpInCurrentLevel} / ${player.xpToNextLevel}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                '${(player.progressPercent * 100).toInt()}% to Level ${player.level + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final controller = TextEditingController(text: settings.username);
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Display Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          maxLength: 24,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your hunter name',
            labelText: 'Display Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                await settings.setUsername(trimmed);
              }
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Unified Streak & Performance Stats Card
class _StreakAndStatsSection extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int totalWorkouts;
  final double totalVolume;
  final int totalSets;

  const _StreakAndStatsSection({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalWorkouts,
    required this.totalVolume,
    required this.totalSets,
  });

  String _formatVolume(double volume) {
    if (volume >= 1000000) {
      return '${(volume / 1000000).toStringAsFixed(1)}M';
    } else if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}k';
    }
    return volume.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightDivider,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top: Streaks Row
          Row(
            children: [
              Expanded(
                child: _StreakStatTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFB923C),
                  title: '$currentStreak Days',
                  subtitle: context.l10n.currentStreak,
                  isHighlighted: currentStreak > 0,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StreakStatTile(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFFBBF24),
                  title: '$longestStreak Days',
                  subtitle: context.l10n.longestStreak,
                  isHighlighted: longestStreak > 0,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          const SizedBox(height: 12),

          // Bottom: Workout Metrics Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricItem(
                value: '$totalWorkouts',
                label: context.l10n.workouts,
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF38BDF8),
              ),
              _MetricItem(
                value: '${_formatVolume(totalVolume)} kg',
                label: context.l10n.volume,
                icon: Icons.trending_up_rounded,
                color: const Color(0xFF34D399),
              ),
              _MetricItem(
                value: '$totalSets',
                label: context.l10n.sets,
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFFA78BFA),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isHighlighted;
  final bool isDark;

  const _StreakStatTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isHighlighted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? iconColor.withValues(alpha: 0.1)
            : (isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? iconColor.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: isHighlighted ? iconColor : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _MetricItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Appearance Settings Card
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showOledToggle = themeProvider.isDarkMode;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightDivider,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeProvider.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.brightness_6_rounded, size: 18, color: themeProvider.accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.theme,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ThemeModeSelector(),
          if (showOledToggle) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
            const SizedBox(height: 10),
            _SettingsSwitchTile(
              icon: Icons.dark_mode_rounded,
              iconColor: const Color(0xFF818CF8),
              title: l10n.oledDarkMode,
              subtitle: l10n.oledSubtitle,
              value: themeProvider.useOledDark,
              onChanged: (value) => themeProvider.setUseOledDark(value),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          const SizedBox(height: 14),

          // Accent Color Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeProvider.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.palette_rounded, size: 18, color: themeProvider.accentColor),
              ),
              const SizedBox(width: 10),
              const Text(
                'Accent Color',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Personalize buttons, badges, and highlighted indicators',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const _AccentColorGrid(),
        ],
      ),
    );
  }
}

/// 4x2 Grid of Accent Colors: 7 Presets + 1 Custom Color Chooser
class _AccentColorGrid extends StatelessWidget {
  const _AccentColorGrid();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentAccent = themeProvider.accentColor;
    final presets = ThemeProvider.presetAccentColors;

    // Check if the current accent matches any of the 7 presets
    final isCustomColor = !presets.any((c) => c.toARGB32() == currentAccent.toARGB32());

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.0, // Perfectly square slots for circular round buttons
      ),
      itemBuilder: (context, index) {
        if (index < 7) {
          final color = presets[index];
          final isSelected = color.toARGB32() == currentAccent.toARGB32();

          return _ColorPresetItem(
            color: color,
            isSelected: isSelected,
            onTap: () => themeProvider.setAccentColor(color),
          );
        }

        // 8th item: Multi-color gradient / custom chooser
        return _CustomColorPickerItem(
          currentColor: currentAccent,
          isCustomActive: isCustomColor,
          onTap: () => _showCustomColorDialog(context, themeProvider, currentAccent),
        );
      },
    );
  }

  void _showCustomColorDialog(
    BuildContext context,
    ThemeProvider themeProvider,
    Color initialColor,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _CustomColorDialog(
        initialColor: initialColor,
        onColorSelected: (newColor) {
          themeProvider.setAccentColor(newColor);
        },
      ),
    );
  }
}

/// Circular round preset color button with selection ring and checkmark
class _ColorPresetItem extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorPresetItem({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A1A);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08)),
              width: isSelected ? 3.0 : 1.5,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: isSelected
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: 22,
                    color: iconColor,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// 8th Item: Circular Custom Color Button with Multi-color Rainbow Gradient
class _CustomColorPickerItem extends StatelessWidget {
  final Color currentColor;
  final bool isCustomActive;
  final VoidCallback onTap;

  const _CustomColorPickerItem({
    required this.currentColor,
    required this.isCustomActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFEF4444),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Color(0xFF06B6D4),
                Color(0xFF3B82F6),
                Color(0xFF8B5CF6),
                Color(0xFFEC4899),
                Color(0xFFEF4444),
              ],
            ),
            border: Border.all(
              color: isCustomActive
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08)),
              width: isCustomActive ? 3.0 : 1.5,
            ),
            boxShadow: [
              if (isCustomActive)
                BoxShadow(
                  color: currentColor.withValues(alpha: 0.55),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isCustomActive
                  ? currentColor
                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCustomActive
                  ? Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: ThemeData.estimateBrightnessForColor(currentColor) == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF1A1A1A),
                    )
                  : ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEC4899), Color(0xFF3B82F6)],
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.colorize_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Color Chooser Dialog with Interactive Color Wheel + Palette Swatches + Hex Code Input
class _CustomColorDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const _CustomColorDialog({
    required this.initialColor,
    required this.onColorSelected,
  });

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late Color _selectedColor;
  late TextEditingController _hexController;
  String? _hexError;

  // Extended spectrum swatches for quick custom selection
  static const List<Color> _swatchPalette = [
    Color(0xFFFF3B30), // Red
    Color(0xFFFF9500), // Orange
    Color(0xFFFFCC00), // Amber Gold
    Color(0xFF34C759), // Green
    Color(0xFF00C7BE), // Mint Teal
    Color(0xFF30B0C7), // Aqua
    Color(0xFF007AFF), // Deep Sky
    Color(0xFF5856D6), // Indigo
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF2D55), // Hot Coral Pink
    Color(0xFFA2845E), // Bronze
    Color(0xFF8E8E93), // Titanium Silver
    Color(0xFFE11D48), // Crimson Rose
    Color(0xFF7C3AED), // Violet Dark
    Color(0xFF059669), // Forest Emerald
    Color(0xFF0284C7), // Ocean Blue
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    return color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
  }

  void _onHexChanged(String val) {
    final cleaned = val.replaceAll('#', '').trim();
    if (cleaned.length == 6) {
      final intVal = int.tryParse(cleaned, radix: 16);
      if (intVal != null) {
        setState(() {
          _selectedColor = Color(0xFF000000 | intVal);
          _hexError = null;
        });
        return;
      }
    }
    setState(() {
      _hexError = cleaned.isEmpty ? null : 'Invalid 6-digit hex';
    });
  }

  void _onWheelColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
      _hexController.text = _colorToHex(color);
      _hexError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
      title: Row(
        children: [
          Icon(Icons.palette_rounded, size: 22, color: _selectedColor),
          const SizedBox(width: 8),
          const Text('Custom Accent Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Bar
            Container(
              height: 46,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _selectedColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '#${_colorToHex(_selectedColor)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: ThemeData.estimateBrightnessForColor(_selectedColor) == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hex Code Input
            Text(
              'ENTER HEX CODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _hexController,
              maxLength: 7,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                prefixText: '# ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                counterText: '',
                errorText: _hexError,
                hintText: 'FACC15',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _onHexChanged,
            ),
            const SizedBox(height: 16),

            // Interactive Color Wheel
            Text(
              'COLOR SPECTRUM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _InteractiveColorWheel(
                color: _selectedColor,
                onColorChanged: _onWheelColorChanged,
                size: 190,
              ),
            ),
            const SizedBox(height: 16),

            // Swatches Palette
            Text(
              'PRESET SWATCHES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _swatchPalette.map((color) {
                final isSelected = color.toARGB32() == _selectedColor.toARGB32();
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _hexController.text = _colorToHex(color);
                      _hexError = null;
                    });
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        width: isSelected ? 2.5 : 0,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1A1A1A),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _selectedColor,
            foregroundColor: ThemeData.estimateBrightnessForColor(_selectedColor) == Brightness.dark
                ? Colors.white
                : const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            widget.onColorSelected(_selectedColor);
            Navigator.pop(context);
          },
          child: const Text('Apply Accent', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// Interactive circular HSV color wheel with touch and drag indicator
class _InteractiveColorWheel extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onColorChanged;
  final double size;

  const _InteractiveColorWheel({
    required this.color,
    required this.onColorChanged,
    this.size = 190,
  });

  @override
  State<_InteractiveColorWheel> createState() => _InteractiveColorWheelState();
}

class _InteractiveColorWheelState extends State<_InteractiveColorWheel> {
  void _handleGesture(Offset localPosition, double radius) {
    final center = Offset(radius, radius);
    final offset = localPosition - center;
    final distance = offset.distance;

    // Calculate angle in degrees [0, 360)
    // atan2 gives [-pi, pi] starting from positive x-axis
    double angle = math.atan2(offset.dy, offset.dx) * 180 / math.pi;
    if (angle < 0) {
      angle += 360;
    }

    // Saturation is clamped [0.0, 1.0] from center to edge
    final saturation = (distance / radius).clamp(0.0, 1.0);
    final value = 0.95; // Keep bright and vibrant for accent colors

    final hsv = HSVColor.fromAHSV(1.0, angle, saturation, value);
    widget.onColorChanged(hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(widget.color);
    final radius = widget.size / 2;

    // Calculate position of the indicator thumb
    final angleRad = hsv.hue * math.pi / 180;
    final dist = hsv.saturation * radius;
    final thumbX = radius + dist * math.cos(angleRad);
    final thumbY = radius + dist * math.sin(angleRad);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        onPanDown: (details) => _handleGesture(details.localPosition, radius),
        onPanUpdate: (details) => _handleGesture(details.localPosition, radius),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _ColorWheelPainter(),
            ),
            // Selection indicator ring / thumb
            Positioned(
              left: thumbX - 12,
              top: thumbY - 12,
              child: IgnorePointer(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Hue sweep gradient around full 360 degrees
    final sweepColors = List<Color>.generate(361, (i) {
      return HSVColor.fromAHSV(1.0, i.toDouble(), 1.0, 1.0).toColor();
    });

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: sweepColors,
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // 2. Radial gradient from center (white / saturation 0) to transparent edge (saturation 1)
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: const [Colors.white, Color(0x00FFFFFF)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, radialPaint);

    // 3. Subtle inner border for crisp finish
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Modern segmented pill selector for System / Light / Dark
class _ThemeModeSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant.withValues(alpha: 0.6)
            : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ThemeModePill(
            icon: Icons.brightness_auto_rounded,
            label: context.l10n.system,
            isSelected: themeProvider.themeMode == AppThemeMode.system,
            onTap: () => themeProvider.setThemeMode(AppThemeMode.system),
          ),
          _ThemeModePill(
            icon: Icons.light_mode_rounded,
            label: context.l10n.light,
            isSelected: themeProvider.themeMode == AppThemeMode.light,
            onTap: () => themeProvider.setThemeMode(AppThemeMode.light),
          ),
          _ThemeModePill(
            icon: Icons.dark_mode_rounded,
            label: context.l10n.dark,
            isSelected: themeProvider.themeMode == AppThemeMode.dark,
            onTap: () => themeProvider.setThemeMode(AppThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeModePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModePill({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final onPrimaryColor = theme.colorScheme.onPrimary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? onPrimaryColor
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? onPrimaryColor
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouped Settings Container (iOS / One UI styled rounded card)
class _SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightDivider,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 1,
        thickness: 0.7,
        color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
      ),
    );
  }
}

/// Rich Settings Item with colored icon chip and trailing value pill
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? valueBadge;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.valueBadge,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Colored Icon Chip
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? AppColors.error : null,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing Value Badge & Chevron
              if (valueBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    valueBadge!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings item with inline switch
class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.black,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Unit selection card tile inside dialog
class _UnitSelectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _UnitSelectionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
