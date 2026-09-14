import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/domain/modes/classic/classic_session.dart';
import 'package:stuzer/domain/round.dart';

const _origin = Point<double>(0, 0);
Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// Fingers land at 0, Lock-in 3, Locked until 4, Suspense until 7.
Round classicRound({int seed = 1, ClassicConfig config = const ClassicConfig()}) =>
    Round(
      startMode: (fingers, at) => ClassicSession(
        fingers: fingers,
        lockInAt: at,
        beat: const Duration(seconds: 1),
        config: config,
        random: Random(seed),
      ),
    );

ClassicSession classic(Round round) => round.session! as ClassicSession;

Round lockedRound({int count = 4, int seed = 1}) {
  final round = classicRound(seed: seed);
  for (var i = 0; i < count; i++) {
    round.fingerDown(i, _origin, s(0));
  }
  round.advance(s(3));
  expect(classic(round).phase, ClassicPhase.locked);
  return round;
}

void main() {
  test('Locked lasts one beat, then the Spotlight hops with slowing rhythm',
      () {
    final round = lockedRound();
    expect(round.nextDeadline, s(4));
    expect(classic(round).spotlight, isNull);

    final first = round.advance(s(4));
    expect(first.single, isA<SpotlightMoved>());
    expect(classic(round).phase, ClassicPhase.suspense);
    expect(classic(round).spotlight, isNotNull);

    // Collect hop times by walking deadlines until the stop.
    final hopTimes = <Duration>[s(4)];
    while (classic(round).phase == ClassicPhase.suspense) {
      final due = round.nextDeadline!;
      final effects = round.advance(due);
      if (effects.any((e) => e is SpotlightMoved)) hopTimes.add(due);
      if (effects.any((e) => e is Chosen)) break;
    }
    expect(classic(round).phase, ClassicPhase.done);
    expect(round.phase, RoundPhase.results);

    final gaps = [
      for (var i = 1; i < hopTimes.length; i++) hopTimes[i] - hopTimes[i - 1]
    ];
    expect(gaps.first, const Duration(milliseconds: 90));
    for (var i = 1; i < gaps.length; i++) {
      expect(gaps[i] >= gaps[i - 1], isTrue, reason: 'hops only slow down');
      expect(gaps[i] <= const Duration(milliseconds: 450), isTrue);
    }
    expect(hopTimes.length, greaterThan(8));
    expect(hopTimes.last < s(7), isTrue);
  });

  test('consecutive hops never light the same finger', () {
    final round = lockedRound(count: 3);
    Finger? previous;
    while (round.phase == RoundPhase.playing) {
      final effects = round.advance(round.nextDeadline!);
      for (final e in effects.whereType<SpotlightMoved>()) {
        expect(e.finger, isNot(same(previous)));
        previous = e.finger;
      }
    }
  });

  test('the Chosen finger is the last Spotlight and gets first place alone',
      () {
    final round = lockedRound();
    Finger? lastLit;
    Chosen? chosen;
    while (round.phase == RoundPhase.playing) {
      for (final e in round.advance(round.nextDeadline!)) {
        if (e is SpotlightMoved) lastLit = e.finger;
        if (e is Chosen) chosen = e;
      }
    }
    expect(chosen!.finger, same(lastLit));
    expect(classic(round).chosen, same(lastLit));

    final ranking = round.ranking!;
    expect(ranking.decidedPlaces, 1);
    expect(ranking.first, same(lastLit));
    expect(ranking.ordered.length, 4);
    for (final f in round.fingers) {
      expect(ranking.placeOf(f), f == lastLit ? 1 : isNull);
    }
    // The rest follow landing order.
    final rest = ranking.ordered.skip(1).map((f) => f.ordinal).toList();
    expect(rest, List.of(rest)..sort());
  });

  test('different seeds pick different fingers', () {
    final picks = <int>{};
    for (var seed = 0; seed < 12; seed++) {
      final round = lockedRound(seed: seed);
      while (round.phase == RoundPhase.playing) {
        round.advance(round.nextDeadline!);
      }
      picks.add(round.ranking!.first!.id);
    }
    expect(picks.length, greaterThan(1));
  });

  test('a finger that lifts drops out and is never chosen', () {
    for (var seed = 0; seed < 10; seed++) {
      final round = lockedRound(count: 3, seed: seed);
      round.advance(s(4));
      // Hops due before 4.5 fire first; the lift's own effects follow.
      final effects = round.fingerUp(0, s(4.5));
      expect(effects.whereType<DroppedOut>().single.finger.id, 0);
      // If the Spotlight was on the leaver it moved on at once.
      expect(classic(round).spotlight!.id, isNot(0));
      while (round.phase == RoundPhase.playing) {
        for (final e in round.advance(round.nextDeadline!)) {
          if (e is SpotlightMoved) expect(e.finger.id, isNot(0));
        }
      }
      expect(round.ranking!.first!.id, isNot(0));
    }
  });

  test('a lift during Locked also drops out', () {
    final round = lockedRound(count: 2);
    expect(round.fingerUp(1, s(3.5)).single, isA<DroppedOut>());
    while (round.phase == RoundPhase.playing) {
      round.advance(round.nextDeadline!);
    }
    expect(round.ranking!.first!.id, 0);
  });

  test('everyone letting go aborts', () {
    final round = lockedRound(count: 2);
    round.advance(s(4.2));
    round.fingerUp(0, s(4.3));
    final effects = round.fingerUp(1, s(4.4));
    expect(effects.last, isA<Aborted>());
    expect(effects.whereType<DroppedOut>(), isEmpty,
        reason: 'the shell drops the session effects when it aborts');
    expect(round.phase, RoundPhase.aborted);
  });

  test('suspense progress runs 0..1 across Suspense', () {
    final round = lockedRound();
    round.advance(s(4));
    final c = classic(round);
    expect(c.suspenseProgress(s(3.5)), 0);
    expect(c.suspenseProgress(s(4)), 0);
    expect(c.suspenseProgress(s(5.5)), closeTo(0.5, 1e-9));
    expect(c.suspenseProgress(s(7)), 1);
    expect(c.suspenseProgress(s(9)), 1);
  });

  test('suspense length is configurable', () {
    final round = classicRound(
        config: const ClassicConfig(suspense: Duration(seconds: 1)));
    round.fingerDown(0, _origin, s(0));
    round.fingerDown(1, _origin, s(0));
    round.advance(s(4.999));
    expect(round.phase, RoundPhase.playing);
    round.advance(s(5));
    expect(round.phase, RoundPhase.results);
  });
}
