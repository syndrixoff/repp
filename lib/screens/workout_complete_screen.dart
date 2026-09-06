import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

/// Full-screen reward overlay shown after completing a workout
class WorkoutCompleteScreen extends StatefulWidget {
  final XPAwardResult xpResult;
  final Workout workout;

  const WorkoutCompleteScreen({
    super.key,
    required this.xpResult,
    required this.workout,
  });

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _xpCountController;
  late AnimationController _levelUpController;
  late AnimationController _pulseController;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _xpCount;
  late Animation<double> _levelUpScale;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _xpCountController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _levelUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideUp = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _xpCount = Tween<double>(
      begin: 0.0,
      end: widget.xpResult.totalXPGained.toDouble(),
    ).animate(
      CurvedAnimation(parent: _xpCountController, curve: Curves.easeOutCubic),
    );

    _levelUpScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _levelUpController, curve: Curves.elasticOut),
    );

    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sequence the animations
    _entranceController.forward().then((_) {
      _xpCountController.forward().then((_) {
        if (widget.xpResult.didLevelUp) {
          _levelUpController.forward();
        }
        _pulseController.repeat(reverse: true);
      });
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _xpCountController.dispose();
    _levelUpController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.xpResult;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: AnimatedBuilder(
            animation: _slideUp,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _slideUp.value),
              child: child,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // System header
                  _SystemHeader(),

                  const SizedBox(height: 32),

                  // XP gained — big animated number
                  _XPGainedCard(
                    animation: _xpCount,
                    totalXP: result.totalXPGained,
                  ),

                  const SizedBox(height: 24),

                  // Level-up notification
                  if (result.didLevelUp)
                    _LevelUpCard(
                      scaleAnimation: _levelUpScale,
                      newLevel: result.newLevel,
                      newTitle: result.newTitle ?? '',
                    ),

                  if (result.didLevelUp) const SizedBox(height: 24),

                  // XP breakdown
                  _XPBreakdownCard(result: result),

                  const SizedBox(height: 20),

                  // Muscle XP gains
                  if (result.muscleXPGains.isNotEmpty)
                    _MuscleXPCard(muscleGains: result.muscleXPGains),

                  if (result.muscleXPGains.isNotEmpty)
                    const SizedBox(height: 20),

                  // XP progress bar
                  _XPProgressCard(
                    level: result.newLevel,
                    currentXP: LevelSystem.xpInCurrentLevel(result.newTotalXP),
                    neededXP: LevelSystem.xpToNextLevel(result.newTotalXP),
                    progress: LevelSystem.progressPercent(result.newTotalXP),
                  ),

                  const SizedBox(height: 32),

                  // Continue button
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) => Transform.scale(
                      scale: _pulse.value,
                      child: child,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.systemBlue,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: AppColors.systemBlue.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'CONTINUE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// Sub-widgets
// ============================================================

class _SystemHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.systemPanelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.systemBlue.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.systemBlue.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, color: AppColors.systemBlue, size: 18),
          const SizedBox(width: 10),
          Text(
            '[ SYSTEM ]  Dungeon Cleared',
            style: TextStyle(
              color: AppColors.systemBlue,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _XPGainedCard extends StatelessWidget {
  final Animation<double> animation;
  final int totalXP;

  const _XPGainedCard({required this.animation, required this.totalXP});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.xpGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Text(
            'XP GAINED',
            style: TextStyle(
              color: AppColors.xpGreen.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) => Text(
              '+${animation.value.toInt()}',
              style: TextStyle(
                color: AppColors.xpGreen,
                fontSize: 56,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                shadows: [
                  Shadow(
                    color: AppColors.xpGreen.withValues(alpha: 0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelUpCard extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final int newLevel;
  final String newTitle;

  const _LevelUpCard({
    required this.scaleAnimation,
    required this.newLevel,
    required this.newTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.systemGold.withValues(alpha: 0.15),
              AppColors.systemGoldDark.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.systemGold.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.systemGold.withValues(alpha: 0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.arrow_upward_rounded, color: AppColors.systemGold, size: 32),
            const SizedBox(height: 8),
            Text(
              'LEVEL UP',
              style: TextStyle(
                color: AppColors.systemGold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    color: AppColors.systemGold.withValues(alpha: 0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Level $newLevel',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              newTitle,
              style: TextStyle(
                color: AppColors.systemPurple,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XPBreakdownCard extends StatelessWidget {
  final XPAwardResult result;

  const _XPBreakdownCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final items = <_BreakdownItem>[
      if (result.setXP > 0)
        _BreakdownItem('Sets Completed', '+${result.setXP}', Icons.check_circle_outline),
      if (result.repsXP > 0)
        _BreakdownItem('Rep Bonus', '+${result.repsXP}', Icons.repeat_rounded),
      if (result.weightXP > 0)
        _BreakdownItem('Weight Bonus', '+${result.weightXP}', Icons.fitness_center_rounded),
      _BreakdownItem('Workout Complete', '+${result.completionXP}', Icons.emoji_events_outlined),
      if (result.streakXP > 0)
        _BreakdownItem('Streak Bonus', '+${result.streakXP}', Icons.local_fire_department),
      if (result.prXP > 0)
        _BreakdownItem('PR Bonus', '+${result.prXP}', Icons.star_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BREAKDOWN',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(item.icon, color: AppColors.systemBlue, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: Colors.grey.shade300,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  item.value,
                  style: TextStyle(
                    color: AppColors.xpGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _BreakdownItem {
  final String label;
  final String value;
  final IconData icon;
  _BreakdownItem(this.label, this.value, this.icon);
}

class _MuscleXPCard extends StatelessWidget {
  final Map<String, int> muscleGains;

  const _MuscleXPCard({required this.muscleGains});

  @override
  Widget build(BuildContext context) {
    final sorted = muscleGains.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxXP = sorted.first.value.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MUSCLE XP',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.map((entry) {
            final progress = maxXP > 0 ? entry.value / maxXP : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.getMuscleColor(entry.key),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '+${entry.value}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.xpGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _XPProgressCard extends StatelessWidget {
  final int level;
  final int currentXP;
  final int neededXP;
  final double progress;

  const _XPProgressCard({
    required this.level,
    required this.currentXP,
    required this.neededXP,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level $level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Level ${level + 1}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.xpBarGradient,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.systemBlue.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$currentXP / $neededXP XP',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
