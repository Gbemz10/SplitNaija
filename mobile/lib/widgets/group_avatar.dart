import 'package:flutter/material.dart';
import '../theme.dart';

/// A colored circular badge for a group, tinted deterministically from
/// [kPieColors] based on the group's id — same trick as `InitialsAvatar`,
/// but drawing from the pie palette to keep the "shared slices" motif
/// visible wherever groups show up, not just on the splash/logo.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.name, required this.seed, this.radius = 24});

  final String name;
  final String seed;
  final double radius;

  Color get _color => kPieColors[seed.codeUnits.fold<int>(0, (a, b) => a + b) % kPieColors.length];

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color.withOpacity(0.15),
      child: Icon(Icons.groups_rounded, color: _color, size: radius * 0.95),
    );
  }
}
