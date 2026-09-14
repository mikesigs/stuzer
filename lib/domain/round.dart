import 'dart:math';

import 'effects.dart';
import 'finger.dart';
import 'round_config.dart';
import 'standings.dart';

export 'effects.dart';
export 'finger.dart';
export 'round_config.dart';
export 'standings.dart';

/// Where a Round is in its lifecycle. See CONTEXT.md for the language.
enum RoundPhase { gathering, locked, countdown, race, results, aborted }

/// The Round state machine. Pure Dart, no timers, no Flutter.
///
/// Feed it timestamped finger events and call [advance] with the current
/// monotonic time; it returns the [RoundEffect]s the presentation should
/// react to. [nextDeadline] says when the next time-driven transition is due,
/// so the caller can schedule a single timer rather than polling.
class Round {
  Round({this.config = const RoundConfig()});

  final RoundConfig config;

  RoundPhase _phase = RoundPhase.gathering;
  final Map<int, Finger> _fingers = {};
  final Set<int> _ignoredPointers = {};
  int _nextOrdinal = 0;

  Duration? _lockInAt;
  Duration? _goAt;
  Duration? _nextTeaseAt;
  Duration? _closeAt;
  int? _countdownNumber;
  int _teaseCount = 0;
  List<Placement>? _placements;
  Duration? _nextDeadline;

  RoundPhase get phase => _phase;

  /// Fingers in this Round, in landing order. Includes lifted ones once the
  /// Round has left Gathering.
  List<Finger> get fingers =>
      _fingers.values.toList()..sort((a, b) => a.ordinal.compareTo(b.ordinal));

  List<Finger> get heldFingers => fingers.where((f) => f.isHeld).toList();

  /// When the next time-driven transition happens, or null if none is due.
  Duration? get nextDeadline => _nextDeadline;

  Duration? get lockInAt => _lockInAt;
  Duration? get goAt => _goAt;

  /// Number currently shown during Countdown, else null.
  int? get countdownNumber =>
      _phase == RoundPhase.countdown ? _countdownNumber : null;

  /// Final standings once the Race has closed, else null.
  List<Placement>? get placements => _placements;

  // ---------------------------------------------------------------- events

  List<RoundEffect> fingerDown(int pointer, Point<double> at, Duration time) {
    final effects = advance(time);
    if (_phase == RoundPhase.results || _phase == RoundPhase.aborted) {
      _reset();
    }
    switch (_phase) {
      case RoundPhase.gathering:
        final finger = Finger(
          id: pointer,
          ordinal: _nextOrdinal++,
          landedAt: time,
          position: at,
        );
        _fingers[pointer] = finger;
        _recomputeStability(time);
        effects.add(FingerLanded(finger));
      case RoundPhase.locked:
      case RoundPhase.countdown:
      case RoundPhase.race:
        _ignoredPointers.add(pointer);
      case RoundPhase.results:
      case RoundPhase.aborted:
        throw StateError('unreachable: reset above');
    }
    return effects;
  }

  List<RoundEffect> fingerMove(int pointer, Point<double> at) {
    final finger = _fingers[pointer];
    if (finger != null && finger.isHeld) finger.moveTo(at);
    return const [];
  }

  List<RoundEffect> fingerUp(int pointer, Duration time) {
    final effects = advance(time);
    if (_ignoredPointers.remove(pointer)) return effects;
    final finger = _fingers[pointer];
    if (finger == null || !finger.isHeld) return effects;

    switch (_phase) {
      case RoundPhase.gathering:
        _fingers.remove(pointer);
        _recomputeStability(time);
        effects.add(FingerLeft(finger));
      case RoundPhase.locked:
      case RoundPhase.countdown:
        finger.lift(time);
        if (heldFingers.isEmpty && !_finalBeatStarted) {
          // Nobody left to race, and the Round has not reached the "1" beat.
          // Abort now rather than make the table sit through the Countdown.
          _reset();
          _phase = RoundPhase.aborted;
          effects.add(const Aborted(AbortReason.everyoneLetGo));
        } else {
          effects.add(FalseStarted(finger));
        }
      case RoundPhase.race:
        finger.lift(time);
        if (time < _goAt!) {
          // Late-delivered event that really happened before Go.
          effects.add(FalseStarted(finger));
        } else {
          effects.add(Lifted(finger, _legitimateLiftCount()));
        }
        if (heldFingers.isEmpty) effects.add(_closeRace());
      case RoundPhase.results:
      case RoundPhase.aborted:
        break;
    }
    return effects;
  }

