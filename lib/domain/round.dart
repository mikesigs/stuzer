import 'dart:math';

import 'effects.dart';
import 'finger.dart';
import 'mode.dart';
import 'round_config.dart';

export 'effects.dart';
export 'finger.dart';
export 'mode.dart';
export 'round_config.dart';

/// Where a Round is in its lifecycle. See CONTEXT.md for the language.
/// While [playing], the Mode's session has the detail.
enum RoundPhase { gathering, playing, results, aborted }

/// The Round shell. Pure Dart, no timers, no Flutter.
///
/// Owns Gathering, Lock-in, Results, and Aborted for every Mode. At Lock-in
/// it builds a [ModeSession] with [startMode] and forwards Lifts and time to
/// it until the session has a [Ranking] or asks to abort.
///
/// Feed it timestamped finger events and call [advance] with the current
/// monotonic time; it returns the [RoundEffect]s the presentation should
/// react to. [nextDeadline] says when the next transition is due, so the
/// caller can schedule a single timer rather than polling.
class Round {
  Round({this.config = const RoundConfig(), required this.startMode});

  final RoundConfig config;
  final ModeSessionFactory startMode;

  RoundPhase _phase = RoundPhase.gathering;
  final Map<int, Finger> _fingers = {};
  final Set<int> _ignoredPointers = {};
  int _nextOrdinal = 0;
  Duration? _stableAt;
  Duration? _lockInAt;
  ModeSession? _session;
  Ranking? _ranking;

  RoundPhase get phase => _phase;

  /// Fingers in this Round, in landing order. Includes lifted ones once the
  /// Round has left Gathering.
  List<Finger> get fingers =>
      _fingers.values.toList()..sort((a, b) => a.ordinal.compareTo(b.ordinal));

  List<Finger> get heldFingers => fingers.where((f) => f.isHeld).toList();

  Duration? get lockInAt => _lockInAt;

  /// The Mode's session while playing, and kept through Results so the
  /// presentation can show Mode-specific detail.
  ModeSession? get session => _session;

  /// Final Ranking once the Mode has decided, else null.
  Ranking? get ranking => _ranking;

  /// When the next time-driven transition happens, or null if none is due.
  Duration? get nextDeadline => switch (_phase) {
        RoundPhase.gathering => _stableAt,
        RoundPhase.playing => _session!.nextDeadline,
        _ => null,
      };

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
      case RoundPhase.playing:
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
      case RoundPhase.playing:
        finger.lift(time);
        _delegate(effects, _session!.fingerUp(finger, time));
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
    _abort(reason, effects);
    return effects;
  }

  /// Fire every time-driven transition due at or before [time].
  List<RoundEffect> advance(Duration time) {
    final effects = <RoundEffect>[];
    while (true) {
      final due = nextDeadline;
      if (due == null || due > time) break;
      switch (_phase) {
        case RoundPhase.gathering:
          _lockIn(due, effects);
        case RoundPhase.playing:
          _delegate(effects, _session!.advance(time));
        case RoundPhase.results:
        case RoundPhase.aborted:
          return effects;
      }
    }
    return effects;
  }

  // ----------------------------------------------------------- transitions

  void _recomputeStability(Duration time) {
    _stableAt = _fingers.length >= config.minFingers
        ? time + config.gatheringStability
        : null;
  }

  void _lockIn(Duration at, List<RoundEffect> effects) {
    _phase = RoundPhase.playing;
    _lockInAt = at;
    _stableAt = null;
    _session = startMode(fingers, at);
    effects.add(LockedIn(fingers));
  }

  /// Fold a session's effects into ours and react to what they mean.
  void _delegate(List<RoundEffect> effects, List<RoundEffect> fromSession) {
    Aborted? abort;
    for (final e in fromSession) {
      if (e is Aborted) {
        abort = e;
      } else {
        effects.add(e);
      }
    }
    if (abort != null) {
      _abort(abort.reason, effects);
      return;
    }
    final ranking = _session!.ranking;
    if (ranking != null && _phase == RoundPhase.playing) {
      _phase = RoundPhase.results;
      _ranking = ranking;
      _ignoredPointers.clear();
      effects.add(RoundFinished(ranking));
    }
  }

  void _abort(AbortReason reason, List<RoundEffect> effects) {
    _reset();
    _phase = RoundPhase.aborted;
    effects.add(Aborted(reason));
  }

  void _reset() {
    _phase = RoundPhase.gathering;
    _fingers.clear();
    _ignoredPointers.clear();
    _nextOrdinal = 0;
    _stableAt = null;
    _lockInAt = null;
    _session = null;
    _ranking = null;
  }
}
