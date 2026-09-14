import '../domain/modes/classic/classic_config.dart';
import '../domain/modes/race/race_config.dart';
import '../domain/round_config.dart';
import 'app_config.dart';

/// JSON shape for tuning without recompiling. Durations are in seconds and
/// may be fractional unless the key says `Ms`. Missing or malformed keys
/// fall back to the built-in defaults.
///
/// ```json
/// {
///   "minFingers": 2,
///   "gatheringStabilitySeconds": 3,
///   "beatSeconds": 1,
///   "modes": {
///     "race": {
///       "countdownFrom": 3,
///       "straggler": {
///         "afterSeconds": 2,
///         "messageCount": 3,
///         "messageSeconds": 1,
///         "messages": ["Still there?", "You can let go now."]
///       }
///     },
///     "classic": {
///       "suspenseSeconds": 3,
///       "firstHopMs": 90,
///       "hopGrowth": 1.16,
///       "maxHopMs": 450
///     }
///   }
/// }
/// ```
///
/// A Race closes `afterSeconds + messageCount * messageSeconds` after Go.
/// Older files with `countdownFrom` and `straggler` at the top level are
/// still read.
AppConfig appConfigFromJson(
  Map<String, Object?> json, {
  AppConfig base = const AppConfig(),
}) {
  final modes = _map(json['modes']);
  final race = _map(modes['race']);
  final classic = _map(modes['classic']);
  final straggler = _map(race['straggler'] ?? json['straggler']);

  final messages = straggler['messages'];
  final messageList = messages is List
      ? messages
          .whereType<String>()
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList()
      : const <String>[];

  final b = base.round;
  final r = base.race;
  final c = base.classic;
  return AppConfig(
    round: RoundConfig(
      minFingers: _intOr(json['minFingers'], b.minFingers, min: 2),
      gatheringStability:
          _secondsOr(json['gatheringStabilitySeconds'], b.gatheringStability),
      beat: _secondsOr(json['beatSeconds'], b.beat),
    ),
    race: RaceConfig(
      countdownFrom:
          _intOr(race['countdownFrom'] ?? json['countdownFrom'], r.countdownFrom),
      stragglerAfter: _secondsOr(
          straggler['afterSeconds'] ?? json['stragglerAfterSeconds'],
          r.stragglerAfter),
      stragglerMessageCount:
          _intOr(straggler['messageCount'], r.stragglerMessageCount, min: 0),
      stragglerMessageInterval:
          _secondsOr(straggler['messageSeconds'], r.stragglerMessageInterval),
    ),
    classic: ClassicConfig(
      suspense: _secondsOr(classic['suspenseSeconds'], c.suspense),
      firstHop: _millisOr(classic['firstHopMs'], c.firstHop),
      hopGrowth: _doubleOr(classic['hopGrowth'], c.hopGrowth, min: 1.0),
      maxHop: _millisOr(classic['maxHopMs'], c.maxHop),
    ),
    stragglerMessages:
        messageList.isNotEmpty ? messageList : base.stragglerMessages,
  );
}

Map<String, Object?> appConfigToJson(AppConfig c) => {
      'minFingers': c.round.minFingers,
      'gatheringStabilitySeconds': _seconds(c.round.gatheringStability),
      'beatSeconds': _seconds(c.round.beat),
      'modes': {
        'race': {
          'countdownFrom': c.race.countdownFrom,
          'straggler': {
            'afterSeconds': _seconds(c.race.stragglerAfter),
            'messageCount': c.race.stragglerMessageCount,
            'messageSeconds': _seconds(c.race.stragglerMessageInterval),
            'messages': c.stragglerMessages,
          },
        },
        'classic': {
          'suspenseSeconds': _seconds(c.classic.suspense),
          'firstHopMs': c.classic.firstHop.inMilliseconds,
          'hopGrowth': c.classic.hopGrowth,
          'maxHopMs': c.classic.maxHop.inMilliseconds,
        },
      },
    };

Map<String, Object?> _map(Object? v) =>
    v is Map<String, Object?> ? v : const {};

int _intOr(Object? v, int fallback, {int min = 1}) =>
    v is num && v >= min ? v.toInt() : fallback;

double _doubleOr(Object? v, double fallback, {double min = 0}) =>
    v is num && v > min ? v.toDouble() : fallback;

Duration _secondsOr(Object? v, Duration fallback) => v is num && v > 0
    ? Duration(microseconds: (v * 1000000).round())
    : fallback;

Duration _millisOr(Object? v, Duration fallback) => v is num && v > 0
    ? Duration(microseconds: (v * 1000).round())
    : fallback;

num _seconds(Duration d) {
  final s = d.inMicroseconds / 1000000;
  return s == s.roundToDouble() ? s.round() : s;
}

/// One line for the debug caption, e.g.
/// "lock-in 1.5s · beat 1s · 3-2-1 · race 5s" for Race.
String describeConfig(AppConfig c, String modeId) {
  final shared = 'lock-in ${_seconds(c.round.gatheringStability)}s · '
      'beat ${_seconds(c.round.beat)}s';
  switch (modeId) {
    case 'race':
      final countdown = List.generate(
          c.race.countdownFrom, (i) => '${c.race.countdownFrom - i}').join('-');
      return '$shared · $countdown · race ${_seconds(c.race.raceDuration)}s';
    case 'classic':
      return '$shared · suspense ${_seconds(c.classic.suspense)}s';
    default:
      return shared;
  }
}
