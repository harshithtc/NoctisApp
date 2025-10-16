import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _dotCount = 3;
  static const _duration = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _dotScale(int index, double t) {
    // Phase-shifted pulse per dot using a sine wave
    final phase = (t + index * 0.2) % 1.0;
    final v = (math.sin(2 * math.pi * phase) + 1) / 2; // 0..1
    return 0.6 + 0.4 * v; // 0.6..1.0
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleTheme = theme.extension<ChatBubbleTheme>();
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = bubbleTheme?.receivedBubble ??
        (isDark ? const Color(0xFF424242) : const Color(0xFFF5F5F5));
    final dotColor = theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: Alignment.centerLeft,
      child: RepaintBoundary(
        child: Semantics(
          label: 'Typing…',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_dotCount, (i) {
                    final scale = _dotScale(i, t);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