  /// The OS cancelled every touch, or the app lost focus.
  List<RoundEffect> cancelAll(Duration time, AbortReason reason) {
    final effects = advance(time);
    if (_phase == RoundPhase.results) {
      // Results stay up; only the held stragglers are gone.
      _ignoredPointers.clear();
      return effects;
    }
    _reset();
    _phase = RoundPhase.aborted;
    effects.add(Aborted(reason));
    return effects;
  }

  /// Fire every time-driven transition due at or before [time].
  List<RoundEffect> advance(Duration time) {
    final effects = <RoundEffect>[];
    while (_nextDeadline != null && _nextDeadline! <= time) {
      final due = _nextDeadline!;
      switch (_phase) {
        case RoundPhase.gathering:
          _lockIn(due, effects);
        case RoundPhase.locked:
          _phase = RoundPhase.countdown;
          _countdownNumber = config.countdownFrom;
          effects.add(CountdownTick(_countdownNumber!));
          _nextDeadline = due + config.beat;
        case RoundPhase.countdown:
          if (_countdownNumber! > 1) {
            _countdownNumber = _countdownNumber! - 1;
            effects.add(CountdownTick(_countdownNumber!));
            _nextDeadline = due + config.beat;
          } else {
            _go(due, effects);
          }
        case RoundPhase.race:
          if (due >= _closeAt!) {
            effects.add(_closeRace());
          } else {
            effects.add(StragglersTeased(heldFingers, _teaseCount++));
            _nextTeaseAt = due + config.stragglerMessageInterval;
            _scheduleRaceDeadline();
          }
        case RoundPhase.results:
        case RoundPhase.aborted:
          _nextDeadline = null;
      }
    }
    return effects;
  }

  // ----------------------------------------------------------- transitions

  /// True once the Countdown has spoken "1". From then on, everyone letting
  /// go is a False Start across the board rather than an abort.
  bool get _finalBeatStarted =>
      _phase == RoundPhase.countdown && _countdownNumber == 1;

  int _legitimateLiftCount() => _fingers.values
      .where((f) => f.liftedAt != null && f.liftedAt! >= _goAt!)
      .length;

  void _recomputeStability(Duration time) {
    _nextDeadline = _fingers.length >= config.minFingers
        ? time + config.gatheringStability
        : null;
  }

  void _lockIn(Duration at, List<RoundEffect> effects) {
    _phase = RoundPhase.locked;
    _lockInAt = at;
    _nextDeadline = at + config.beat;
    effects.add(LockedIn(fingers));
  }

  void _go(Duration at, List<RoundEffect> effects) {
    _phase = RoundPhase.race;
    _goAt = at;
    _countdownNumber = null;
    _closeAt = at + config.raceDuration;
    _nextTeaseAt = at + config.stragglerAfter;
    effects.add(const Go());
    if (heldFingers.isEmpty) {
      effects.add(_closeRace());
    } else {
      _scheduleRaceDeadline();
    }
  }

  void _scheduleRaceDeadline() {
    final tease = _nextTeaseAt!;
    _nextDeadline = tease < _closeAt! ? tease : _closeAt;
  }

  RaceClosed _closeRace() {
    _phase = RoundPhase.results;
    _placements = rankFingers(_fingers.values, _goAt!);
    _nextDeadline = null;
    _ignoredPointers.clear();
    return RaceClosed(_placements!);
  }

  void _reset() {
    _phase = RoundPhase.gathering;
    _fingers.clear();
    _ignoredPointers.clear();
    _nextOrdinal = 0;
    _lockInAt = null;
    _goAt = null;
    _nextTeaseAt = null;
    _closeAt = null;
    _countdownNumber = null;
    _teaseCount = 0;
    _placements = null;
    _nextDeadline = null;
  }
}
