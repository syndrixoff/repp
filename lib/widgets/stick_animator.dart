import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stick_figure_painter.dart';

class StickKeyframe {
  final double t;
  final Map<String, Offset> joints;
  StickKeyframe({required this.t, required this.joints});
  factory StickKeyframe.fromJson(Map<String, dynamic> j) {
    final t = (j['t'] as num).toDouble();
    final joints = StickFigurePainter.fromJson((j['joints'] as Map).cast<String,dynamic>());
    return StickKeyframe(t: t, joints: joints);
  }
}

class StickAnimationData {
  final String exerciseId;
  final List<StickKeyframe> keyframes;
  StickAnimationData({required this.exerciseId, required this.keyframes});

  factory StickAnimationData.fromJson(Map<String,dynamic> j) {
    final kfs = (j['keyframes'] as List).map((e)=>StickKeyframe.fromJson(e as Map<String,dynamic>)).toList()
      ..sort((a,b)=>a.t.compareTo(b.t));
    return StickAnimationData(exerciseId: j['exerciseId']?.toString() ?? '', keyframes: kfs);
  }

  static Future<StickAnimationData?> loadAsset(String assetPath) async {
    try {
      final s = await rootBundle.loadString(assetPath);
      return StickAnimationData.fromJson(jsonDecode(s));
    } catch (_) { return null; }
  }
}

/// Animated stick figure widget. Pass keyframes (normalized 0..1).
/// Lerp between nearest keyframes at animation value.
class StickAnimator extends StatefulWidget {
  final StickAnimationData data;
  final Duration duration;
  final bool autoPlay;
  final double height;
  const StickAnimator({super.key, required this.data, this.duration = const Duration(milliseconds: 1600), this.autoPlay = true, this.height = 220});

  @override
  State<StickAnimator> createState() => _StickAnimatorState();
}

class _StickAnimatorState extends State<StickAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    if (widget.autoPlay) _ctrl.repeat(reverse: true);
  }
  @override
  void didUpdateWidget(covariant StickAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _ctrl.duration = widget.duration;
    }
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Map<String, Offset> _currentJoints(double animT) {
    final kfs = widget.data.keyframes;
    if (kfs.isEmpty) return {};
    if (kfs.length == 1) return kfs.first.joints;
    // ping-pong 0..1..0 mapping handled by repeat reverse, but for lerp we treat animT 0..1
    final t = animT.clamp(0.0, 1.0);
    StickKeyframe a = kfs.first, b = kfs.last;
    for (var i=0;i<kfs.length-1;i++) {
      if (t >= kfs[i].t && t <= kfs[i+1].t) { a=kfs[i]; b=kfs[i+1]; break; }
    }
    final span = (b.t - a.t).abs() < 1e-6 ? 1.0 : (b.t - a.t);
    final local = ((t - a.t)/span).clamp(0.0,1.0);
    return StickFigurePainter.lerp(a.joints, b.joints, local);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final joints = _currentJoints(_ctrl.value);
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CustomPaint(
            painter: StickFigurePainter(
              normalizedJoints: joints,
              lineColor: isDark ? Colors.white : Colors.white,
            ),
          ),
        );
      },
    );
  }
}
