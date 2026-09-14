import 'package:flutter/painting.dart';

/// Colour for the Finger with the given landing ordinal.
///
/// Uses the golden angle so every Finger gets a hue far from the ones before
/// it, without any existing Finger changing colour when a new one lands, and
/// with no cap on how many Fingers can be told apart. Hues stay out of the
/// red band, which is reserved for the False Start alarm.
Color fingerColor(int ordinal) {
  const goldenAngle = 137.50776405;
  const redBand = 50.0; // degrees either side of 0 to avoid
  final spread = (ordinal * goldenAngle) % (360.0 - 2 * redBand);
  final hue = redBand + spread;
  return HSLColor.fromAHSL(1, hue, 0.85, 0.55).toColor();
}
