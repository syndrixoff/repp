import 'dart:math' as math;

/// Pure-math angle calculator. No native deps.
/// Input joints are normalized 0..1 points in image space.
class Joint2D {
  final double x, y;
  final double confidence;
  const Joint2D(this.x, this.y, [this.confidence = 1.0]);
}

class AngleCalculator {
  /// Angle at b formed by a-b-c in degrees 0..180
  static double angle(Joint2D a, Joint2D b, Joint2D c) {
    final abx = a.x - b.x, aby = a.y - b.y;
    final cbx = c.x - b.x, cby = c.y - b.y;
    final dot = abx * cbx + aby * cby;
    final magAB = math.sqrt(abx * abx + aby * aby);
    final magCB = math.sqrt(cbx * cbx + cby * cby);
    if (magAB == 0 || magCB == 0) return 0;
    final cosA = (dot / (magAB * magCB)).clamp(-1.0, 1.0);
    return math.acos(cosA) * 180 / math.pi;
  }

  /// Convenience map from joint-name map.
  static Map<String, double> fromJoints(Map<String, Joint2D> j) {
    final out = <String, double>{};
    // Left knee: hip-knee-ankle
    if (j.containsKey('hip_l') && j.containsKey('knee_l') && j.containsKey('ankle_l')) {
      out['knee_l'] = angle(j['hip_l']!, j['knee_l']!, j['ankle_l']!);
    }
    if (j.containsKey('hip_r') && j.containsKey('knee_r') && j.containsKey('ankle_r')) {
      out['knee_r'] = angle(j['hip_r']!, j['knee_r']!, j['ankle_r']!);
    }
    if (j.containsKey('shoulder_l') && j.containsKey('hip_l') && j.containsKey('knee_l')) {
      out['hip_l'] = angle(j['shoulder_l']!, j['hip_l']!, j['knee_l']!);
    }
    if (j.containsKey('shoulder_r') && j.containsKey('hip_r') && j.containsKey('knee_r')) {
      out['hip_r'] = angle(j['shoulder_r']!, j['hip_r']!, j['knee_r']!);
    }
    if (j.containsKey('shoulder_l') && j.containsKey('elbow_l') && j.containsKey('wrist_l')) {
      out['elbow_l'] = angle(j['shoulder_l']!, j['elbow_l']!, j['wrist_l']!);
    }
    if (j.containsKey('shoulder_r') && j.containsKey('elbow_r') && j.containsKey('wrist_r')) {
      out['elbow_r'] = angle(j['shoulder_r']!, j['elbow_r']!, j['wrist_r']!);
    }
    return out;
  }
}
