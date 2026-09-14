import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/domain/round.dart';

const _origin = Point<double>(0, 0);
Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// A stand-in Mode: finishes when every Finger has lifted, ranking by Lift
/// time, or when told to via [finishAt]. Can be told to abort.
class ScriptedSession implements ModeSession {
  ScriptedSession(this.fingers, this.lockInAt);

  final List<Finger> fingers;
  final Duration lockInAt;
  final lifts = <(Finger, Duration)>[];
  Duration? finishAt;
  bool abortOnNextLift = false;
  int advances = 0;

  @override
  Ranking? ranking;

  @override
  Duration? get nextDeadline => ranking == null ? finishAt : null;

  @override
  List<RoundEffect> fingerUp(Finger finger, Duration time) {
    lifts.add((finger, time));
    if (abortOnNextLift) return [const Aborted(AbortReason.everyoneLetGo)];
    if (fingers.every((f) => !f.isHeld)) _finish();
    return const [];
  }

  @override
  List<RoundEffect> advance(Duration time) {
    advances++;
    if (finishAt != null && time >= finishAt! && ranking == null) _finish();
    return const [];
  }

  void _finish() {
    final ordered = List.of(fingers)
      ..sort((a, b) => (a.liftedAt ?? s(999)).compareTo(b.liftedAt ?? s(999)));
    ranking = Ranking(ordered, decidedPlaces: ordered.length);
  }
}

class Harness {
  ScriptedSession? session;
  late final Round round = Round(startMode: (fingers, at) {
    return session = ScriptedSession(fingers, at);
  });
}

Harness locked({int count = 2}) {
  final h = Harness();
  for (var i = 0; i < count; i++) {
    h.round.fingerDown(i, _origin, s(0));
  }
  h.round.advance(s(3));
  expect(h.round.phase, RoundPhase.playing);
  return h;
}

