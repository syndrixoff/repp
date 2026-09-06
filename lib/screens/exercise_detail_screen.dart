import 'package:flutter/material.dart';

import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/history_provider.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _isPlaying = false;
  ExercisePRs? _prs;
  List<Map<String, dynamic>> _history = [];
  bool _historyLoaded = false;

  late TabController _tabController;
  final ExerciseService _exerciseService = ExerciseService();

  Exercise? get _exercise => _exerciseService.getById(widget.exerciseId);
  bool get _hasHowTo => _exercise?.howToSteps.isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _hasHowTo ? 3 : 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPRs();
    _initializeMedia();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_historyLoaded) {
      _loadHistory();
    }
  }

  Future<void> _loadPRs() async {
    final historyProvider = context.read<HistoryProvider>();
    final prs = await historyProvider.getPRsForExercise(widget.exerciseId);
    if (mounted) {
      setState(() {
        _prs = prs;
      });
    }
  }

  Future<void> _loadHistory() async {
    final historyProvider = context.read<HistoryProvider>();
    final history = await historyProvider.getExerciseHistory(
      widget.exerciseId,
    );
    if (mounted) {
      setState(() {
        _history = history;
        _historyLoaded = true;
      });
    }
  }

  bool get _isImage {
    final url = _exercise?.videoUrl;
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  bool get _hasMedia {
    return _exercise?.videoUrl != null || _exercise?.thumbnailUrl != null;
  }

  Future<void> _initializeMedia() async {
    final url = _exercise?.videoUrl;
    if (url == null) return;

    if (_isImage) return;

    setState(() {
      _isVideoLoading = true;
    });

    try {
      _videoController = VideoPlayerController.asset(url);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0);
      _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ========================
  // Helpers
  // ========================
  bool _hasValidPrimaryMuscle() {
    final pm = _exercise?.primaryMuscle ?? '';
    return pm.isNotEmpty && pm != 'None';
  }

  bool _hasValidSecondaryMuscles() {
    final exercise = _exercise;
    if (exercise == null) return false;
    return exercise.secondaryMuscles.isNotEmpty &&
        !exercise.secondaryMuscles.every(
          (m) => m == 'None' || m.isEmpty,
        );
  }

  bool _hasValidEquipment() {
    final eq = _exercise?.equipment ?? '';
    return eq.isNotEmpty && eq != 'None';
  }

  Color get _muscleColor {
    return AppColors.getMuscleColor(_exercise?.primaryMuscle ?? 'Other');
  }

  // ========================
  // FULL SCREEN VIEWER
  // ========================
  void _openFullScreenMedia() {
    final exercise = _exercise;
    if (exercise == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenMediaViewer(
            exercise: exercise,
            videoController: _videoController,
            isVideo: _isVideoInitialized,
            isImage: _isImage,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ========================
  // BUILD
  // ========================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exercise = _exercise;

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise')),
        body: const Center(
          child: Text('This exercise is no longer available.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _muscleColor,
          labelColor: _muscleColor,
          unselectedLabelColor: isDark
              ? Colors.grey.shade400
              : Colors.grey.shade600,
          indicatorWeight: 3,
          tabs: [
            const Tab(text: 'Summary'),
            const Tab(text: 'History'),
            if (_hasHowTo) const Tab(text: 'How to'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildHistoryTab(),
          if (_hasHowTo) _buildHowToTab(),
        ],
      ),
    );
  }

  // ========================
  // SUMMARY TAB
  // ========================
  Widget _buildSummaryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Polished media section
          _buildMediaSection(isDark),

          // Info chips section
          _buildInfoChips(isDark),

          const SizedBox(height: 8),

          // Personal Records section
          if (_prs != null && _prs!.hasPRs) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_rounded,
                    size: 20,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Personal Records',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPRsCard(isDark),
            ),
          ],

          // "No data yet" placeholder when no PRs
          if (_prs == null || !_prs!.hasPRs) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildNoDataCard(isDark),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========================
  // MEDIA SECTION
  // ========================
  Widget _buildMediaSection(bool isDark) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mediaHeight = screenHeight * 0.38;

    return GestureDetector(
      onTap: () {
        // For videos: toggle play/pause
        if (_isVideoInitialized) {
          _togglePlayPause();
        }
        // For images: open fullscreen viewer
        else if (_hasMedia && !_isVideoLoading) {
          _openFullScreenMedia();
        }
      },
      child: Container(
        height: mediaHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background pattern
              _buildMediaBackground(isDark),

              // Actual media content
              Center(child: _buildMediaContent()),

              // Bottom gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ),

              // Pause/play icon overlay (top-right)
              if (_isVideoInitialized && !_isPlaying)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaBackground(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _muscleColor.withValues(alpha: 0.08),
            isDark ? Colors.black : const Color(0xFF1A1A2E),
            _muscleColor.withValues(alpha: 0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    // 1. Initialized video player
    if (_isVideoInitialized && _videoController != null) {
      return AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    }

    // 2. Loading video — shimmer effect
    if (_isVideoLoading) {
      return _ShimmerLoading(color: _muscleColor);
    }

    // 3. Image URL (from videoUrl if it's an image type, e.g. .gif, .jpg)
    if (_isImage && _exercise?.videoUrl != null) {
      return Hero(
        tag: 'exercise_media_${widget.exerciseId}',
        child: Image.asset(
          _exercise!.videoUrl!,
          key: ValueKey(_exercise!.videoUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      );
    }

    // 4. Thumbnail fallback
    if (_exercise?.thumbnailUrl != null) {
      return Hero(
        tag: 'exercise_media_${widget.exerciseId}',
        child: Image.asset(
          _exercise!.thumbnailUrl!,
          key: ValueKey(_exercise!.thumbnailUrl),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        ),
      );
    }

    // 5. Placeholder
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _muscleColor.withValues(alpha: 0.2),
                _muscleColor.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: _muscleColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            size: 48,
            color: _muscleColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No preview available',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ========================
  // MUSCLE INFO (text-based layout)
  // ========================
  Widget _buildInfoChips(bool isDark) {
    final hasPrimary = _hasValidPrimaryMuscle();
    final hasSecondary = _hasValidSecondaryMuscles();
    final hasEquipment = _hasValidEquipment();

    if (!hasPrimary && !hasSecondary && !hasEquipment) {
      return const SizedBox(height: 16);
    }

    final secondaryMuscles = hasSecondary
        ? _exercise!.secondaryMuscles
              .where((m) => m != 'None' && m.isNotEmpty)
              .toList()
        : <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPrimary)
            _buildMuscleRow(
              label: 'Primary',
              muscles: [_exercise!.primaryMuscle],
              isDark: isDark,
              isPrimary: true,
            ),
          if (hasSecondary) ...[
            const SizedBox(height: 8),
            _buildMuscleRow(
              label: 'Secondary',
              muscles: secondaryMuscles,
              isDark: isDark,
              isPrimary: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMuscleRow({
    required String label,
    required List<String> muscles,
    required bool isDark,
    required bool isPrimary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: muscles.map((muscle) {
              final color = AppColors.getMuscleColor(muscle);
              return _buildMuscleChip(
                label: muscle,
                color: color,
                isDark: isDark,
                isPrimary: isPrimary,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMuscleChip({
    required String label,
    required Color color,
    required bool isDark,
    required bool isPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPrimary
            ? color.withValues(alpha: isDark ? 0.2 : 0.12)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPrimary
              ? color.withValues(alpha: 0.4)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade300),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
              color: isPrimary
                  ? color
                  : (isDark ? Colors.white70 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // PRs CARD
  // ========================
  Widget _buildPRsCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.3),
          width: 1,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_prs!.maxWeight != null)
              _buildPRRow(
                'Best Set',
                _prs!.maxWeight!.formattedValue,
                Icons.fitness_center_rounded,
                isDark,
              ),
            if (_prs!.oneRepMax != null)
              _buildPRRow(
                'Est. 1RM',
                _prs!.oneRepMax!.formattedValue,
                Icons.emoji_events_rounded,
                isDark,
              ),
            if (_prs!.maxVolume != null)
              _buildPRRow(
                'Max Volume',
                _prs!.maxVolume!.formattedValue,
                Icons.trending_up_rounded,
                isDark,
              ),
            if (_prs!.maxReps != null)
              _buildPRRow(
                'Most Session Reps',
                _prs!.maxReps!.formattedValue,
                Icons.repeat_rounded,
                isDark,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRRow(String label, String value, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.amber.shade600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _muscleColor.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: _muscleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _muscleColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: _muscleColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete a workout with this exercise\nto see your personal records.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // HISTORY TAB
  // ========================
  Widget _buildHistoryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_historyLoaded) {
      _loadHistory();
      return Center(child: CircularProgressIndicator(color: _muscleColor));
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _muscleColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                size: 48,
                color: _muscleColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No history yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a workout with this exercise\nto see your history here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // Group history by workout
    final workoutGroups = <String, List<Map<String, dynamic>>>{};
    final workoutMeta = <String, Map<String, dynamic>>{};

    for (final row in _history) {
      final workoutId = row['workout_id'].toString();
      workoutGroups.putIfAbsent(workoutId, () => []);
      workoutGroups[workoutId]!.add(row);
      workoutMeta[workoutId] = row;
    }

    final workoutIds = workoutGroups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workoutIds.length,
      itemBuilder: (context, index) {
        final workoutId = workoutIds[index];
        final sets = workoutGroups[workoutId]!;
        final meta = workoutMeta[workoutId]!;

        final workoutName = meta['workout_name']?.toString() ?? 'Workout';
        final startTime = meta['start_time']?.toString();
        String dateStr = '';
        if (startTime != null) {
          try {
            final dt = DateTime.parse(startTime);
            dateStr = DateFormat('MMM d, yyyy').format(dt);
          } catch (_) {
            dateStr = startTime;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Workout header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _muscleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.fitness_center_rounded,
                        size: 16,
                        color: _muscleColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        workoutName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.grey.shade200,
                ),
                const SizedBox(height: 8),

                // Sets header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          'Set',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Weight',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Reps',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Set rows
                ...sets.asMap().entries.map((entry) {
                  final setIndex = entry.key + 1;
                  final set = entry.value;
                  final weight = set['weight'];
                  final reps = set['reps'];
                  final isCompleted = (set['is_completed'] as int?) == 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$setIndex',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isCompleted
                                  ? _muscleColor
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            weight != null
                                ? '${_formatNumber(weight)} kg'
                                : '-',
                            style: TextStyle(
                              color: isCompleted
                                  ? null
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reps != null ? '$reps' : '-',
                            style: TextStyle(
                              color: isCompleted
                                  ? null
                                  : (isDark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return '-';
    final num n = value is num ? value : num.tryParse(value.toString()) ?? 0;
    if (n == n.toInt()) return n.toInt().toString();
    return n.toStringAsFixed(1);
  }

  // ========================
  // HOW TO TAB
  // ========================
  Widget _buildHowToTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = _exercise?.howToSteps ?? const <String>[];

    if (steps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _muscleColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 48,
                color: _muscleColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No instructions available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How-to instructions for this exercise\nare not available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header with icon
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _muscleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 20,
                color: _muscleColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Instructions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Steps
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          // Strip leading number prefix like "1. " if present
          String cleanStep = step;
          final numMatch = RegExp(r'^\d+\.\s*').firstMatch(step);
          if (numMatch != null) {
            cleanStep = step.substring(numMatch.end);
          }

          final isLast = index == steps.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number with connector line
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _muscleColor,
                            _muscleColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _muscleColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: _muscleColor.withValues(alpha: 0.2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 20),
                    child: Text(
                      cleanStep,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ============================================================================
// SHIMMER LOADING ANIMATION
// ============================================================================
class _ShimmerLoading extends StatefulWidget {
  final Color color;

  const _ShimmerLoading({required this.color});

  @override
  State<_ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<_ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: widget.color.withValues(
                  alpha: 0.08 + (_animation.value * 0.12),
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_circle_outline_rounded,
                size: 48,
                color: widget.color.withValues(
                  alpha: 0.3 + (_animation.value * 0.3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading media...',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// FULL SCREEN MEDIA VIEWER
// ============================================================================
class _FullScreenMediaViewer extends StatefulWidget {
  final Exercise exercise;
  final VideoPlayerController? videoController;
  final bool isVideo;
  final bool isImage;

  const _FullScreenMediaViewer({
    required this.exercise,
    this.videoController,
    this.isVideo = false,
    this.isImage = false,
  });

  @override
  State<_FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<_FullScreenMediaViewer> {
  final TransformationController _transformController =
      TransformationController();
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Auto-hide controls after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main media content with pinch-to-zoom
            Center(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildFullScreenContent(),
              ),
            ),

            // Top bar with close button
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: _showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.exercise.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom hint
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              bottom: _showControls ? 0 : -60,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Text(
                      'Pinch to zoom · Double-tap to reset',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenContent() {
    // Video
    if (widget.isVideo && widget.videoController != null) {
      return AspectRatio(
        aspectRatio: widget.videoController!.value.aspectRatio,
        child: VideoPlayer(widget.videoController!),
      );
    }

    // Image (gif, jpg, etc.)
    final imageUrl = widget.exercise.videoUrl ?? widget.exercise.thumbnailUrl;
    if (imageUrl != null) {
      return Hero(
        tag: 'exercise_media_${widget.exercise.id}',
        child: Image.asset(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_rounded,
            size: 64,
            color: Colors.white38,
          ),
        ),
      );
    }

    return const Icon(
      Icons.image_not_supported_rounded,
      size: 64,
      color: Colors.white38,
    );
  }
}
