import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VoiceOrbState { idle, listening, thinking, speaking }

/// An interactive, audio-reactive 3D fluid glowing spectrum orb.
/// Inspired by modern generative voice UIs (Gemini Live / Siri / ChatGPT Voice).
class VoiceSpectrumOrb extends StatefulWidget {
  final VoiceOrbState state;
  final double soundLevel; // 0.0 to 1.0 (or normalized dB from STT)
  final double size;

  const VoiceSpectrumOrb({
    super.key,
    this.state = VoiceOrbState.idle,
    this.soundLevel = 0.0,
    this.size = 220.0,
  });

  @override
  State<VoiceSpectrumOrb> createState() => _VoiceSpectrumOrbState();
}

class _VoiceSpectrumOrbState extends State<VoiceSpectrumOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _FluidOrbPainter(
            animationValue: _controller.value,
            state: widget.state,
            soundLevel: widget.soundLevel.clamp(0.0, 1.0),
          ),
        );
      },
    );
  }
}

class _FluidOrbPainter extends CustomPainter {
  final double animationValue;
  final VoiceOrbState state;
  final double soundLevel;

  _FluidOrbPainter({
    required this.animationValue,
    required this.state,
    required this.soundLevel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) * 0.72;

    // Amplitude scale based on state
    double ampScale = 0.08;
    if (state == VoiceOrbState.listening) {
      ampScale = 0.08 + (soundLevel * 0.38);
    } else if (state == VoiceOrbState.speaking) {
      ampScale = 0.12 + 0.18 * math.sin(animationValue * 4 * math.pi).abs();
    } else if (state == VoiceOrbState.thinking) {
      ampScale = 0.12 + 0.06 * math.sin(animationValue * 2 * math.pi);
    }

    // Outer ambient glowing aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFD500F9).withValues(alpha: 0.35 + ampScale * 0.4),
          const Color(0xFF00E5FF).withValues(alpha: 0.20 + ampScale * 0.2),
          Colors.transparent,
        ],
        stops: const [0.4, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 1.5))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    canvas.drawCircle(center, baseRadius * 1.4, auraPaint);

    // Render 3 fluid harmonic contour layers from back to front
    _drawFluidLayer(
      canvas,
      center,
      baseRadius * 0.92,
      phaseOffset: 0.0,
      ampScale: ampScale * 0.85,
      colors: [
        const Color(0xFF4A148C).withValues(alpha: 0.85),
        const Color(0xFF7B1FA2).withValues(alpha: 0.90),
        const Color(0xFF0D47A1).withValues(alpha: 0.85),
      ],
      strokeColor: const Color(0xFFBA68C8).withValues(alpha: 0.5),
    );

    _drawFluidLayer(
      canvas,
      center,
      baseRadius * 0.98,
      phaseOffset: math.pi / 3,
      ampScale: ampScale * 1.05,
      colors: [
        const Color(0xFF9C27B0).withValues(alpha: 0.90),
        const Color(0xFFE040FB).withValues(alpha: 0.95),
        const Color(0xFF2979FF).withValues(alpha: 0.88),
      ],
      strokeColor: const Color(0xFFE1BEE7).withValues(alpha: 0.75),
    );

    _drawFluidLayer(
      canvas,
      center,
      baseRadius * 1.02,
      phaseOffset: (2 * math.pi) / 3,
      ampScale: ampScale * 1.25,
      colors: [
        const Color(0xFFD500F9).withValues(alpha: 0.95),
        const Color(0xFF8E24AA).withValues(alpha: 0.85),
        const Color(0xFF00E5FF).withValues(alpha: 0.92),
      ],
      strokeColor: const Color(0xFFE0F7FA).withValues(alpha: 0.95),
    );

    // Inner glowing highlights & light core
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        colors: [
          Colors.white.withValues(alpha: 0.85),
          const Color(0xFFE040FB).withValues(alpha: 0.65),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius * 0.85));

    canvas.drawCircle(
      Offset(center.dx - baseRadius * 0.15, center.dy - baseRadius * 0.18),
      baseRadius * 0.42,
      corePaint,
    );
  }

  void _drawFluidLayer(
    Canvas canvas,
    Offset center,
    double radius, {
    required double phaseOffset,
    required double ampScale,
    required List<Color> colors,
    required Color strokeColor,
  }) {
    final path = Path();
    const int points = 72;
    final double time = animationValue * 2 * math.pi;

    for (int i = 0; i <= points; i++) {
      final theta = (i / points) * 2 * math.pi;

      // Compound harmonic fluid wave formula
      final wave1 = math.sin(theta * 3 + time + phaseOffset);
      final wave2 = math.cos(theta * 5 - time * 1.5 + phaseOffset * 0.7);
      final wave3 = math.sin(theta * 2 + time * 0.8);

      final r = radius * (1.0 + (wave1 * 0.5 + wave2 * 0.3 + wave3 * 0.2) * ampScale);
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fluid gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(
          math.cos(time + phaseOffset),
          math.sin(time + phaseOffset),
        ),
        end: Alignment(
          -math.cos(time + phaseOffset),
          -math.sin(time + phaseOffset),
        ),
        colors: colors,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));

    canvas.drawPath(path, fillPaint);

    // Glowing rim stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2.0);

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _FluidOrbPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.state != state ||
        oldDelegate.soundLevel != soundLevel;
  }
}
