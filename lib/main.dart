import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/workout_provider.dart';
import 'providers/routine_provider.dart';
import 'providers/history_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/player_provider.dart';
import 'providers/daily_quest_provider.dart';
import 'providers/ai_coach_provider.dart';
import 'services/exercise_service.dart';
import 'ai/local_llm_service.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'screens/home_screen.dart';
import 'l10n/app_localizations.dart';
import 'theme/light_theme.dart';
import 'theme/dark_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize on-device inference engine for local AI
  try {
    await FlutterGemma.initialize(
      inferenceEngines: const [LiteRtLmEngine()],
    );
  } catch (e) {
    debugPrint('AI engine initialization warning: $e');
  }

  // Initialize theme provider first
  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Initialize settings provider
  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  // Pre-load exercises
  await ExerciseService().loadExercises();

  // Pre-warm LLM on standby if model is downloaded so it is instantly responsive
  unawaited(LlmServiceFactory.create());

  // Initialize background downloader task tracking and persistent service
  unawaited(ModelDownloadService().init());

  runApp(
    ReppApp(themeProvider: themeProvider, settingsProvider: settingsProvider),
  );
}

class ReppApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final SettingsProvider settingsProvider;

  const ReppApp({
    super.key,
    required this.themeProvider,
    required this.settingsProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()..initialize()),
        ChangeNotifierProvider(
          create: (_) => RoutineProvider()..loadRoutines(),
        ),
        ChangeNotifierProvider(create: (_) => HistoryProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()..initialize()),
        ChangeNotifierProvider(
          create: (_) => DailyQuestProvider()..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => AiCoachProvider(
            routineProvider: context.read<RoutineProvider>(),
          ),
        ),
      ],
      child: const _ThemedApp(),
    );
  }
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    // Build themes based on provider settings
    final lightTheme = LightTheme.build(
      primaryColor: themeProvider.accentColor,
    );

    final darkTheme = DarkTheme.build(
      primaryColor: themeProvider.accentColor,
      useOled: themeProvider.useOledDark,
    );

    // Update system UI overlay style based on theme
    final isDark = themeProvider.isDarkMode;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );

    // Enable edge-to-edge on Android
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.effectiveThemeMode,
      locale: settingsProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, supportedLocales) {
        for (final locale in locales ?? []) {
          if (supportedLocales.any(
            (supported) => supported.languageCode == locale.languageCode,
          )) {
            return locale;
          }
        }

        return const Locale('en');
      },
      home: const HomeScreen(),
      builder: (context, child) {
        // Apply global settings like text scaling limits
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.3),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
