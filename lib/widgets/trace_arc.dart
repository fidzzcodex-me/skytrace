import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

class TraceArc extends StatelessWidget {
  const TraceArc({super.key, this.size = 220, this.opacity = 0.35});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(size: Size(size, size), painter: _ArcPainter(opacity)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.62);
    for (var i = 0; i < 3; i++) {
      final radius = size.width * (0.28 + i * 0.12);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.2 - i * 0.7
        ..color = AppColors.accentBlue.withOpacity(opacity * (1 - i * 0.28));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi * 1.08,
        math.pi * 0.84,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) => oldDelegate.opacity != opacity;
}
