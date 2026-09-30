import 'package:flutter/material.dart';

/// The app's colour palette, defined once so no screen hardcodes a hex value.
///
/// The brief: "white but not that much white" — a background that is a little
/// off-white / grayish-white, with a faint gray hint rather than pure #FFFFFF.
/// Cards and the nav bar are pure white so they lift gently off that backdrop.
abstract final class AppColors {
  const AppColors._();

  /// Page background — off-white with a barely-there warm gray tint. Sits just
  /// below pure white so white cards read as raised, not flush.
  static const Color background = Color(0xFFF4F4F2);

  /// Cards, the bottom nav bar, and the circular menu button. Pure white.
  static const Color surface = Color(0xFFFFFFFF);

  /// A slightly deeper gray-white for pressed/hover states on white surfaces.
  static const Color surfaceMuted = Color(0xFFECECEA);

  /// Hairline borders and dividers — soft gray, never harsh black.
  static const Color border = Color(0xFFE2E2DF);

  /// Primary text — near-black, softened so it isn't a hard #000 on off-white.
  static const Color textPrimary = Color(0xFF1F1F1D);

  /// Secondary text — muted gray for hints, captions, and helper links.
  static const Color textSecondary = Color(0xFF6E6E6A);

  /// Brand accent — carried over from the existing indigo seed so the auth
  /// screens don't clash with the rest of the app.
  static const Color accent = Color(0xFF4F46E5);

  /// Text/icons placed on top of [accent].
  static const Color onAccent = Color(0xFFFFFFFF);
}
