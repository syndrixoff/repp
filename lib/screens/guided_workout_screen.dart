import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:video_player/video_player.dart';
import '../providers/workout_provider.dart';
import '../providers/history_provider.dart';
import '../providers/player_provider.dart';
import '../providers/daily_quest_provider.dart';
import '../providers/settings_provider.dart';
import '../models/models.dart';
import '../services/exercise_service.dart';
import '../theme/app_colors.dart';
import '../widgets/set_type_bottom_sheet.dart';
import 'workout_complete_screen.dart';

class GuidedWorkoutScreen extends StatefulWidget {
  const GuidedWorkoutScreen({super.key});

  @override
  State<GuidedWorkoutScreen> createState() => _GuidedWorkoutScreenState();
}

class _GuidedWorkoutScreenState extends State<GuidedWorkoutScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Current position in the guided flow
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;

  // Rest timer state
  bool _isRestTimerActive = false;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  // Auto-pause state (freezes elapsed workout timer after rest hits 0 / during Start section & backgrounding)
  bool _isPostRestPaused = false;
  DateTime? _postRestPauseStart;
  DateTime? _appPausedTimestamp;

  // Elapsed workout timer
  Timer? _elapsedTimer;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _restOverlayController;
  late Animation<double> _restOverlayAnimation;
  late AnimationController _timerPulseController;
  late Animation<double> _timerPulseAnimation;
  late AnimationController _progressRingController;

  // Input controllers
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  // Video media controller & state
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoPlaying = false;
  // Preloaded video controllers for background initialization (keyed by exerciseId)
  final Map<String, VideoPlayerController> _preloadedVideoControllers = {};

  // Previous sets data
  final Map<String, List<Map<String, dynamic>>> _previousSetsCache = {};

  @override
  void initState() {
    super.initState();

    // Fade animation for set transitions
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    // Rest overlay animation
    _restOverlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _restOverlayAnimation = CurvedAnimation(
      parent: _restOverlayController,
      curve: Curves.easeOut,
    );

    // Timer pulse animation
    _timerPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _timerPulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _timerPulseController, curve: Curves.easeInOut),
    );

    // Progress ring controller (used to track rest timer progress)
    _progressRingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    // Elapsed timer
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Register app lifecycle observer for background pause tracking
    WidgetsBinding.instance.addObserver(this);

    _loadCurrentSetData();
    _loadPreviousSets();
    _initializeExerciseMedia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restTimer?.cancel();
    _elapsedTimer?.cancel();
    _fadeController.dispose();
    _restOverlayController.dispose();
    _timerPulseController.dispose();
    _progressRingController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App entered background or lost focus
      _appPausedTimestamp ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_appPausedTimestamp != null) {
        final backgroundDuration =
            DateTime.now().difference(_appPausedTimestamp!);
        _appPausedTimestamp = null;

        // If the app was paused in the background during the "Start" state or resting,
        // credit that background idle duration so the active workout timer does not inflate.
        if (_isPostRestPaused && mounted) {
          context.read<WorkoutProvider>().addPausedDuration(backgroundDuration);
          setState(() {});
        }
      }
    }
  }

  void _loadCurrentSetData() {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return;

    if (_currentExerciseIndex >= workout.exercises.length) return;
    final exercise = workout.exercises[_currentExerciseIndex];
    if (_currentSetIndex >= exercise.sets.length) return;
    final set = exercise.sets[_currentSetIndex];

    _weightController.text = set.weight?.toStringAsFixed(1) ?? '';
    _repsController.text = set.reps?.toString() ?? '';
    // Load cardio fields
    _durationController.text = set.duration != null
        ? set.duration!.toStringAsFixed(0)
        : '';
    _distanceController.text = set.distance != null
        ? (set.distance! / 1000).toStringAsFixed(2)
        : '';

    // Ensure the media for this exercise is initialized when we load the set
    _initializeExerciseMedia();
  }

  Future<void> _loadPreviousSets() async {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return;

    final historyProvider = context.read<HistoryProvider>();

    for (final exercise in workout.exercises) {
      if (_previousSetsCache.containsKey(exercise.exerciseId)) continue;

      final history = await historyProvider.getExerciseHistory(
        exercise.exerciseId,
      );

      if (history.isNotEmpty) {
        final Map<String, List<Map<String, dynamic>>> byWorkout = {};
        for (final row in history) {
          final wid = row['workout_id'].toString();
          byWorkout.putIfAbsent(wid, () => []);
          byWorkout[wid]!.add(row);
        }
        if (byWorkout.isNotEmpty) {
          final firstWorkoutId = byWorkout.keys.first;
          _previousSetsCache[exercise.exerciseId] = byWorkout[firstWorkoutId]!;
        }
      }
    }

    if (mounted) setState(() {});
  }

  Map<String, dynamic>? _getPreviousForCurrentSet() {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return null;
    if (_currentExerciseIndex >= workout.exercises.length) return null;

    final exercise = workout.exercises[_currentExerciseIndex];
    final prev = _previousSetsCache[exercise.exerciseId];
    if (prev == null || _currentSetIndex >= prev.length) return null;

    return prev[_currentSetIndex];
  }

  String _getEquipment(String exerciseId) {
    final svc = ExerciseService();
    final ex = svc.getById(exerciseId);
    return ex?.equipment ?? 'Other';
  }

  Exercise? _getExerciseModel(String exerciseId) {
    final svc = ExerciseService();
    return svc.getById(exerciseId);
  }

  Color _getMuscleColor(String exerciseId) {
    final exerciseModel = _getExerciseModel(exerciseId);
    if (exerciseModel == null) return AppColors.primary;
    return AppColors.getMuscleColor(exerciseModel.primaryMuscle);
  }

  bool _isImageUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  /// Consider a URL a video only when it clearly ends with a known video
  /// extension (mp4, mov, webm, etc.). This avoids treating generic or
  /// non-explicit URLs as videos when they should be handled as images/GIFs.
  bool _isVideoUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.ogv') ||
        lower.endsWith('.mpeg') ||
        lower.endsWith('.mpg') ||
        lower.endsWith('.3gp') ||
        lower.endsWith('.mkv');
  }

  Widget _buildExerciseMedia(String exerciseId, bool isDark) {
    final exerciseModel = _getExerciseModel(exerciseId);
    if (exerciseModel == null) return const SizedBox.shrink();

    final muscleColor = _getMuscleColor(exerciseId);

    // Determine whether the exercise has a video URL.
    // Prefer image/GIF handling unless the URL clearly matches a video extension.
    final videoUrl = exerciseModel.videoUrl;
    final isVideo = videoUrl != null && _isVideoUrl(videoUrl);

    // If there is no media at all, show the placeholder
    if (videoUrl == null && (exerciseModel.thumbnailUrl == null)) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              muscleColor.withValues(alpha: 0.10),
              isDark ? const Color(0xFF1A1A1A) : const Color(0xFF1A1A2E),
              muscleColor.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      muscleColor.withValues(alpha: 0.18),
                      muscleColor.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: muscleColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 40,
                  color: muscleColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'No preview available',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // For video: show VideoPlayer (if initialized), otherwise shimmer/loading.
    // For image/gif: show CachedNetworkImage.
    final imageUrlFallback = exerciseModel.thumbnailUrl;
    final imageUrl =
        (exerciseModel.videoUrl != null && _isImageUrl(exerciseModel.videoUrl))
        ? exerciseModel.videoUrl
        : imageUrlFallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background glow gradient (muscle-color based)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    muscleColor.withValues(alpha: 0.10),
                    isDark ? Colors.black : const Color(0xFF1A1A2E),
                    muscleColor.withValues(alpha: 0.06),
                  ],
                ),
              ),
            ),

            // Media content area
            Center(
              child: isVideo
                  ? (_isVideoInitialized && _videoController != null
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                VideoPlayer(_videoController!),
                                // Tappable overlay to toggle play/pause
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(onTap: _toggleVideoPlayPause),
                                ),
                                // Play icon when paused
                                if (!_isVideoPlaying)
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : _buildMediaShimmer(muscleColor))
                  : (imageUrl != null
                        ? (imageUrl.toLowerCase().endsWith('.gif')
                              ? Image.asset(
                                  imageUrl,
                                  gaplessPlayback: true,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: muscleColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.fitness_center_rounded,
                                              size: 36,
                                              color: muscleColor.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Could not load media',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                )
                              : Image.asset(
                                  imageUrl,
                                  key: ValueKey(imageUrl),
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              color: muscleColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.fitness_center_rounded,
                                              size: 36,
                                              color: muscleColor.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Could not load media',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ),
                                ))
                        : const SizedBox.shrink()),
            ),

            // Bottom gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
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

  Widget _buildMediaShimmer(Color muscleColor) {
    return _ShimmerPulse(muscleColor: muscleColor);
  }

  Future<void> _initializeExerciseMedia() async {
    // Initialize or dispose video controller depending on current exercise media
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return;
    if (_currentExerciseIndex >= workout.exercises.length) return;

    final we = workout.exercises[_currentExerciseIndex];
    final exerciseModel = _getExerciseModel(we.exerciseId);
    final url = exerciseModel?.videoUrl;

    // If no video or the url is an image (gif/jpg/png), ensure we dispose any existing controller
    if (url == null || _isImageUrl(url)) {
      if (_videoController != null) {
        try {
          await _videoController!.pause();
        } catch (_) {}
        _videoController?.dispose();
        _videoController = null;
      }
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoPlaying = false;
        });
      }
      return;
    }

    // If same url already initialized, keep it
    if (_videoController != null &&
        _videoController!.dataSource == url &&
        _isVideoInitialized) {
      return;
    }

    // Dispose any existing controller
    _videoController?.dispose();
    _videoController = null;

    try {
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
        });
      }

      _videoController = VideoPlayerController.asset(url);
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0);
      await _videoController!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoPlaying = true;
        });
      }
    } catch (e) {
      // If initialization fails, clean up and fall back to image/placeholder
      _videoController?.dispose();
      _videoController = null;
      if (mounted) {
        setState(() {
          _isVideoInitialized = false;
          _isVideoPlaying = false;
        });
      }
    }
  }

  void _toggleVideoPlayPause() {
    if (_videoController == null || !_isVideoInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
      setState(() {
        _isVideoPlaying = false;
      });
    } else {
      _videoController!.play();
      setState(() {
        _isVideoPlaying = true;
      });
    }
  }

  /// Preload media (image/GIF or video) for a given exerciseId so it's ready
  /// when the UI moves to that exercise. For videos this initializes a
  /// VideoPlayerController and stores it in `_preloadedVideoControllers`.
  Future<void> _preloadNextMedia(String exerciseId) async {
    if (exerciseId.isEmpty) return;
    // If already preloaded, nothing to do
    if (_preloadedVideoControllers.containsKey(exerciseId)) return;

    final svc = ExerciseService();
    final ex = svc.getById(exerciseId);
    if (ex == null) return;

    // If there's a clearly identifiable video URL, initialize a controller
    final videoUrl = ex.videoUrl;
    if (videoUrl != null && _isVideoUrl(videoUrl)) {
      try {
        final tmp = VideoPlayerController.asset(videoUrl);
        await tmp.initialize();
        tmp.setLooping(true);
        tmp.setVolume(0);
        // Do not autoplay until we swap into active controller, but prepare it
        // by seeking to start and pausing (play to prime may be platform-dependent).
        try {
          await tmp.pause();
        } catch (_) {}
        _preloadedVideoControllers[exerciseId] = tmp;
      } catch (e) {
        // ignore preload errors; fall back to image prefetch below if present
      }
    }
    if (!mounted) return;

    // For image/GIF fallback, prefetch into image cache
    final imageUrl = (ex.videoUrl != null && _isImageUrl(ex.videoUrl))
        ? ex.videoUrl
        : ex.thumbnailUrl;
    if (imageUrl != null) {
      try {
        final provider = AssetImage(imageUrl);
        final config = createLocalImageConfiguration(context);
        provider.resolve(config);
      } catch (_) {}
    }
  }

  String _formatElapsedTime(Duration dur) {
    final hours = dur.inHours;
    final minutes = dur.inMinutes % 60;
    final seconds = dur.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isLastSetOfLastExercise() {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return true;

    final isLastExercise =
        _currentExerciseIndex >= workout.exercises.length - 1;
    if (!isLastExercise) return false;

    final exercise = workout.exercises[_currentExerciseIndex];
    return _currentSetIndex >= exercise.sets.length - 1;
  }

  Future<void> _completeCurrentSet() async {
    final workoutProvider = context.read<WorkoutProvider>();
    final workout = workoutProvider.activeWorkout;
    if (workout == null) return;

    // Detect if this is a cardio exercise
    final workoutExercise = workout.exercises[_currentExerciseIndex];
    final exerciseModel = _getExerciseModel(workoutExercise.exerciseId);
    final isCardio =
        exerciseModel != null &&
        CardioType.isCardio(exerciseModel.primaryMuscle);

    if (isCardio) {
      // Save duration/distance values for cardio
      final duration = double.tryParse(_durationController.text);
      final distanceKm = double.tryParse(_distanceController.text);
      if (duration != null) {
        await workoutProvider.updateSet(
          _currentExerciseIndex,
          _currentSetIndex,
          duration: duration * 60, // Store as seconds
        );
      }
      if (distanceKm != null) {
        await workoutProvider.updateSet(
          _currentExerciseIndex,
          _currentSetIndex,
          distance: distanceKm * 1000, // Store as meters
        );
      }
    } else {
      // Save weight/reps values for strength
      final weight = double.tryParse(_weightController.text);
      final reps = int.tryParse(_repsController.text);
      if (weight != null) {
        await workoutProvider.updateSet(
          _currentExerciseIndex,
          _currentSetIndex,
          weight: weight,
        );
      }
      if (reps != null) {
        await workoutProvider.updateSet(
          _currentExerciseIndex,
          _currentSetIndex,
          reps: reps,
        );
      }
    }

    // Mark set as completed
    await workoutProvider.updateSet(
      _currentExerciseIndex,
      _currentSetIndex,
      isCompleted: true,
    );

    HapticFeedback.mediumImpact();

    if (_isLastSetOfLastExercise()) {
      // Last set of last exercise — finish immediately, no rest
      _showFinishDialog();
    } else {
      // Start rest timer
      _startRestTimer();
    }
  }

  void _startRestTimer() {
    final restDuration = context.read<SettingsProvider>().restTimerSeconds;

    setState(() {
      _isRestTimerActive = true;
      _restSecondsRemaining = restDuration;
    });

    // Preload the next set/exercise media in the background so it's ready
    // when rest ends. This preloads images/GIFs into cache and initializes
    // a temporary VideoPlayerController for video URLs.
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout != null && workout.exercises.isNotEmpty) {
      int nextExerciseIndex = _currentExerciseIndex;
      final currentExercise = workout.exercises[_currentExerciseIndex];

      if (_currentSetIndex < currentExercise.sets.length - 1) {
        // Next set is within the same exercise -> keep nextExerciseIndex as-is.
      } else if (_currentExerciseIndex < workout.exercises.length - 1) {
        // Move to the first set of the next exercise.
        nextExerciseIndex++;
      } else {
        // No next exercise
        nextExerciseIndex = -1;
      }

      if (nextExerciseIndex >= 0 &&
          nextExerciseIndex < workout.exercises.length) {
        final nextExerciseId = workout.exercises[nextExerciseIndex].exerciseId;
        _preloadNextMedia(nextExerciseId);
      }
    }

    _restOverlayController.forward();
    _timerPulseController.repeat(reverse: true);

    _progressRingController.duration = Duration(seconds: restDuration);
    _progressRingController.forward(from: 0.0);

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _restSecondsRemaining--;
      });

      if (_restSecondsRemaining <= 0) {
        HapticFeedback.mediumImpact();
        timer.cancel();
        setState(() {
          _restSecondsRemaining = 0;
          _isPostRestPaused = true;
          _postRestPauseStart = DateTime.now();
        });
        _progressRingController.stop();
      }
    });
  }

  void _skipRestTimer() {
    _restTimer?.cancel();
    HapticFeedback.lightImpact();
    setState(() {
      _restSecondsRemaining = 0;
      _isPostRestPaused = true;
      _postRestPauseStart = DateTime.now();
    });
    _progressRingController.stop();
    // Keep overlay open and pulsing so user explicitly presses Start.
  }

  void _endRestTimer() {
    _restTimer?.cancel();
    _timerPulseController.stop();
    _timerPulseController.reset();
    _progressRingController.stop();
    _progressRingController.reset();

    // Deduct post-rest waiting/idle time from the workout so active duration is accurate
    if (_isPostRestPaused && _postRestPauseStart != null) {
      final pausedDuration = DateTime.now().difference(_postRestPauseStart!);
      _isPostRestPaused = false;
      _postRestPauseStart = null;
      context.read<WorkoutProvider>().addPausedDuration(pausedDuration);
    }

    _restOverlayController.reverse().then((_) {
      if (!mounted) return;
      _moveToNextSet();
    });
  }

  void _moveToNextSet() {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return;

    final currentExercise = workout.exercises[_currentExerciseIndex];

    // Fade out current
    _fadeController.reverse().then((_) {
      if (!mounted) return;

      setState(() {
        _isRestTimerActive = false;

        if (_currentSetIndex < currentExercise.sets.length - 1) {
          // Next set of same exercise
          _currentSetIndex++;
        } else {
          // Next exercise, first set
          _currentExerciseIndex++;
          _currentSetIndex = 0;
        }
      });

      // If we preloaded a VideoPlayerController for the next exercise, swap it in
      try {
        final workout = context.read<WorkoutProvider>().activeWorkout;
        if (workout != null &&
            _currentExerciseIndex < workout.exercises.length) {
          final nextExerciseId =
              workout.exercises[_currentExerciseIndex].exerciseId;
          if (_preloadedVideoControllers.containsKey(nextExerciseId)) {
            // Dispose existing active controller and replace with preloaded one
            _videoController?.dispose();
            _videoController = _preloadedVideoControllers.remove(
              nextExerciseId,
            );
            if (_videoController != null) {
              _isVideoInitialized = _videoController!.value.isInitialized;
              _isVideoPlaying = false;
              try {
                // Try to play the swapped controller so it's visible immediately
                _videoController!.setLooping(true);
                _videoController!.setVolume(0);
                _videoController!.play();
                _isVideoPlaying = true;
              } catch (_) {}
            }
          } else {
            // Ensure media for the newly visible exercise is initialized
            _initializeExerciseMedia();
          }
        }
      } catch (_) {}

      _loadCurrentSetData();

      // Fade in next
      _fadeController.forward();
    });
  }

  void _showFinishDialog() {
    final workoutProvider = context.read<WorkoutProvider>();
    final workout = workoutProvider.activeWorkout;
    if (workout == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration icon
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.success,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Routine Complete!',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Great work finishing your workout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),

                // Quick stats
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      _FinishStatRow(
                        icon: Icons.timer_rounded,
                        label: 'Duration',
                        value: workout.durationString,
                        color: AppColors.accentOrange,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _FinishStatRow(
                        icon: Icons.fitness_center_rounded,
                        label: 'Exercises',
                        value: '${workout.exercises.length}',
                        color: AppColors.primary,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),
                      _FinishStatRow(
                        icon: Icons.check_circle_rounded,
                        label: 'Sets Completed',
                        value: '${workout.completedSets}/${workout.totalSets}',
                        color: AppColors.success,
                        isDark: isDark,
                      ),
                      if (workout.totalVolume > 0) ...[
                        const SizedBox(height: 10),
                        _FinishStatRow(
                          icon: Icons.trending_up_rounded,
                          label: 'Total Volume',
                          value: '${workout.totalVolume.toStringAsFixed(0)} kg',
                          color: AppColors.accentPurple,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      final completedWorkout = workoutProvider.activeWorkout;
                      final historyProvider = context.read<HistoryProvider>();
                      final playerProvider = context.read<PlayerProvider>();
                      final questProvider = context.read<DailyQuestProvider>();
                      final nav = Navigator.of(context);
                      await workoutProvider.finishWorkout();
                      await historyProvider.refresh();
                      // Award XP and show reward screen
                      if (completedWorkout != null) {
                        final xpResult = await playerProvider.awardWorkoutXP(
                          completedWorkout,
                        );
                        await questProvider.registerProgressMilestones(
                          xpResult: xpResult,
                          stats: playerProvider.stats,
                        );
                        await questProvider.ensureToday(
                          stats: playerProvider.stats,
                          workoutHistory: historyProvider.workoutHistory,
                        );
                        if (mounted) {
                          nav.pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => WorkoutCompleteScreen(
                                xpResult: xpResult,
                                workout: completedWorkout,
                              ),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          nav.pop();
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Finish Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white70
                          : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep Going',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    final workoutProvider = context.read<WorkoutProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Cancel Workout?',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All progress from this workout will be lost.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      final nav = Navigator.of(context);
                      await workoutProvider.cancelWorkout();
                      if (mounted) {
                        nav.pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Cancel Workout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.white70
                          : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Keep Going',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRestTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '0:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutProvider>();
    final workout = workoutProvider.activeWorkout;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    if (workout == null || workout.exercises.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Setting up workout...',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Safety clamp
    final exerciseIndex = _currentExerciseIndex.clamp(
      0,
      workout.exercises.length - 1,
    );
    final exercise = workout.exercises[exerciseIndex];
    final setIndex = _currentSetIndex.clamp(0, exercise.sets.length - 1);
    final currentSet = exercise.sets[setIndex];
    final equipment = _getEquipment(exercise.exerciseId);
    final exerciseModel = _getExerciseModel(exercise.exerciseId);
    final isCardio =
        exerciseModel != null &&
        CardioType.isCardio(exerciseModel.primaryMuscle);
    final needsDistance =
        exerciseModel != null && CardioType.needsDistance(exerciseModel.name);
    final showWeight = !isCardio && EquipmentType.needsWeight(equipment);
    final muscleColor = _getMuscleColor(exercise.exerciseId);

    // Elapsed time (excluding accumulated paused dead time and active post-rest idle time)
    final pendingPostRestPause =
        (_isPostRestPaused && _postRestPauseStart != null)
            ? DateTime.now().difference(_postRestPauseStart!).inSeconds
            : 0;
    final totalRawSeconds =
        DateTime.now().difference(workout.startTime).inSeconds;
    final activeSeconds =
        totalRawSeconds - workout.pausedSeconds - pendingPostRestPause;
    final elapsed =
        Duration(seconds: activeSeconds > 0 ? activeSeconds : 0);
    final elapsedStr = _formatElapsedTime(elapsed);

    // Progress
    int totalSets = 0;
    int completedSoFar = 0;
    for (int ei = 0; ei < workout.exercises.length; ei++) {
      for (int si = 0; si < workout.exercises[ei].sets.length; si++) {
        totalSets++;
        if (ei < _currentExerciseIndex ||
            (ei == _currentExerciseIndex && si < _currentSetIndex)) {
          completedSoFar++;
        }
      }
    }
    final progress = totalSets > 0 ? completedSoFar / totalSets : 0.0;

    // Set type label and color
    final setTypeLabel = currentSet.isWarmup
        ? 'W'
        : currentSet.isDropSet
        ? 'D'
        : currentSet.isFailure
        ? 'F'
        : '${currentSet.setNumber}';

    final setColor = currentSet.isWarmup
        ? Colors.orange
        : currentSet.isDropSet
        ? Colors.blue
        : currentSet.isFailure
        ? AppColors.error
        : colorScheme.primary;

    final setTypeName = currentSet.isWarmup
        ? 'Warm Up'
        : currentSet.isDropSet
        ? 'Drop Set'
        : currentSet.isFailure
        ? 'Failure Set'
        : 'Working Set';

    // Previous data
    final prevData = _getPreviousForCurrentSet();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showCancelDialog();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        body: Stack(
          children: [
            // ── Background glow — radial gradient from top using muscle color ──
            Positioned(
              top: -100,
              left: -40,
              right: -40,
              height: 420,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.3,
                      colors: [
                        muscleColor.withValues(alpha: 0.16),
                        muscleColor.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // ── Main content column ──
            Column(
              children: [
                // ── Custom top bar ──
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 26),
                          onPressed: _showCancelDialog,
                        ),
                        const Spacer(),
                        Text(
                          workout.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _showFinishDialog,
                          child: Text(
                            'Finish',
                            style: TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Progress bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Exercise ${exerciseIndex + 1} of ${workout.exercises.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$completedSoFar / $totalSets sets',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Scrollable main content ──
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // Exercise GIF / media
                          _buildExerciseMedia(exercise.exerciseId, isDark),

                          const SizedBox(height: 16),

                          // Exercise name
                          Text(
                            exercise.exerciseName,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isCardio)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                needsDistance ? 'Distance + Time' : 'Time',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else if (!showWeight)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                equipment == 'None' ? 'Bodyweight' : equipment,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Large elapsed timer
                          Text(
                            elapsedStr,
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ELAPSED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade500,
                              letterSpacing: 2.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Set type badge — tappable
                          GestureDetector(
                            onTap: () async {
                              final option = await SetTypeBottomSheet.show(
                                context,
                                currentSet.setNumber,
                              );
                              if (option != null &&
                                  option != SetTypeOption.remove) {
                                workoutProvider.updateSet(
                                  _currentExerciseIndex,
                                  _currentSetIndex,
                                  isWarmup: option == SetTypeOption.warmUp,
                                  isDropSet: option == SetTypeOption.drop,
                                  isFailure: option == SetTypeOption.failure,
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: setColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: setColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: setColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      setTypeLabel,
                                      style: TextStyle(
                                        color: setColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$setTypeName  ·  Set ${setIndex + 1} of ${exercise.sets.length}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 22,
                                    color: isDark
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade500,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Previous value
                          if (prevData != null)
                            _buildPreviousValue(prevData, isDark),
                          if (prevData != null) const SizedBox(height: 20),

                          // Inputs — cardio: time/distance, strength: weight/reps
                          if (isCardio)
                            Row(
                              children: [
                                if (needsDistance) ...[
                                  Expanded(
                                    child: _GuidedInput(
                                      controller: _distanceController,
                                      label: 'DISTANCE (KM)',
                                      isDark: isDark,
                                      isDecimal: true,
                                      onChanged: (value) {
                                        final km = double.tryParse(value);
                                        if (km != null) {
                                          workoutProvider.updateSet(
                                            _currentExerciseIndex,
                                            _currentSetIndex,
                                            distance: km * 1000,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                Expanded(
                                  child: _GuidedInput(
                                    controller: _durationController,
                                    label: 'TIME (MIN)',
                                    isDark: isDark,
                                    isDecimal: true,
                                    onChanged: (value) {
                                      final mins = double.tryParse(value);
                                      if (mins != null) {
                                        workoutProvider.updateSet(
                                          _currentExerciseIndex,
                                          _currentSetIndex,
                                          duration: mins * 60,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                if (showWeight) ...[
                                  Expanded(
                                    child: _GuidedInput(
                                      controller: _weightController,
                                      label: 'WEIGHT (KG)',
                                      isDark: isDark,
                                      isDecimal: true,
                                      onChanged: (value) {
                                        final weight = double.tryParse(value);
                                        if (weight != null) {
                                          workoutProvider.updateSet(
                                            _currentExerciseIndex,
                                            _currentSetIndex,
                                            weight: weight,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                Expanded(
                                  child: _GuidedInput(
                                    controller: _repsController,
                                    label: 'REPS',
                                    isDark: isDark,
                                    isDecimal: false,
                                    onChanged: (value) {
                                      final reps = int.tryParse(value);
                                      if (reps != null) {
                                        workoutProvider.updateSet(
                                          _currentExerciseIndex,
                                          _currentSetIndex,
                                          reps: reps,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Complete set button — pinned at bottom ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton.icon(
                      onPressed: _completeCurrentSet,
                      icon: const Icon(Icons.check_rounded, size: 28),
                      label: Text(
                        _isLastSetOfLastExercise()
                            ? 'Complete Workout'
                            : 'Complete Set',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLastSetOfLastExercise()
                            ? AppColors.success
                            : colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Rest timer overlay ──
            if (_isRestTimerActive)
              FadeTransition(
                opacity: _restOverlayAnimation,
                child: _buildRestTimerOverlay(isDark, colorScheme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousValue(Map<String, dynamic> prev, bool isDark) {
    final weight = prev['weight'];
    final reps = prev['reps'];
    final duration = prev['duration'];
    final distance = prev['distance'];

    String prevText = '';
    if (duration != null && duration > 0) {
      final mins = (duration as num) / 60;
      if (distance != null && distance > 0) {
        final km = (distance as num) / 1000;
        prevText =
            '${km.toStringAsFixed(2)} km · ${mins.toStringAsFixed(0)} min';
      } else {
        prevText = '${mins.toStringAsFixed(0)} min';
      }
    } else if (weight != null && reps != null) {
      final w = weight is num ? weight : num.tryParse(weight.toString()) ?? 0;
      final weightStr = w == w.toInt()
          ? '${w.toInt()} kg'
          : '${w.toStringAsFixed(1)} kg';
      prevText = '$weightStr × $reps reps';
    } else if (reps != null) {
      prevText = '$reps reps';
    }

    if (prevText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_rounded,
            size: 18,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Text(
            'Previous: ',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
          Text(
            prevText,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimerOverlay(bool isDark, ColorScheme colorScheme) {
    final settingsProvider = context.read<SettingsProvider>();
    final totalDuration = settingsProvider.restTimerSeconds;
    final progressValue = totalDuration > 0
        ? _restSecondsRemaining / totalDuration
        : 0.0;
    final isReadyToStart = _restSecondsRemaining <= 0;

    // Use a BackdropFilter to blur the underlying content more strongly,
    // then place a semi-opaque dark layer on top for better contrast.
    return Stack(
      children: [
        // Blurred background
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(color: Colors.black.withValues(alpha: 0.65)),
          ),
        ),

        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'REST',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 24),

                // Circular timer (tap the circle to start once ready)
                GestureDetector(
                  onTap: isReadyToStart ? _endRestTimer : null,
                  behavior: HitTestBehavior.opaque,
                  child: ScaleTransition(
                    scale: _timerPulseAnimation,
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background ring
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: 1.0,
                              strokeWidth: 6,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          // Progress ring
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: CircularProgressIndicator(
                              value: progressValue,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              color: colorScheme.primary,
                            ),
                          ),
                          // Timer text
                          Text(
                            isReadyToStart
                                ? 'Start'
                                : _formatRestTime(_restSecondsRemaining),
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Next up preview
                _buildNextUpPreview(isDark),

                const SizedBox(height: 40),

                // Skip button only during active countdown.
                if (!isReadyToStart)
                  ScaleTransition(
                    scale: _timerPulseAnimation,
                    child: SizedBox(
                      width: 160,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _skipRestTimer,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextUpPreview(bool isDark) {
    final workout = context.read<WorkoutProvider>().activeWorkout;
    if (workout == null) return const SizedBox.shrink();

    final currentExercise = workout.exercises[_currentExerciseIndex];
    String nextLabel;
    String nextDetail;

    if (_currentSetIndex < currentExercise.sets.length - 1) {
      // Next set of same exercise
      nextLabel = currentExercise.exerciseName;
      nextDetail =
          'Set ${_currentSetIndex + 2} of ${currentExercise.sets.length}';
    } else if (_currentExerciseIndex < workout.exercises.length - 1) {
      // Next exercise
      final nextExercise = workout.exercises[_currentExerciseIndex + 1];
      nextLabel = nextExercise.exerciseName;
      nextDetail = 'Set 1 of ${nextExercise.sets.length}';
    } else {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          'NEXT UP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          nextLabel,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          nextDetail,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer pulse for loading media
// ---------------------------------------------------------------------------

class _ShimmerPulse extends StatefulWidget {
  final Color muscleColor;
  const _ShimmerPulse({required this.muscleColor});

  @override
  State<_ShimmerPulse> createState() => _ShimmerPulseState();
}

class _ShimmerPulseState extends State<_ShimmerPulse>
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
        final pulse = _animation.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.muscleColor.withValues(
                  alpha: 0.06 + (pulse * 0.10),
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_circle_outline_rounded,
                size: 40,
                color: widget.muscleColor.withValues(
                  alpha: 0.25 + (pulse * 0.25),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 12,
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

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _GuidedInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDark;
  final bool isDecimal;
  final ValueChanged<String> onChanged;

  const _GuidedInput({
    required this.controller,
    required this.label,
    required this.isDark,
    required this.isDecimal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(
          height: 68,
          child: TextField(
            controller: controller,
            keyboardType: isDecimal
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: '—',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                fontSize: 32,
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 16,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _FinishStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _FinishStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
