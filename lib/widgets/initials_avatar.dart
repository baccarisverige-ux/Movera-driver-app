import 'package:flutter/material.dart';

/// L-a Q1 (owner 2026-11-06, "Real name, no photo"): a person is shown by
/// the initials of the name the server sent, in a circle. No stock photo
/// anywhere (driver menu, Profile, the rider sheet on a trip).
String initialsOf(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  String first(String word) => String.fromCharCodes(word.runes.take(1));
  final letters = words.length == 1
      ? first(words.first)
      : first(words.first) + first(words.last);
  return letters.toUpperCase();
}

/// A circle with [name]'s initials; a person icon when there is no name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    required this.radius,
    this.background = const Color(0xFF1C2421),
    this.foreground = Colors.white,
  });

  final String name;
  final double radius;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: initials.isEmpty
          ? Icon(Icons.person_rounded, color: foreground, size: radius)
          : Text(
              initials,
              style: TextStyle(
                color: foreground,
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
    );
  }
}
