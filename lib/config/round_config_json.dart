import '../domain/round_config.dart';
import 'app_config.dart';

/// JSON shape for tuning without recompiling. Durations are in seconds and
/// may be fractional. Missing or malformed keys fall back to the built-in
/// defaults.
///
/// ```json
/// {
///   "minFingers": 2,
///   "gatheringStabilitySeconds": 3,
///   "beatSeconds": 1,
///   "countdownFrom": 3,
///   "straggler": {
///     "afterSeconds": 2,
///     "messageCount": 3,
///     "messageSeconds": 1,
///     "messages": ["Still there?", "You can let go now."]
///   }
/// }
/// ```
///
/// The Race closes `afterSeconds + messageCount * messageSeconds` after Go.
AppConfig appConfigFromJson(
  Map<String, Object?> json, {
  AppConfig base = const AppConfig(),
}) {
  final b = base.round;
  final straggler = json['straggler'];
  final s = straggler is Map<String, Object?> ? straggler : const {};

  final messages = s['messages'];
  final messageList = messages is List
      ? messages.whereType<String>().map((m) => m.trim()).where((m) => m.isNotEmpty).toList()
      : const <String>[];

  return AppConfig(
    round: RoundConfig(
      minFingers: _intOr(json['minFingers'], b.minFingers, min: 2),
      gatheringStability:
          _secondsOr(json['gatheringStabilitySeconds'], b.gatheringStability),
      beat: _secondsOr(json['beatSeconds'], b.beat),
      countdownFrom: _intOr(json['countdownFrom'], b.countdownFrom),
      stragglerAfter: _secondsOr(
          s['afterSeconds'] ?? json['stragglerAfterSeconds'], b.stragglerAfter),
      stragglerMessageCount:
          _intOr(s['messageCount'], b.stragglerMessageCount, min: 0),
      stragglerMessageInterval:
          _secondsOr(s['messageSeconds'], b.stragglerMessageInterval),
    ),
    stragglerMessages:
        messageList.isNotEmpty ? messageList : base.stragglerMessages,
  );
}

Map<String, Object?> appConfigToJson(AppConfig c) => {
      'minFingers': c.round.minFingers,
      'gatheringStabilitySeconds': _seconds(c.round.gatheringStability),
      'beatSeconds': _seconds(c.round.beat),
      'countdownFrom': c.round.countdownFrom,
      'straggler': {
        'afterSeconds': _seconds(c.round.stragglerAfter),
        'messageCount': c.round.stragglerMessageCount,
        'messageSeconds': _seconds(c.round.stragglerMessageInterval),
        'messages': c.stragglerMessages,
      },
    };

int _intOr(Object? v, int fallback, {int min = 1}) =>
    v is num && v >= min ? v.toInt() : fallback;

Duration _secondsOr(Object? v, Duration fallback) => v is num && v > 0
    ? Duration(microseconds: (v * 1000000).round())
    : fallback;

num _seconds(Duration d) {
  final s = d.inMicroseconds / 1000000;
  return s == s.roundToDouble() ? s.round() : s;
}

/// One line for the debug caption, e.g. "lock-in 1.5s · beat 1s · 3-2-1 · race 5s".
String describeRoundConfig(RoundConfig c) {
  final countdown =
      List.generate(c.countdownFrom, (i) => '${c.countdownFrom - i}').join('-');
  return 'lock-in ${_seconds(c.gatheringStability)}s · '
      'beat ${_seconds(c.beat)}s · $countdown · '
      'race ${_seconds(c.raceDuration)}s';
}
