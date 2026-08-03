import 'package:flutter/material.dart';

/// A circular avatar showing a person's initials, tinted with a color
/// derived deterministically from [seed] (their id or name) so the same
/// person always gets the same color across the app.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, required this.seed, this.radius = 20});

  final String name;
  final String seed;
  final double radius;

  static const _palette = [
    Color(0xFF00A651),
    Color(0xFF1E88E5),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFF6D4C41),
    Color(0xFFD81B60),
  ];

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Color get _color => _palette[seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}