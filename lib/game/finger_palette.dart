import 'package:flutter/painting.dart';

/// Colour for the Finger with the given landing ordinal.
///
/// Uses the golden angle so every Finger gets a hue far from the ones before
/// it, without any existing Finger changing colour when a new one lands, and
/// with no cap on how many Fingers can be told apart.
Color fingerColor(int ordinal) {
  const goldenAngle = 137.50776405;
  final hue = (ordinal * goldenAngle) % 360.0;
  return HSLColor.fromAHSL(1, hue, 0.85, 0.55).toColor();
}
