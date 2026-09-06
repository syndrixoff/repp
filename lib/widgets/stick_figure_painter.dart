import 'package:flutter/material.dart';

// Draws 17 COCO-style joints. Joints are normalized 0..1 within the canvas.
// Used by StickAnimator + PoseOverlay so both share same skeleton logic.
class StickFigurePainter extends CustomPainter {
  final Map<String, Offset> joints; // normalized already scaled to widget size externally OR 0..1 map is passed + size param
  final Map<String, Offset> normalizedJoints;
  final Color lineColor;
  final Color jointColor;
  final double strokeWidth;

  StickFigurePainter({
    required this.normalizedJoints,
    this.lineColor = Colors.white,
    this.jointColor = const Color(0xFFFACC15),
    this.strokeWidth = 4,
  }) : joints = normalizedJoints;

  static const bones = [
    ['nose', 'shoulder_l'],
    ['nose', 'shoulder_r'],
    ['shoulder_l', 'shoulder_r'],
    ['shoulder_l', 'elbow_l'],
    ['elbow_l', 'wrist_l'],
    ['shoulder_r', 'elbow_r'],
    ['elbow_r', 'wrist_r'],
    ['shoulder_l', 'hip_l'],
    ['shoulder_r', 'hip_r'],
    ['hip_l', 'hip_r'],
    ['hip_l', 'knee_l'],
    ['knee_l', 'ankle_l'],
    ['hip_r', 'knee_r'],
    ['knee_r', 'ankle_r'],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Offset toPx(Offset n) => Offset(n.dx * size.width, n.dy * size.height);

    // bones
    final bonePaint = Paint()
      ..color = lineColor.withValues(alpha: 0.95)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final b in bones) {
      final a = normalizedJoints[b[0]];
      final c = normalizedJoints[b[1]];
      if (a == null || c == null) continue;
      canvas.drawLine(toPx(a), toPx(c), bonePaint);
    }

    // joints
    final jointPaint = Paint()..color = jointColor;
    final jointOutline = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final e in normalizedJoints.entries) {
      final p = toPx(e.value);
      canvas.drawCircle(p, 6, jointOutline);
      canvas.drawCircle(p, 5, jointPaint);
      if (e.key == 'nose') {
        canvas.drawCircle(p, 7, jointOutline);
        canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StickFigurePainter oldDelegate) =>
      oldDelegate.normalizedJoints != normalizedJoints ||
      oldDelegate.lineColor != lineColor;

  /// Linear interpolation between two joint maps at t in 0..1
  static Map<String, Offset> lerp(
      Map<String, Offset> a, Map<String, Offset> b, double t) {
    final out = <String, Offset>{};
    final keys = {...a.keys, ...b.keys};
    for (final k in keys) {
      final av = a[k];
      final bv = b[k];
      if (av == null) { if (bv!=null) out[k]=bv; continue; }
      if (bv == null) { out[k]=av; continue; }
      out[k] = Offset(
        av.dx + (bv.dx - av.dx) * t,
        av.dy + (bv.dy - av.dy) * t,
      );
    }
    return out;
  }

  static Map<String, Offset> fromJson(Map<String, dynamic> j) {
    final out = <String, Offset>{};
    j.forEach((k, v) {
      if (v is List && v.length >= 2) {
        out[k] = Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
      }
    });
    return out;
  }
}
