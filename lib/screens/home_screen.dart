import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/workout_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import 'workout_tab.dart';
import 'history_tab.dart';
import 'guided_workout_screen.dart';
import 'quests_tab.dart';
import 'profile_tab.dart';
import 'ai_coach_screen.dart';
import 'nutrition_tab.dart';
import '../providers/settings_provider.dart';
import '../ai/local_llm_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static _HomeScreenState? _activeState;

  static void switchTab(BuildContext? context, int index) {
    if (_activeState != null && _activeState!.mounted) {
      _activeState!._navigateToTab(index);
      return;
    }
    if (context != null && context.mounted) {
      try {
        final state = context.findAncestorStateOfType<_HomeScreenState>();
        state?._navigateToTab(index);
      } catch (_) {}
    }
  }

  static void switchToAiTab([BuildContext? context]) {
    if (_activeState != null && _activeState!.mounted) {
      _activeState!._navigateToTab(3, showAiTab: true);
      return;
    }
    if (context != null && context.mounted) {
      try {
        final state = context.findAncestorStateOfType<_HomeScreenState>();
        state?._navigateToTab(3, showAiTab: true);
      } catch (_) {}
    }
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isModelDownloaded = false;
  bool _lastShowAiTab = false;
  StreamSubscription<bool>? _downloadStatusSub;

  @override
  void initState() {
    super.initState();
    HomeScreen._activeState = this;
    _checkModelStatus();
    _downloadStatusSub = ModelDownloadService().statusStream.listen((_) {
      _checkModelStatus();
    });
  }

  @override
  void dispose() {
    if (HomeScreen._activeState == this) {
      HomeScreen._activeState = null;
    }
    _downloadStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    final downloaded = await ModelDownloadService().isModelDownloaded();
    if (mounted && downloaded != _isModelDownloaded) {
      setState(() {
        _isModelDownloaded = downloaded;
      });
    }
  }

  List<Widget> _getTabs(bool showAiTab) {
    if (showAiTab) {
      return const [
        WorkoutTab(),
        HistoryTab(),
        NutritionTab(),
        AiCoachScreen(),
        QuestsTab(),
        ProfileTab(),
      ];
    }
    return const [
      WorkoutTab(),
      HistoryTab(),
      NutritionTab(),
      QuestsTab(),
      ProfileTab(),
    ];
  }

  void _navigateToTab(int index, {bool? showAiTab}) {
    if (showAiTab == true) {
      final settings = context.read<SettingsProvider>();
      if (!settings.aiFeatureEnabled) {
        settings.setAiFeatureEnabled(true);
      }
      _lastShowAiTab = true;
    }

    final effectiveShowAi = showAiTab ??
        (_isModelDownloaded ||
            ModelDownloadService().isDownloading ||
            context.read<SettingsProvider>().aiFeatureEnabled);
    final tabsLength = _getTabs(effectiveShowAi).length;
    if (index < 0 || index >= tabsLength) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final isDownloading = ModelDownloadService().isDownloading;
    final isDownloaded = _isModelDownloaded || ModelDownloadService().isDownloaded;
    final showAiTab = isDownloaded || isDownloading || settingsProvider.aiFeatureEnabled;

    // Smoothly preserve the active tab when the AI Coach tab is dynamically added or removed
    if (_lastShowAiTab != showAiTab) {
      if (showAiTab && !_lastShowAiTab) {
        // AI tab inserted at index 3: shift tabs from index 3 and above by +1
        if (_currentIndex >= 3) {
          _currentIndex += 1;
        }
      } else if (!showAiTab && _lastShowAiTab) {
        // AI tab removed from index 3:
        if (_currentIndex == 3) {
          _currentIndex = 0; // Fallback to Workout tab if user was on AI Coach
        } else if (_currentIndex > 3) {
          _currentIndex -= 1;
        }
      }
      _lastShowAiTab = showAiTab;
    }

    final tabs = _getTabs(showAiTab);

    if (_currentIndex >= tabs.length) {
      _currentIndex = tabs.length - 1;
    }

    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: _GlassNavigationBar(
        currentIndex: _currentIndex,
        aiEnabled: showAiTab,
        onTap: (i) => _navigateToTab(i, showAiTab: showAiTab),
        onSlideLeft: () =>
            _navigateToTab((_currentIndex + 1) % tabs.length, showAiTab: showAiTab),
        onSlideRight: () => _navigateToTab(
            (_currentIndex - 1 + tabs.length) % tabs.length,
            showAiTab: showAiTab),
      ),
      // Show floating action button when workout is active
      floatingActionButton:
          workoutProvider.hasActiveWorkout && _currentIndex != 0
              ? FloatingActionButton.extended(
                  onPressed: () {
                    final isRoutineWorkout =
                        workoutProvider.activeWorkout?.routineId != null;
                    if (isRoutineWorkout) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const GuidedWorkoutScreen(),
                        ),
                      );
                    } else {
                      _navigateToTab(0, showAiTab: showAiTab);
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    workoutProvider.activeWorkout?.durationString ?? 'Resume',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: const Color(0xFF1A1A1A),
                )
              : null,
    );
  }
}

/// Glassmorphism navigation bar with blur effect
class _GlassNavigationBar extends StatelessWidget {
  final int currentIndex;
  final bool aiEnabled;
  final ValueChanged<int> onTap;
  final VoidCallback onSlideLeft;
  final VoidCallback onSlideRight;

