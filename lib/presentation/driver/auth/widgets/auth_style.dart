import 'package:flutter/material.dart';

/// Colours and type of the sign-in flow, the rider app's "ink and green"
/// (owner round 3): black text and buttons on white and the cool pale
/// ground; green only for the accent word of a headline and the resend
/// timer. Kept local to the auth screens so the rest of the app's theme is
/// untouched.
abstract final class AuthColors {
  static const ground = Color(0xFFEEF1E8);

  /// The sign-in black: text, the wordmark, buttons, the pin.
  static const ink = Color(0xFF111214);
  static const muted = Color(0xFF65716B);

  /// ≥ 4.5:1 on [ground].
  static const faint = Color(0xFF676F6B);
  static const green = Color(0xFF147A50);
  static const deepGreen = Color(0xFF123F32);
  static const field = Color(0xFFF1F4F2);
  static const line = Color(0xFFE1E7E3);

  /// Underline of a resting input.
  static const underline = Color(0xFFD5DCD7);
  static const stepIdle = Color(0xFFDDE5DF);
  static const stepDone = Color(0xFF9BBEAA);

  /// Quiet grey for notes and chips.
  static const noteGround = Color(0xFFF3F4F5);
  static const noteText = Color(0xFF3A3F3C);
  static const error = Color(0xFFB3261E);

  /// A disabled primary button: the same black, very light.
  static const disabled = Color(0xFFF0F0F1);
  static const disabledText = Color(0xFFA6A7A9);
}

/// The sign-in face: Urbanist, bundled with the app (pubspec `fonts`), the
/// same face the rider sign-in uses and the radar orb's labels.
abstract final class AuthText {
  static const fontFamily = 'Urbanist';

  /// Urbanist in [weight] and [size]; the base of every style below.
  static TextStyle urbanist({
    double? size,
    FontWeight weight = FontWeight.w500,
    Color color = AuthColors.ink,
    double? height,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: fontFeatures,
  );

  static TextStyle headline(double size) => urbanist(
    size: size,
    height: 1.1,
    weight: FontWeight.w800,
    letterSpacing: -1.1,
  );

  static TextStyle lede() =>
      urbanist(size: 15, height: 1.45, color: AuthColors.muted);

  static TextStyle cardTitle() =>
      urbanist(size: 17, height: 1.3, weight: FontWeight.w600);

  static TextStyle cardSub() =>
      urbanist(size: 13.5, height: 1.4, color: AuthColors.muted);

  static TextStyle label() => urbanist(size: 12.5, weight: FontWeight.w600);

  static TextStyle input() => urbanist(size: 16);

  static TextStyle small() =>
      urbanist(size: 12, height: 1.45, color: AuthColors.faint);

  /// Body text in the sign-in font, for the few places that style inline.
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AuthColors.ink,
    double? height,
  }) => urbanist(size: size, weight: weight, color: color, height: height);
}
