import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'initials_avatar.dart';

/// Shows a person's real profile photo if they've set one (decoded from the
/// base64 data URI the backend stores on their User row), falling back to
/// [InitialsAvatar] otherwise. Used for a person's *own* avatar (Account
/// screen, the Groups header) — contexts with several people at once (like
/// member lists) still use bare [InitialsAvatar] on purpose, since a photo
/// only helps when it's clearly one specific person's.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.seed,
    this.photoUrl,
    this.radius = 20,
  });

  final String name;
  final String seed;
  final String? photoUrl;
  final double radius;

  static Uint8List? _decode(String? dataUri) {
    if (dataUri == null || dataUri.isEmpty) return null;
    final commaIndex = dataUri.indexOf(',');
    final base64Part = commaIndex == -1 ? dataUri : dataUri.substring(commaIndex + 1);
    try {
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(photoUrl);
    if (bytes == null) return InitialsAvatar(name: name, seed: seed, radius: radius);
    return CircleAvatar(radius: radius, backgroundImage: MemoryImage(bytes));
  }
}
