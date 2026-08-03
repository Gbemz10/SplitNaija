import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Three dots bouncing in a staggered wave — the loading indicator used
/// everywhere in this app instead of the stock `CircularProgressIndicator`,
/// from full-screen loads to small inline button spinners.
class BouncingDots extends StatefulWidget {
  const BouncingDots({super.key, this.color = Colors.white, this.size = 8});

  final Color color;

  /// Diameter of each dot. Spacing and bounce height both scale off this,
  /// so one number is enough to resize the whole thing for a given spot
  /// (a small one inside a button, a bigger one for a full-page loader).
  final double size;

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Reserves room for the bounce itself so the dots don't clip against
      // whatever's above them, and so this widget's own height stays fixed
      // regardless of animation phase (avoids other layout jumping around
      // it every frame).
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              // Each dot's phase is offset by a fifth of the cycle so they
              // bounce as a left-to-right wave rather than all in lockstep.
              final t = (_controller.value + i * 0.2) % 1.0;
              final bounce = math.sin(t * math.pi).clamp(0.0, 1.0); // 0 -> 1 -> 0
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.size * 0.25),
                child: Transform.translate(
                  offset: Offset(0, -bounce * widget.size),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
