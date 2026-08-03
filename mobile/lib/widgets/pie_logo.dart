import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Static rendering of the SplitNaija pie mark — the same 5-color wedges
/// that fly together on the splash screen, just assembled and motionless.
/// Used wherever a small app logo is needed (currently: atop Login).
class PieLogo extends StatelessWidget {
  const PieLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _StaticPiePainter());
  }
}

class _StaticPiePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceCount = kPieColors.length;
    final sweep = 360 / sliceCount;

    for (var i = 0; i < sliceCount; i++) {
      final startAngle = -90.0 + i * sweep;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle * math.pi / 180, sweep * math.pi / 180, false)
        ..close();

      canvas.drawPath(path, Paint()..color = kPieColors[i]);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticPiePainter oldDelegate) => false;
}
