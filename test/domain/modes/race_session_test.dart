import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/domain/modes/race/race_session.dart';
import 'package:stuzer/domain/round.dart';

const _origin = Point<double>(0, 0);
Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// Default timeline used by the helpers below:
/// fingers land at 0, Lock-in at 3, Locked until 4, ticks 3/2/1 at 4/5/6,
/// Go at 7, Straggler teasing at 9/10/11, Race closes at 12.
const lockIn = 3;
const go = 7;
const close = 12;

Round raceRound({RaceConfig config = const RaceConfig()}) => Round(
      startMode: (fingers, at) => RaceSession(
        fingers: fingers,
        lockInAt: at,
        beat: const Duration(seconds: 1),
        config: config,
      ),
    );

RaceSession race(Round round) => round.session! as RaceSession;

/// Puts [count] fingers down at t=0 and advances to Lock-in.
Round lockedRound({int count = 3}) {
  final round = raceRound();
  for (var i = 0; i < count; i++) {
    round.fingerDown(i, _origin, s(0));
  }
  round.advance(s(lockIn));
  expect(race(round).phase, RacePhase.locked);
  return round;
}

/// A locked Round advanced to Go.
Round racingRound({int count = 3}) {
  final round = lockedRound(count: count);
  round.advance(s(go));
  expect(race(round).phase, RacePhase.racing);
  expect(race(round).goAt, s(go));
  return round;
}

List<int> placesOf(List<Placement> placements) =>
    placements.map((p) => p.finger.id).toList();

