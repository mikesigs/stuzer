import 'dart:math';

import '../../effects.dart';
import '../../finger.dart';
import '../../mode.dart';
import 'classic_config.dart';
import 'classic_effects.dart';

export 'classic_config.dart';
export 'classic_effects.dart';

enum ClassicPhase { locked, suspense, done }

/// Classic Mode: a Spotlight hops between held Fingers with a slowing
/// rhythm and stops on one at random. Only first Place is decided.
///
/// Timeline from Lock-in at L with beat b: Locked until L+b, Suspense until
/// L+b+suspense, hops starting every [ClassicConfig.firstHop] and slowing
/// geometrically to [ClassicConfig.maxHop].
class ClassicSession implements ModeSession {
  ClassicSession({
    required this._fingers,
    required Duration lockInAt,
    required Duration beat,
    this.config = const ClassicConfig(),
    Random? random,
  })  : _random = random ?? Random(),
        _lockedUntil = lockInAt + beat,
        _suspenseEnd = lockInAt + beat + config.suspense,
        _hopInterval = config.firstHop;

  final List<Finger> _fingers;
  final ClassicConfig config;
  final Random _random;
  final Duration _lockedUntil;
  final Duration _suspenseEnd;

  ClassicPhase _phase = ClassicPhase.locked;
  Duration _hopInterval;
  Duration? _nextHopAt;
  Finger? _spotlight;
  Finger? _chosen;
  Ranking? _ranking;

  ClassicPhase get phase => _phase;

  /// The Finger currently lit, once Suspense has begun.
  Finger? get spotlight => _spotlight;

  /// The Finger the Spotlight stopped on, once decided.
  Finger? get chosen => _chosen;

  /// 0..1 through Suspense, for the presentation to build tension on.
  double suspenseProgress(Duration now) {
    final total = _suspenseEnd - _lockedUntil;
    if (total <= Duration.zero) return 1;
    final p = (now - _lockedUntil).inMicroseconds / total.inMicroseconds;
    return p.clamp(0.0, 1.0);
  }

  List<Finger> get heldFingers => _fingers.where((f) => f.isHeld).toList();

  @override
  Ranking? get ranking => _ranking;

  @override
  Duration? get nextDeadline => switch (_phase) {
        ClassicPhase.locked => _lockedUntil,
        ClassicPhase.suspense =>
          _nextHopAt! < _suspenseEnd ? _nextHopAt : _suspenseEnd,
        ClassicPhase.done => null,
      };

  @override
  List<RoundEffect> fingerUp(Finger finger, Duration time) {
    if (_phase == ClassicPhase.done) return const [];
    final effects = <RoundEffect>[DroppedOut(finger)];
    final held = heldFingers;
    if (held.isEmpty) {
      return [const Aborted(AbortReason.everyoneLetGo)];
    }
    if (_spotlight == finger) {
      // The lit Finger left; the Spotlight must land on someone still in.
      _spotlight = _pick(held, avoid: finger);
      effects.add(SpotlightMoved(_spotlight!));
    }
    return effects;
  }

  @override
  List<RoundEffect> advance(Duration time) {
    final effects = <RoundEffect>[];
    while (true) {
      final due = nextDeadline;
      if (due == null || due > time) break;
      switch (_phase) {
        case ClassicPhase.locked:
          _phase = ClassicPhase.suspense;
          _hop(due, effects);
        case ClassicPhase.suspense:
          if (due >= _suspenseEnd) {
            _stop(effects);
          } else {
            _hop(due, effects);
          }
        case ClassicPhase.done:
          return effects;
      }
    }
    return effects;
  }

  void _hop(Duration at, List<RoundEffect> effects) {
    final held = heldFingers;
    if (held.isEmpty) {
      effects.add(const Aborted(AbortReason.everyoneLetGo));
      _phase = ClassicPhase.done;
      return;
    }
    _spotlight = _pick(held, avoid: _spotlight);
    effects.add(SpotlightMoved(_spotlight!));
    _nextHopAt = at + _hopInterval;
    final grown = Duration(
        microseconds: (_hopInterval.inMicroseconds * config.hopGrowth).round());
    _hopInterval = grown < config.maxHop ? grown : config.maxHop;
  }

  void _stop(List<RoundEffect> effects) {
    _phase = ClassicPhase.done;
    final chosen = _spotlight!;
    _chosen = chosen;
    final rest = _fingers.where((f) => f != chosen).toList()
      ..sort(Ranking.byLanding);
    _ranking = Ranking([chosen, ...rest], decidedPlaces: 1);
    effects.add(Chosen(chosen));
  }

  /// A random Finger from [held], not [avoid] when there is a choice.
  Finger _pick(List<Finger> held, {Finger? avoid}) {
    final candidates =
        held.length > 1 ? held.where((f) => f != avoid).toList() : held;
    return candidates[_random.nextInt(candidates.length)];
  }
}
