import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/domain/round.dart';

const _origin = Point<double>(0, 0);
Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// Puts [count] fingers down at t=0 and advances to Lock-in at t=3s.
Round lockedRound({int count = 3}) {
  final round = Round();
  for (var i = 0; i < count; i++) {
    round.fingerDown(i, _origin, s(0));
  }
  round.advance(s(3));
  expect(round.phase, RoundPhase.locked);
  return round;
}

/// A locked Round advanced to Go. Lock-in at 3s, Go at 9s.
Round racingRound({int count = 3}) {
  final round = lockedRound(count: count);
  round.advance(s(9));
  expect(round.phase, RoundPhase.race);
  expect(round.goAt, s(9));
  return round;
}

List<int> placesOf(List<Placement> placements) =>
    placements.map((p) => p.finger.id).toList();

void main() {
  group('Gathering', () {
    test('a single finger never locks in', () {
      final round = Round();
      round.fingerDown(0, _origin, s(0));
      expect(round.nextDeadline, isNull);
      round.advance(s(10));
      expect(round.phase, RoundPhase.gathering);
    });

    test('two fingers unchanged for 3 seconds lock in', () {
      final round = Round();
      round.fingerDown(0, _origin, s(0));
      final effects = round.fingerDown(1, _origin, s(0.5));
      expect(effects.single, isA<FingerLanded>());
      expect(round.nextDeadline, s(3.5));

      expect(round.advance(s(3.4)), isEmpty);
      final locked = round.advance(s(3.5));
      expect(locked.single, isA<LockedIn>());
      expect(round.phase, RoundPhase.locked);
      expect(round.lockInAt, s(3.5));
    });

    test('a new finger restarts the stability window', () {
      final round = Round();
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.fingerDown(2, _origin, s(2.9));
      round.advance(s(3));
      expect(round.phase, RoundPhase.gathering);
      round.advance(s(5.9));
      expect(round.phase, RoundPhase.locked);
    });

    test('a finger leaving restarts the window and has no consequence', () {
      final round = Round();
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.fingerDown(2, _origin, s(0));
      final effects = round.fingerUp(2, s(2));
      expect(effects.single, isA<FingerLeft>());
      expect(round.fingers.length, 2);
      expect(round.nextDeadline, s(5));
    });

    test('dropping below two fingers cancels the window', () {
      final round = Round();
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.fingerUp(1, s(1));
      expect(round.nextDeadline, isNull);
    });

    test('moving updates position and emits nothing', () {
      final round = Round();
      round.fingerDown(0, _origin, s(0));
      expect(round.fingerMove(0, const Point(10, 20)), isEmpty);
      expect(round.fingers.single.position, const Point<double>(10, 20));
    });
  });

  group('Locked and Countdown', () {
    test('Locked lasts one beat, then 5..1 tick once per second, then Go', () {
      final round = lockedRound();
      expect(round.nextDeadline, s(4));

      final ticks = <int>[];
      for (var t = 4; t <= 8; t++) {
        final effects = round.advance(s(t));
        ticks.add((effects.single as CountdownTick).number);
        expect(round.countdownNumber, ticks.last);
      }
      expect(ticks, [5, 4, 3, 2, 1]);
      expect(round.phase, RoundPhase.countdown);

      final go = round.advance(s(9));
      expect(go.single, isA<Go>());
      expect(round.phase, RoundPhase.race);
      expect(round.goAt, s(9));
      expect(round.countdownNumber, isNull);
    });

    test('a big time jump fires every transition in order', () {
      final round = lockedRound();
      final effects = round.advance(s(9));
      expect(effects.map((e) => e.runtimeType).toList(), [
        CountdownTick,
        CountdownTick,
        CountdownTick,
        CountdownTick,
        CountdownTick,
        Go,
      ]);
    });

    test('a finger landing after Lock-in is ignored, and so is its lift', () {
      final round = lockedRound(count: 2);
      final landing = round.fingerDown(99, _origin, s(5));
      expect(landing.whereType<FingerLanded>(), isEmpty);
      expect(round.fingers.length, 2);
      round.advance(s(9));
      final lifting = round.fingerUp(99, s(9.1));
      expect(lifting.whereType<Lifted>(), isEmpty);
      expect(lifting.whereType<FalseStarted>(), isEmpty);
      expect(round.placements, isNull);
    });

    test('lifting during Locked or Countdown is a False Start', () {
      final round = lockedRound();
      final duringLocked = round.fingerUp(0, s(3.5));
      expect(duringLocked.single, isA<FalseStarted>());

      final duringCountdown = round.fingerUp(1, s(6));
      expect(duringCountdown.whereType<FalseStarted>().single.finger.id, 1);
      expect(round.phase, RoundPhase.countdown);
    });

    test('a False Starter who re-touches is ignored', () {
      final round = lockedRound();
      round.fingerUp(0, s(5));
      expect(round.fingerDown(7, _origin, s(5.1)).whereType<FingerLanded>(),
          isEmpty);
      round.advance(s(9));
      expect(round.fingerUp(7, s(9.2)).whereType<Lifted>(), isEmpty);
    });

    test('if everyone False Starts the Race closes at Go', () {
      final round = lockedRound(count: 2);
      round.fingerUp(0, s(5));
      round.fingerUp(1, s(6));
      final effects = round.advance(s(9));
      expect(effects.map((e) => e.runtimeType).toList(),
          containsAllInOrder([Go, RaceClosed]));
      expect(round.phase, RoundPhase.results);
    });
  });

  group('Race', () {
    test('lifts after Go earn places in order and the first is the winner',
        () {
      final round = racingRound();
      final first = round.fingerUp(1, s(9.2)).single as Lifted;
      expect(first.place, 1);
      expect(first.isWinner, isTrue);

      final second = round.fingerUp(0, s(9.3)).single as Lifted;
      expect(second.place, 2);
      expect(second.isWinner, isFalse);
    });

    test('the Race closes as soon as every finger has lifted', () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(9.2));
      final effects = round.fingerUp(1, s(9.4));
      expect(effects.last, isA<RaceClosed>());
      expect(round.phase, RoundPhase.results);
      expect(placesOf(round.placements!), [0, 1]);
      expect(round.placements![0].offsetFromGo, s(0.2));
      expect(round.placements![1].offsetFromGo, s(0.4));
    });

    test('Stragglers are teased at 2, 3, 4 seconds and the Race closes at 5',
        () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(9.1));
      expect(round.nextDeadline, s(11));

      final tease0 = round.advance(s(11)).single as StragglersTeased;
      expect(tease0.messageIndex, 0);
      expect(tease0.stragglers.single.id, 1);

      expect((round.advance(s(12)).single as StragglersTeased).messageIndex, 1);
      expect((round.advance(s(13)).single as StragglersTeased).messageIndex, 2);

      final closed = round.advance(s(14)).single as RaceClosed;
      expect(closed.placements.last.kind, LiftKind.straggler);
      expect(closed.placements.last.finger.id, 1);
      expect(closed.placements.last.offsetFromGo, isNull);
      expect(round.phase, RoundPhase.results);
    });

    test('a late-delivered lift stamped before Go is a False Start', () {
      final round = racingRound();
      final effects = round.fingerUp(0, s(8.9));
      expect(effects.single, isA<FalseStarted>());
    });

    test('a Straggler lifting during Results changes nothing', () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(9.1));
      round.advance(s(14));
      final before = round.placements;
      expect(round.fingerUp(1, s(15)), isEmpty);
      expect(round.placements, same(before));
    });
  });

  group('Placement rules', () {
    test('legitimate lifts, then False Starts (earliest last), then Stragglers',
        () {
      // Fingers 0..5 land at t=0..0.5 in id order.
      final round = Round();
      for (var i = 0; i < 6; i++) {
        round.fingerDown(i, _origin, s(i * 0.1));
      }
      round.advance(s(3.5)); // Lock-in at 3.5, Go at 9.5
      round.advance(s(9.5));
      expect(round.goAt, s(9.5));

      round.fingerUp(0, s(8.0)); // false start, earliest jump
      round.fingerUp(1, s(9.2)); // false start, closer to Go
      round.fingerUp(2, s(9.9)); // legit, 2nd
      round.fingerUp(3, s(9.7)); // legit, 1st
      // 4 and 5 are stragglers
      final closed = round.advance(s(14.5)).last as RaceClosed;

      expect(placesOf(closed.placements), [3, 2, 1, 0, 4, 5]);
      expect(closed.placements.map((p) => p.kind).toList(), [
        LiftKind.legitimate,
        LiftKind.legitimate,
        LiftKind.falseStart,
        LiftKind.falseStart,
        LiftKind.straggler,
        LiftKind.straggler,
      ]);
      expect(closed.placements.map((p) => p.place).toList(), [1, 2, 3, 4, 5, 6]);
      expect(closed.placements[2].offsetFromGo, s(-0.3));
      expect(closed.placements[3].offsetFromGo, s(-1.5));
    });

    test('every tie goes to the finger that landed first', () {
      final round = Round();
      round.fingerDown(10, _origin, s(0.2)); // landed second
      round.fingerDown(20, _origin, s(0.1)); // landed first
      round.fingerDown(30, _origin, s(0.4));
      round.fingerDown(40, _origin, s(0.3));
      round.advance(s(9.4));
      final go = round.goAt!;

      // Same legit lift time.
      round.fingerUp(10, go + s(0.25));
      round.fingerUp(20, go + s(0.25));
      // 30 and 40 are stragglers with no lift time at all.
      final closed = round.advance(go + s(5)).last as RaceClosed;
      expect(placesOf(closed.placements), [20, 10, 40, 30]);
    });

    test('same lift time false starts tie by landing order too', () {
      final round = Round();
      round.fingerDown(1, _origin, s(0.2));
      round.fingerDown(2, _origin, s(0.1));
      round.advance(s(3.2));
      round.fingerUp(1, s(5));
      round.fingerUp(2, s(5));
      final closed = round.advance(s(9.2)).last as RaceClosed;
      expect(placesOf(closed.placements), [2, 1]);
    });
  });

  group('Results and new Rounds', () {
    test('a finger landing during Results starts a fresh Round', () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(9.1));
      round.fingerUp(1, s(9.2));
      expect(round.phase, RoundPhase.results);

      final effects = round.fingerDown(50, _origin, s(20));
      expect(effects.single, isA<FingerLanded>());
      expect(round.phase, RoundPhase.gathering);
      expect(round.fingers.single.ordinal, 0);
      expect(round.placements, isNull);
      expect(round.goAt, isNull);
    });
  });

  group('Aborted', () {
    test('cancelling all touches aborts any live phase', () {
      final cases = <(Round Function(), Duration)>[
        (() => Round()..fingerDown(0, _origin, s(0)), s(1)),
        (lockedRound, s(3.5)),
        (() => lockedRound()..advance(s(6)), s(6.5)),
        (racingRound, s(9.5)),
      ];
      for (final (setup, at) in cases) {
        final round = setup();
        final effects = round.cancelAll(at, AbortReason.touchesCancelled);
        expect(effects.last, isA<Aborted>());
        expect(round.phase, RoundPhase.aborted);
        expect(round.fingers, isEmpty);
        expect(round.nextDeadline, isNull);
      }
    });

    test('losing focus during Results keeps the Results', () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(9.1));
      round.advance(s(14));
      final effects = round.cancelAll(s(15), AbortReason.lostFocus);
      expect(effects.whereType<Aborted>(), isEmpty);
      expect(round.phase, RoundPhase.results);
    });

    test('the next finger after Aborted begins Gathering', () {
      final round = lockedRound();
      round.cancelAll(s(5), AbortReason.touchesCancelled);
      round.fingerDown(3, _origin, s(6));
      expect(round.phase, RoundPhase.gathering);
      expect(round.fingers.single.ordinal, 0);
    });
  });
}
