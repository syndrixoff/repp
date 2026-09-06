/// Simple state machine for rep counting from knee angle time series.
/// No ML dep - just thresholds on knee flexion.
class RepCounter {
  final double downThreshold; // below => bottom
  final double upThreshold; // above => top
  int reps = 0;
  bool _wasDown = false;

  RepCounter({this.downThreshold = 90, this.upThreshold = 160});

  /// Call each frame with current knee angle. Returns true on rep counted.
  bool update(double kneeAngle) {
    if (!_wasDown && kneeAngle < downThreshold) {
      _wasDown = true;
      return false;
    }
    if (_wasDown && kneeAngle > upThreshold) {
      _wasDown = false;
      reps++;
      return true;
    }
    return false;
  }

  void reset() {
    reps = 0;
    _wasDown = false;
  }

  String get stateLabel => _wasDown ? 'DOWN' : 'UP';
}
