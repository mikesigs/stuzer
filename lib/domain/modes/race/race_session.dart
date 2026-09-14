import '../../effects.dart';
import '../../finger.dart';
import '../../mode.dart';
import 'race_config.dart';
import 'race_effects.dart';
import 'standings.dart';

export 'race_config.dart';
export 'race_effects.dart';
export 'standings.dart';

/// Where a Race is. Locked one beat, Countdown, then Racing after Go.
enum RacePhase { locked, countdown, racing, done }

/// Race Mode: after Go, the fastest Finger off the screen is first.
///
/// Timeline from Lock-in at L with beat b and countdownFrom n:
/// Locked until L+b, ticks n..1 at L+b .. L+n*b, Go at L+(n+1)*b.
class RaceSession implements ModeSession {
  RaceSession({
    required this._fingers,
    required this.lockInAt,
    required this.beat,
    this.config = const RaceConfig(),
  }) : _nextDeadline = lockInAt + beat;

  final List<Finger> _fingers;
  final Duration lockInAt;
  final Duration beat;
  final RaceConfig config;

  RacePhase _phase = RacePhase.locked;
  Duration? _goAt;
  Duration? _nextTeaseAt;
  Duration? _closeAt;
  int? _countdownNumber;
  int _teaseCount = 0;
  List<Placement>? _placements;
  Ranking? _ranking;
  Duration? _nextDeadline;

  RacePhase get phase => _phase;
  Duration? get goAt => _goAt;

  /// Number currently shown during Countdown, else null.
  int? get countdownNumber =>
      _phase == RacePhase.countdown ? _countdownNumber : null;

  /// Final standings once the Race has closed, else null.
  List<Placement>? get placements => _placements;

  List<Finger> get heldFingers => _fingers.where((f) => f.isHeld).toList();

  @override
  Ranking? get ranking => _ranking;

  @override
  Duration? get nextDeadline => _nextDeadline;

  /// True once the Countdown has spoken "1". From then on, everyone letting
  /// go is a False Start across the board rather than an abort.
  bool get _finalBeatStarted =>
      _phase == RacePhase.countdown && _countdownNumber == 1;

  @override
  List<RoundEffect> fingerUp(Finger finger, Duration time) {
    final effects = <RoundEffect>[];
    switch (_phase) {
      case RacePhase.locked:
      case RacePhase.countdown:
        if (heldFingers.isEmpty && !_finalBeatStarted) {
          // Nobody left to race, and the Round has not reached the "1" beat.
          // Abort now rather than make the table sit through the Countdown.
          effects.add(const Aborted(AbortReason.everyoneLetGo));
        } else {
          effects.add(FalseStarted(finger));
        }
      case RacePhase.racing:
        if (time < _goAt!) {
          // Late-delivered event that really happened before Go.
          effects.add(FalseStarted(finger));
        } else {
          effects.add(Lifted(finger, _legitimateLiftCount()));
        }
        if (heldFingers.isEmpty) _close();
      case RacePhase.done:
        break;
    }
    return effects;
  }

  @override
  List<RoundEffect> advance(Duration time) {
    final effects = <RoundEffect>[];
    while (_nextDeadline != null && _nextDeadline! <= time) {
      final due = _nextDeadline!;
      switch (_phase) {
        case RacePhase.locked:
          _phase = RacePhase.countdown;
          _countdownNumber = config.countdownFrom;
          effects.add(CountdownTick(_countdownNumber!));
          _nextDeadline = due + beat;
        case RacePhase.countdown:
          if (_countdownNumber! > 1) {
            _countdownNumber = _countdownNumber! - 1;
            effects.add(CountdownTick(_countdownNumber!));
            _nextDeadline = due + beat;
          } else {
            _go(due, effects);
          }
        case RacePhase.racing:
          if (due >= _closeAt!) {
            _close();
          } else {
            effects.add(StragglersTeased(heldFingers, _teaseCount++));
            _nextTeaseAt = due + config.stragglerMessageInterval;
            _scheduleRaceDeadline();
          }
        case RacePhase.done:
          _nextDeadline = null;
      }
    }
    return effects;
  }

  int _legitimateLiftCount() => _fingers
      .where((f) => f.liftedAt != null && f.liftedAt! >= _goAt!)
      .length;

  void _go(Duration at, List<RoundEffect> effects) {
    _phase = RacePhase.racing;
    _goAt = at;
    _countdownNumber = null;
    _closeAt = at + config.raceDuration;
    _nextTeaseAt = at + config.stragglerAfter;
    effects.add(const Go());
    if (heldFingers.isEmpty) {
      _close();
    } else {
      _scheduleRaceDeadline();
    }
  }

  void _scheduleRaceDeadline() {
    final tease = _nextTeaseAt!;
    _nextDeadline = tease < _closeAt! ? tease : _closeAt;
  }

  void _close() {
    _phase = RacePhase.done;
    final placements = rankFingers(_fingers, _goAt!);
    _placements = placements;
    _ranking = Ranking(
      placements.map((p) => p.finger).toList(),
      decidedPlaces: placements.length,
    );
    _nextDeadline = null;
  }
}