void main() {
  group('Locked and Countdown', () {
    test('Locked lasts one beat, then 3, 2, 1 tick once per second, then Go',
        () {
      final round = lockedRound();
      expect(round.nextDeadline, s(lockIn + 1));

      final ticks = <int>[];
      for (var t = lockIn + 1; t < go; t++) {
        final effects = round.advance(s(t));
        ticks.add((effects.single as CountdownTick).number);
        expect(race(round).countdownNumber, ticks.last);
      }
      expect(ticks, [3, 2, 1]);
      expect(race(round).phase, RacePhase.countdown);

      final effects = round.advance(s(go));
      expect(effects.single, isA<Go>());
      expect(race(round).phase, RacePhase.racing);
      expect(race(round).goAt, s(go));
      expect(race(round).countdownNumber, isNull);
    });

    test('a big time jump fires every transition in order', () {
      final round = lockedRound();
      final effects = round.advance(s(go));
      expect(effects.map((e) => e.runtimeType).toList(), [
        CountdownTick,
        CountdownTick,
        CountdownTick,
        Go,
      ]);
    });

    test('countdownFrom is configurable', () {
      final round = raceRound(config: const RaceConfig(countdownFrom: 5));
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      final effects = round.advance(s(9));
      expect(effects.whereType<CountdownTick>().map((t) => t.number),
          [5, 4, 3, 2, 1]);
      expect(race(round).goAt, s(9));
    });

    test('lifting during Locked or Countdown is a False Start', () {
      final round = lockedRound();
      final duringLocked = round.fingerUp(0, s(3.5));
      expect(duringLocked.single, isA<FalseStarted>());

      final duringCountdown = round.fingerUp(1, s(5));
      expect(duringCountdown.whereType<FalseStarted>().single.finger.id, 1);
      expect(race(round).phase, RacePhase.countdown);
    });

    test('everyone letting go before the "1" beat aborts the Round', () {
      // During Locked.
      var round = lockedRound(count: 2);
      expect(round.fingerUp(0, s(3.3)).single, isA<FalseStarted>());
      final last = round.fingerUp(1, s(3.6));
      expect(last.single, isA<Aborted>());
      expect((last.single as Aborted).reason, AbortReason.everyoneLetGo);
      expect(round.phase, RoundPhase.aborted);
      expect(round.fingers, isEmpty);
      expect(round.nextDeadline, isNull);

      // During "3".
      round = lockedRound(count: 2);
      round.fingerUp(0, s(4.2));
      expect(round.fingerUp(1, s(4.8)).single, isA<Aborted>());

      // During "2", with the second lift arriving just before "1" is spoken.
      round = lockedRound(count: 2);
      round.fingerUp(0, s(5.1));
      expect(round.fingerUp(1, s(5.999)).single, isA<Aborted>());
    });

    test('everyone letting go during the "1" beat is a False Start for all',
        () {
      final round = lockedRound(count: 2);
      round.fingerUp(0, s(4.5)); // false start during "3"
      round.advance(s(6)); // "1" spoken
      expect(race(round).countdownNumber, 1);
      final effects = round.fingerUp(1, s(6.4));
      expect(effects.single, isA<FalseStarted>());
      expect(round.phase, RoundPhase.playing);

      final atGo = round.advance(s(go));
      expect(atGo.map((e) => e.runtimeType).toList(), [Go, RoundFinished]);
      expect(round.phase, RoundPhase.results);
      expect(placesOf(race(round).placements!), [1, 0]);
    });

    test('a False Starter who re-touches is ignored', () {
      final round = lockedRound();
      round.fingerUp(0, s(5));
      expect(round.fingerDown(7, _origin, s(5.1)).whereType<FingerLanded>(),
          isEmpty);
      round.advance(s(go));
      expect(round.fingerUp(7, s(go + 0.2)).whereType<Lifted>(), isEmpty);
    });

    test('one finger left through the Countdown still races alone at Go', () {
      final round = lockedRound(count: 2);
      round.fingerUp(0, s(4.5));
      round.advance(s(go));
      expect(race(round).phase, RacePhase.racing);
      final effects = round.fingerUp(1, s(go + 0.3));
      expect(effects.first, isA<Lifted>());
      expect(effects.last, isA<RoundFinished>());
      expect(placesOf(race(round).placements!), [1, 0]);
    });
  });

  group('Racing', () {
    test('lifts after Go earn places in order and the first is the winner',
        () {
      final round = racingRound();
      final first = round.fingerUp(1, s(go + 0.2)).single as Lifted;
      expect(first.place, 1);
      expect(first.isWinner, isTrue);

      final second = round.fingerUp(0, s(go + 0.3)).single as Lifted;
      expect(second.place, 2);
      expect(second.isWinner, isFalse);
    });

    test('the Race closes as soon as every finger has lifted', () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(go + 0.2));
      final effects = round.fingerUp(1, s(go + 0.4));
      expect(effects.last, isA<RoundFinished>());
      expect(round.phase, RoundPhase.results);
      final placements = race(round).placements!;
      expect(placesOf(placements), [0, 1]);
      expect(placements[0].offsetFromGo, s(0.2));
      expect(placements[1].offsetFromGo, s(0.4));
      expect(round.ranking!.decidedPlaces, 2);
      expect(round.ranking!.ordered.map((f) => f.id), [0, 1]);
    });

    test('Stragglers are teased at 2, 3, 4 seconds and the Race closes at 5',
        () {
      final round = racingRound(count: 2);
      round.fingerUp(0, s(go + 0.1));
      expect(round.nextDeadline, s(go + 2));

      final tease0 = round.advance(s(go + 2)).single as StragglersTeased;
      expect(tease0.messageIndex, 0);
      expect(tease0.stragglers.single.id, 1);

      expect((round.advance(s(go + 3)).single as StragglersTeased).messageIndex,
          1);
      expect((round.advance(s(go + 4)).single as StragglersTeased).messageIndex,
          2);

      final closed = round.advance(s(close)).single as RoundFinished;
      final last = race(round).placements!.last;
      expect(last.kind, LiftKind.straggler);
      expect(last.finger.id, 1);
      expect(last.offsetFromGo, isNull);
      expect(closed.ranking.ordered.last.id, 1);
      expect(round.phase, RoundPhase.results);
    });

    test('teasing cadence and count come from config', () {
      final round = raceRound(
        config: const RaceConfig(
          stragglerAfter: Duration(seconds: 1),
          stragglerMessageCount: 2,
          stragglerMessageInterval: Duration(milliseconds: 1500),
        ),
      );
      round.fingerDown(0, _origin, s(0));
      round.fingerDown(1, _origin, s(0));
      round.advance(s(go));
      round.fingerUp(0, s(go + 0.1));
      expect(round.nextDeadline, s(go + 1));
      round.advance(s(go + 1));
      expect(round.nextDeadline, s(go + 2.5));
      round.advance(s(go + 2.5));
      expect(round.nextDeadline, s(go + 4));
      round.advance(s(go + 4));
      expect(round.phase, RoundPhase.results);
    });

    test('a late-delivered lift stamped before Go is a False Start', () {
      final round = racingRound();
      final effects = round.fingerUp(0, s(go - 0.1));
      expect(effects.single, isA<FalseStarted>());
    });
  });

  group('Placement rules', () {
    test('legitimate lifts, then False Starts (earliest last), then Stragglers',
        () {
      // Fingers 0..5 land at t=0..0.5 in id order. Lock-in 3.5, Go 7.5.
      final round = raceRound();
      for (var i = 0; i < 6; i++) {
        round.fingerDown(i, _origin, s(i * 0.1));
      }
      round.advance(s(3.5));
      round.advance(s(7.5));
      expect(race(round).goAt, s(7.5));

      round.fingerUp(0, s(6.0)); // false start, earliest jump
      round.fingerUp(1, s(7.2)); // false start, closer to Go
      round.fingerUp(2, s(7.9)); // legit, 2nd
      round.fingerUp(3, s(7.7)); // legit, 1st
      // 4 and 5 are stragglers
      round.advance(s(12.5));
      final placements = race(round).placements!;

      expect(placesOf(placements), [3, 2, 1, 0, 4, 5]);
      expect(placements.map((p) => p.kind).toList(), [
        LiftKind.legitimate,
        LiftKind.legitimate,
        LiftKind.falseStart,
        LiftKind.falseStart,
        LiftKind.straggler,
        LiftKind.straggler,
      ]);
      expect(placements.map((p) => p.place).toList(), [1, 2, 3, 4, 5, 6]);
      expect(placements[2].offsetFromGo, s(-0.3));
      expect(placements[3].offsetFromGo, s(-1.5));
    });

    test('every tie goes to the finger that landed first', () {
      final round = raceRound();
      round.fingerDown(10, _origin, s(0.2)); // landed second
      round.fingerDown(20, _origin, s(0.1)); // landed first
      round.fingerDown(30, _origin, s(0.4));
      round.fingerDown(40, _origin, s(0.3));
      // The last landing *event* was at 0.3, so Lock-in is 3.3 and Go 7.3.
      round.advance(s(7.3));
      final goAt = race(round).goAt!;
      expect(goAt, s(7.3));

      // Same legit lift time.
      round.fingerUp(10, goAt + s(0.25));
      round.fingerUp(20, goAt + s(0.25));
      // 30 and 40 are stragglers with no lift time at all.
      round.advance(goAt + s(5));
      expect(placesOf(race(round).placements!), [20, 10, 40, 30]);
    });

    test('same lift time false starts tie by landing order too', () {
      final round = raceRound();
      round.fingerDown(1, _origin, s(0.2));
      round.fingerDown(2, _origin, s(0.1));
      round.advance(s(6.2)); // Lock-in 3.2, "1" spoken at 6.2
      round.fingerUp(1, s(6.5));
      round.fingerUp(2, s(6.5));
      round.advance(s(7.2));
      expect(placesOf(race(round).placements!), [2, 1]);
    });
  });
}
