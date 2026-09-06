import 'package:flutter/material.dart';
import '../ai/pose_service.dart';
import 'stick_figure_painter.dart';

/// Overlay that draws skeleton on top of camera preview.
/// Stub renders from PoseService stream. Replace CameraPreview child in Phase 2.
class PoseOverlay extends StatelessWidget {
  final PoseFrame? frame;
  final Widget? cameraPreview;
  const PoseOverlay({super.key, this.frame, this.cameraPreview});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (cameraPreview != null) cameraPreview!
        else Container(color: Colors.black),
        if (frame != null)
          CustomPaint(
            painter: StickFigurePainter(
              normalizedJoints: {
                for (final l in frame!.landmarks) l.name: Offset(l.x, l.y),
              },
              lineColor: Colors.greenAccent,
              jointColor: Colors.yellowAccent,
            ),
          ),
        // angle chips bottom
        if (frame != null && frame!.angles.isNotEmpty)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Wrap(
              spacing: 8,
              children: frame!.angles.entries.map((e) {
                return Chip(
                  label: Text('${e.key} ${e.value.toStringAsFixed(0)}°',
                      style: const TextStyle(fontSize: 11, color: Colors.white)),
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