void main() {
  group('Gathering', () {
    test('a single finger never locks in', () {
      final round = Harness().round;
      round.fingerDown(0, _origin, s(0));
      expect(round.nextDeadline, isNull);
      round.advance(s(10));
      expect(round.phase, RoundPhase.gathering);
      expect(round.session, isNull);
    });

    test('two fingers unchanged for 3 seconds lock in and start the Mode', () {
      final h = Harness();
      h.round.fingerDown(0, _origin, s(0));
      final effects = h.round.fingerDown(1, _origin, s(0.5));
      expect(effects.single, isA<FingerLanded>());
      expect(h.round.nextDeadline, s(3.5));

      expect(h.round.advance(s(3.4)), isEmpty);
      final locked = h.round.advance(s(3.5));
      expect(locked.single, isA<LockedIn>());
      expect(h.round.phase, RoundPhase.playing);
      expect(h.round.lockInAt, s(3.5));
      expect(h.session!.lockInAt, s(3.5));
      expect(h.session!.fingers.map((f) => f.id), [0, 1]);
    });

    test('a new finger restarts the stability window', () {
      final round = Harness().round;
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.fingerDown(2, _origin, s(2.9));
      round.advance(s(3));
      expect(round.phase, RoundPhase.gathering);
      round.advance(s(5.9));
      expect(round.phase, RoundPhase.playing);
    });

    test('a finger leaving restarts the window and has no consequence', () {
      final round = Harness().round;
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.fingerDown(2, _origin, s(0));
      final effects = round.fingerUp(2, s(2));
      expect(effects.single, isA<FingerLeft>());
      expect(round.fingers.length, 2);
      expect(round.nextDeadline, s(5));
    });

    test('dropping below two fingers cancels the window', () {
      final round = Harness().round;
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.fingerUp(1, s(1));
      expect(round.nextDeadline, isNull);
    });

    test('moving updates position and emits nothing', () {
      final round = Harness().round;
      round.fingerDown(0, _origin, s(0));
      expect(round.fingerMove(0, const Point(10, 20)), isEmpty);
      expect(round.fingers.single.position, const Point<double>(10, 20));
    });
  });

  group('Playing', () {
    test('lifts are recorded on the Finger and forwarded to the Mode', () {
      final h = locked();
      h.round.fingerUp(0, s(4));
      expect(h.session!.lifts.single.$1.id, 0);
      expect(h.session!.lifts.single.$2, s(4));
      expect(h.round.fingers.first.liftedAt, s(4));
      expect(h.round.phase, RoundPhase.playing);
    });

    test('a finger landing while playing is ignored, and so is its lift', () {
      final h = locked();
      final landing = h.round.fingerDown(99, _origin, s(4));
      expect(landing, isEmpty);
      expect(h.round.fingers.length, 2);
      expect(h.round.fingerUp(99, s(5)), isEmpty);
      expect(h.session!.lifts, isEmpty);
    });

    test('time is forwarded to the Mode and its deadline drives the shell',
        () {
      final h = locked();
      h.session!.finishAt = s(8);
      expect(h.round.nextDeadline, s(8));
      h.round.advance(s(7));
      expect(h.round.phase, RoundPhase.playing);
      final effects = h.round.advance(s(8));
      expect(effects.single, isA<RoundFinished>());
      expect(h.round.phase, RoundPhase.results);
      expect(h.round.nextDeadline, isNull);
    });

    test('when the Mode has a Ranking the Round shows Results', () {
      final h = locked();
      h.round.fingerUp(1, s(4));
      final effects = h.round.fingerUp(0, s(5));
      final finished = effects.single as RoundFinished;
      expect(finished.ranking.ordered.map((f) => f.id), [1, 0]);
      expect(finished.ranking.placeOf(h.round.fingers[1]), 1);
      expect(h.round.ranking, same(finished.ranking));
      expect(h.round.session, isNotNull, reason: 'kept for Results detail');
    });

    test('a Mode asking to abort aborts the Round', () {
      final h = locked();
      h.session!.abortOnNextLift = true;
      final effects = h.round.fingerUp(0, s(4));
      expect(effects.single, isA<Aborted>());
      expect((effects.single as Aborted).reason, AbortReason.everyoneLetGo);
      expect(h.round.phase, RoundPhase.aborted);
      expect(h.round.fingers, isEmpty);
      expect(h.round.session, isNull);
    });
  });

  group('Results and new Rounds', () {
    test('a finger landing during Results starts a fresh Round', () {
      final h = locked();
      h.round.fingerUp(0, s(4));
      h.round.fingerUp(1, s(4));
      expect(h.round.phase, RoundPhase.results);

      final effects = h.round.fingerDown(50, _origin, s(20));
      expect(effects.single, isA<FingerLanded>());
      expect(h.round.phase, RoundPhase.gathering);
      expect(h.round.fingers.single.ordinal, 0);
      expect(h.round.ranking, isNull);
      expect(h.round.session, isNull);
    });

    test('a leftover finger lifting during Results changes nothing', () {
      final h = locked();
      h.session!.finishAt = s(8);
      h.round.fingerUp(0, s(4));
      h.round.advance(s(8));
      final before = h.round.ranking;
      expect(h.round.fingerUp(1, s(9)), isEmpty);
      expect(h.round.ranking, same(before));
    });
  });

  group('Aborted', () {
    test('cancelling all touches aborts Gathering or Playing', () {
      for (final (setup, at) in <(Harness Function(), Duration)>[
        (() => Harness()..round.fingerDown(0, _origin, s(0)), s(1)),
        (locked, s(3.5)),
      ]) {
        final h = setup();
        final effects = h.round.cancelAll(at, AbortReason.touchesCancelled);
        expect(effects.last, isA<Aborted>());
        expect(h.round.phase, RoundPhase.aborted);
        expect(h.round.fingers, isEmpty);
        expect(h.round.nextDeadline, isNull);
      }
    });

    test('losing focus during Results keeps the Results', () {
      final h = locked();
      h.session!.finishAt = s(8);
      h.round.fingerUp(0, s(4));
      h.round.advance(s(8));
      final effects = h.round.cancelAll(s(9), AbortReason.lostFocus);
      expect(effects.whereType<Aborted>(), isEmpty);
      expect(h.round.phase, RoundPhase.results);
    });

    test('the next finger after Aborted begins Gathering', () {
      final h = locked();
      h.round.cancelAll(s(5), AbortReason.touchesCancelled);
      h.round.fingerDown(3, _origin, s(6));
      expect(h.round.phase, RoundPhase.gathering);
      expect(h.round.fingers.single.ordinal, 0);
    });
  });

  group('Ranking', () {
    test('placeOf is null beyond the decided Places', () {
      final a = Finger(id: 1, ordinal: 0, landedAt: s(0), position: _origin);
      final b = Finger(id: 2, ordinal: 1, landedAt: s(1), position: _origin);
      final r = Ranking([b, a], decidedPlaces: 1);
      expect(r.placeOf(b), 1);
      expect(r.placeOf(a), isNull);
      expect(r.first, same(b));
      expect(Ranking([b, a], decidedPlaces: 0).first, isNull);
    });
  });
}