  const _GlassNavigationBar({
    required this.currentIndex,
    required this.aiEnabled,
    required this.onTap,
    required this.onSlideLeft,
    required this.onSlideRight,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOled = themeProvider.useOledDark && isDark;
    // Glassy translucency with visible frosted background content underneath
    final backgroundColor = isDark
        ? (isOled
              ? Colors.black.withValues(alpha: 0.58)
              : const Color(0xFF0F172A).withValues(alpha: 0.62))
        : Colors.white.withValues(alpha: 0.68);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: isOled ? 0.14 : 0.18)
        : Colors.white.withValues(alpha: 0.60);
    final navShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : const Color(0xFF64748B).withValues(alpha: 0.12);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: navShadowColor,
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragEnd: (details) {
                    final vx = details.velocity.pixelsPerSecond.dx;
                    if (vx < -120) onSlideLeft();
                    if (vx > 120) onSlideRight();
                  },
                  child: _SyndrixNavBar(
                    currentIndex: currentIndex,
                    aiEnabled: aiEnabled,
                    onTap: onTap,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Syndrix-style navbar pill transition widget.
/// The active pill physically slides and stretches across tabs using asymmetric
/// leading and trailing cubic-bezier curves (cubic-bezier(0.25, 1, 0.5, 1) with 50ms stagger),
/// creating the signature organic liquid glide on press.
class _SyndrixNavBar extends StatefulWidget {
  final int currentIndex;
  final bool aiEnabled;
  final ValueChanged<int> onTap;

  const _SyndrixNavBar({
    required this.currentIndex,
    required this.aiEnabled,
    required this.onTap,
  });

  @override
  State<_SyndrixNavBar> createState() => _SyndrixNavBarState();
}

class _SyndrixNavBarState extends State<_SyndrixNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _leadingAnimation;
  late Animation<double> _trailingAnimation;
  int _prevIndex = 0;
  int? _pressedIndex;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _setupAnimations(_prevIndex.toDouble(), widget.currentIndex.toDouble());
  }

  void _setupAnimations(double from, double to) {
    final isMovingRight = to >= from;

    // Syndrix exact curves:
    // Moving Right: leading edge has a 50ms delay with cubic-bezier(0.25, 1, 0.5, 1) [380ms],
    // trailing edge starts immediately with cubic-bezier(0.25, 1, 0.5, 1) [320ms].
    // Moving Left: leading edge starts immediately [320ms], trailing edge has a 50ms delay [380ms].
    const syndrixCubic = Cubic(0.25, 1.0, 0.5, 1.0);

    if (isMovingRight) {
      // Right edge stretches out first (0.0 -> 0.84 of duration = ~320ms)
      _trailingAnimation = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.84, curve: syndrixCubic),
        ),
      );
      // Left edge catches up after a 50ms stagger (0.13 -> 1.0 of duration = 380ms)
      _leadingAnimation = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.13, 1.0, curve: syndrixCubic),
        ),
      );
    } else {
      // Left edge stretches out first (0.0 -> 0.84 of duration = ~320ms)
      _leadingAnimation = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.84, curve: syndrixCubic),
        ),
      );
      // Right edge catches up after a 50ms stagger (0.13 -> 1.0 of duration = 380ms)
      _trailingAnimation = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.13, 1.0, curve: syndrixCubic),
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant _SyndrixNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final from = _prevIndex.toDouble();
      final to = widget.currentIndex.toDouble();
      _prevIndex = widget.currentIndex;
      _setupAnimations(from, to);
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    final inactiveColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final items = <_NavItemData>[
      const _NavItemData(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, targetIndex: 0),
      const _NavItemData(icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, targetIndex: 1),
      const _NavItemData(icon: Icons.restaurant_outlined, selectedIcon: Icons.restaurant_rounded, targetIndex: 2),
      if (widget.aiEnabled)
        const _NavItemData(icon: Icons.auto_awesome_outlined, selectedIcon: Icons.auto_awesome_rounded, targetIndex: 3),
      _NavItemData(icon: Icons.flag_outlined, selectedIcon: Icons.flag_rounded, targetIndex: widget.aiEnabled ? 4 : 3),
      _NavItemData(icon: Icons.person_outline, selectedIcon: Icons.person, targetIndex: widget.aiEnabled ? 5 : 4),
    ];

    final itemCount = items.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final slotWidth = totalWidth / itemCount;

        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Floating Syndrix sliding & stretching indicator pill
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final leftIndex = _controller.isAnimating
                    ? _leadingAnimation.value
                    : widget.currentIndex.toDouble();
                final rightIndex = _controller.isAnimating
                    ? _trailingAnimation.value
                    : widget.currentIndex.toDouble();

                final leftEdge = (leftIndex.clamp(0.0, itemCount - 1.0)) * slotWidth;
                final rightEdge = (rightIndex.clamp(0.0, itemCount - 1.0) + 1.0) * slotWidth;
                final pillWidth = (rightEdge - leftEdge).clamp(slotWidth * 0.7, totalWidth);

                return Positioned(
                  left: leftEdge + (slotWidth - 44) / 2,
                  width: pillWidth - (slotWidth - 44),
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            // Nav bar icons row on top
            Row(
              children: items.map((item) {
                final isSelected = widget.currentIndex == item.targetIndex;
                final isPressed = _pressedIndex == item.targetIndex;

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _pressedIndex = item.targetIndex),
                    onTapCancel: () => setState(() => _pressedIndex = null),
                    onTapUp: (_) => setState(() => _pressedIndex = null),
                    onTap: () => widget.onTap(item.targetIndex),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      scale: isPressed ? 0.92 : 1.0,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutBack,
                            scale: isSelected ? 1.08 : 0.95,
                            child: Icon(
                              isSelected ? item.selectedIcon : item.icon,
                              color: isSelected ? onPrimary : inactiveColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final int targetIndex;

  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.targetIndex,
  });
}

