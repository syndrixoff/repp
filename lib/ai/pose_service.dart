import 'dart:async';
import 'pose/angle_calculator.dart';

/// Pose representation independent of ML Kit / YOLO.
/// Normalized 0..1 coordinates so painter + LLM share same space.
class PoseLandmark {
  final String name;
  final double x, y;
  final double confidence;
  PoseLandmark(this.name, this.x, this.y, [this.confidence = 1.0]);
  Joint2D toJoint() => Joint2D(x, y, confidence);
}

class PoseFrame {
  final List<PoseLandmark> landmarks;
  final Map<String, double> angles;
  final DateTime timestamp;
  PoseFrame({required this.landmarks, required this.angles, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  /// Compact text passed to LLM (token cheap).
  String toPoseContext({String exerciseHint = 'squat'}) {
    final a = angles.entries.map((e) => '${e.key}=${e.value.toStringAsFixed(0)}°').join(', ');
    return 'exercise=$exerciseHint, ${a.isEmpty ? 'no pose' : a}, landmarks=${landmarks.length}';
  }

  Map<String, Joint2D> toJointMap() => {
        for (final l in landmarks) l.name: l.toJoint(),
      };
}

/// Abstraction over MLKit (default) and YOLO (alt). Stub today, wire natives in Phase 2.
abstract class PoseService {
  Stream<PoseFrame> get poseStream;
  Future<void> start();
  Future<void> stop();
  bool get isRunning;
  void dispose();
}

/// Stub implementation that emits no frames until native plugin is wired.
/// Keep UI from crashing on Windows where MLKit is unavailable.
class StubPoseService implements PoseService {
  final _ctrl = StreamController<PoseFrame>.broadcast();
  bool _running = false;

  @override
  Stream<PoseFrame> get poseStream => _ctrl.stream;
  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async {
    _running = true;
    // Emit a synthetic demo frame every 2s so AI coach can be tested without camera.
    Timer.periodic(const Duration(seconds: 2), (t) {
      if (!_running) { t.cancel(); return; }
      final demo = PoseFrame(
        landmarks: [
          PoseLandmark('nose', 0.5, 0.15),
          PoseLandmark('shoulder_l', 0.42, 0.30),
          PoseLandmark('shoulder_r', 0.58, 0.30),
          PoseLandmark('hip_l', 0.45, 0.55),
          PoseLandmark('hip_r', 0.55, 0.55),
          PoseLandmark('knee_l', 0.44, 0.78),
          PoseLandmark('knee_r', 0.56, 0.78),
          PoseLandmark('ankle_l', 0.43, 0.95),
          PoseLandmark('ankle_r', 0.57, 0.95),
        ],
        angles: {'knee_l': 88, 'knee_r': 89, 'hip_l': 92},
      );
      if (!_ctrl.isClosed) _ctrl.add(demo);
    });
  }

  @override
  Future<void> stop() async { _running = false; }

  @override
  void dispose() { _ctrl.close(); }
}
