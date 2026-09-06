import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated 3-dot typing indicator where dots raise one by one smoothly,
/// with an active seconds counter so the user knows it's actively computing.
class TypingDotsIndicator extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double raiseHeight;
  final bool showTimer;
  final String? statusLabel;

  const TypingDotsIndicator({
    super.key,
    this.color,
    this.dotSize = 6.5,
    this.raiseHeight = 5.5,
    this.showTimer = true,
    this.statusLabel,
  });

  @override
  State<TypingDotsIndicator> createState() => _TypingDotsIndicatorState();
}

class _TypingDotsIndicatorState extends State<TypingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    if (widget.showTimer) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _seconds++);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    final dotColor = widget.color ?? Theme.of(context).colorScheme.primary;
    // Stagger intervals for 3 dots: [0.0..0.5], [0.2..0.7], [0.4..0.9]
    final start = index * 0.2;
    final end = (start + 0.5).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        double dy = 0.0;
        double opacity = 0.4;

        if (t >= start && t <= end) {
          final progress = (t - start) / (end - start);
          // Sine curve for smooth up-and-down raise
          final wave = math.sin(progress * math.pi);
          dy = -widget.raiseHeight * wave;
          opacity = 0.4 + (0.6 * wave);
        }

        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText = widget.statusLabel != null
        ? '${widget.statusLabel!} (${_seconds}s)'
        : (_seconds < 6
            ? 'Thinking (${_seconds}s)...'
            : 'Generating (${_seconds}s)...');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildDot(0),
          const SizedBox(width: 5),
          _buildDot(1),
          const SizedBox(width: 5),
          _buildDot(2),
          if (widget.showTimer) ...[
            const SizedBox(width: 8),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
