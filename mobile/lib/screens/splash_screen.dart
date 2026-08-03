import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Loading / startup screen.
///
/// Shows a handful of colored pie "slices" flying in from different
/// directions and assembling into a single pie chart — a nod to splitting
/// (and re-joining) a bill — then reveals the SplitNaija wordmark.
///
/// This widget only plays the reveal animation once and holds on the final
/// frame; it does not navigate anywhere. The caller (see `main.dart`) is
/// responsible for deciding how long to keep this on screen and what to
/// show next (e.g. waiting on session restore in parallel).
class SplitNaijaSplashScreen extends StatefulWidget {
  const SplitNaijaSplashScreen({super.key});

  @override
  State<SplitNaijaSplashScreen> createState() => _SplitNaijaSplashScreenState();
}

class _SplitNaijaSplashScreenState extends State<SplitNaijaSplashScreen>
    with SingleTickerProviderStateMixin {
  static const _sliceCount = 5;
  static const _pieRadius = 64.0;
  static const _flyDistance = 210.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // Slower than a typical splash on purpose — this is the moment a
      // user notices they've actually entered the app, not a blip to
      // rush past.
      duration: const Duration(milliseconds: 3400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Manually evaluates [curve] over the sub-range [start, end] of the
  /// controller's linear 0..1 progress, clamping outside that range.
  /// (Deliberately avoids allocating a new CurvedAnimation/Interval per
  /// frame, which would leak listeners on the shared controller.)
  double _sub(double t, double start, double end, Curve curve) {
    if (t <= start) return curve.transform(0);
    if (t >= end) return curve.transform(1);
    return curve.transform((t - start) / (end - start));
  }

  /// `num.clamp()` returns `num`, not `double` — this keeps callers honest
  /// about the type without a cast at every use site.
  double _clamp01(double v) => v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: _pieRadius * 2 + 60,
                  height: _pieRadius * 2 + 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: List.generate(_sliceCount, (i) => _buildSlice(i, t)),
                  ),
                ),
                const SizedBox(height: 8),
                _buildWordmark(t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlice(int index, double t) {
    const sweep = 360 / _sliceCount;
    final startAngle = -90 + index * sweep; // 12 o'clock, clockwise

    // Stagger each slice's own arrival so they don't all move in lockstep.
    final start = index * 0.09;
    final end = _clamp01(start + 0.5);
    final progress = _sub(t, start, end, Curves.easeOutBack);

    // Fly in from along the slice's own mid-angle, outside the frame.
    final midAngleRad = (startAngle + sweep / 2) * math.pi / 180;
    final remaining = (1 - progress);
    final offset = Offset(
      math.cos(midAngleRad) * _flyDistance * remaining,
      math.sin(midAngleRad) * _flyDistance * remaining,
    );

    final opacity = _clamp01(progress);
    final scale = 0.35 + 0.65 * opacity;
    final spin = (index.isEven ? -0.5 : 0.5) * remaining;

    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: spin,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: const Size(_pieRadius * 2, _pieRadius * 2),
              painter: _PieSlicePainter(
                startAngleDeg: startAngle,
                sweepAngleDeg: sweep,
                color: kPieColors[index % kPieColors.length],
                radius: _pieRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordmark(double t) {
    final progress = _clamp01(_sub(t, 0.55, 1.0, Curves.easeOut));
    return Opacity(
      opacity: progress,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - progress)),
        child: const Text(
          'SplitNaija',
          style: TextStyle(
            fontFamily: kFontFamily,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: kBrandPurple,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

class _PieSlicePainter extends CustomPainter {
  const _PieSlicePainter({
    required this.startAngleDeg,
    required this.sweepAngleDeg,
    required this.color,
    required this.radius,
  });

  final double startAngleDeg;
  final double sweepAngleDeg;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(rect, startAngleDeg * math.pi / 180, sweepAngleDeg * math.pi / 180, false)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _PieSlicePainter oldDelegate) {
    return oldDelegate.startAngleDeg != startAngleDeg ||
        oldDelegate.sweepAngleDeg != sweepAngleDeg ||
        oldDelegate.color != color ||
        oldDelegate.radius != radius;
  }
}
