import '../domain/round_config.dart';

/// JSON shape for tuning a Round without recompiling. Durations are in
/// seconds and may be fractional. Missing or malformed keys fall back to the
/// value in [base].
///
/// ```json
/// {
///   "minFingers": 2,
///   "gatheringStabilitySeconds": 3.0,
///   "beatSeconds": 1.0,
///   "countdownFrom": 3,
///   "stragglerAfterSeconds": 2.0,
///   "raceDurationSeconds": 5.0
/// }
/// ```
RoundConfig roundConfigFromJson(
  Map<String, Object?> json, {
  RoundConfig base = const RoundConfig(),
}) {
  int intOr(String key, int fallback, {int min = 1}) {
    final v = json[key];
    if (v is num && v >= min) return v.toInt();
    return fallback;
  }

  Duration secondsOr(String key, Duration fallback) {
    final v = json[key];
    if (v is num && v > 0) {
      return Duration(microseconds: (v * 1000000).round());
    }
    return fallback;
  }

  return RoundConfig(
    minFingers: intOr('minFingers', base.minFingers, min: 2),
    gatheringStability:
        secondsOr('gatheringStabilitySeconds', base.gatheringStability),
    beat: secondsOr('beatSeconds', base.beat),
    countdownFrom: intOr('countdownFrom', base.countdownFrom),
    stragglerAfter: secondsOr('stragglerAfterSeconds', base.stragglerAfter),
    raceDuration: secondsOr('raceDurationSeconds', base.raceDuration),
  );
}

Map<String, Object?> roundConfigToJson(RoundConfig c) => {
      'minFingers': c.minFingers,
      'gatheringStabilitySeconds': _seconds(c.gatheringStability),
      'beatSeconds': _seconds(c.beat),
      'countdownFrom': c.countdownFrom,
      'stragglerAfterSeconds': _seconds(c.stragglerAfter),
      'raceDurationSeconds': _seconds(c.raceDuration),
    };

num _seconds(Duration d) {
  final s = d.inMicroseconds / 1000000;
  return s == s.roundToDouble() ? s.round() : s;
}

/// One line for the debug caption, e.g. "lock-in 1.5s · beat 1s · 3-2-1".
String describeRoundConfig(RoundConfig c) {
  final countdown =
      List.generate(c.countdownFrom, (i) => '${c.countdownFrom - i}').join('-');
  return 'lock-in ${_seconds(c.gatheringStability)}s · '
      'beat ${_seconds(c.beat)}s · $countdown · '
      'race ${_seconds(c.raceDuration)}s';
}
