// Placeholder for YOLO tflite variant.
// To enable: add tflite_flutter + yolov8n-pose.tflite to assets/models/,
// implement Interpreter.run() and NMS here. Stub keeps build green.
class YoloPoseDetector {
  bool get isAvailable => false;
  Future<void> loadModel(String assetPath) async {
    throw UnimplementedError('YOLO pose not bundled - see docs/yolo.md');
  }
  void dispose() {}
}
