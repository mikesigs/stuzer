import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/audio/sound_engine.dart';
import 'package:stuzer/config/app_config.dart';
import 'package:stuzer/domain/round.dart';
import 'package:stuzer/game/round_controller.dart';

const fast = AppConfig(
  round: RoundConfig(gatheringStability: Duration(milliseconds: 500)),
);

void main() {
  // The controller fires haptics through platform channels.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('applyConfig swaps the Round only while idle', () {
    final c = RoundController(sounds: SoundEngine.silent());
    expect(c.applyConfig(fast), isTrue);
    expect(c.round.config.gatheringStability, fast.round.gatheringStability);

    // A finger is down: not idle.
    c.round.fingerDown(1, const Point(0, 0), Duration.zero);
    expect(c.applyConfig(const AppConfig()), isFalse);
    expect(c.round.config.gatheringStability, fast.round.gatheringStability);
    expect(c.round.fingers, hasLength(1));

    // Lock-in 0.5, Locked to 1.5, ticks 1.5/2.5/3.5, Go 4.5, close 9.5.
    c.round.fingerDown(2, const Point(0, 0), Duration.zero);
    c.round.advance(const Duration(seconds: 5));
    expect(c.round.phase, RoundPhase.race);
    expect(c.applyConfig(const AppConfig()), isFalse);
    c.round.fingerUp(1, const Duration(seconds: 5));
    c.round.fingerUp(2, const Duration(seconds: 5));
    expect(c.round.phase, RoundPhase.results);
    expect(c.applyConfig(const AppConfig()), isTrue);
    expect(c.round.phase, RoundPhase.gathering);
    expect(c.round.config.gatheringStability, const Duration(seconds: 3));
  });

  test('onAppResumed pulls fresh config from the loader', () async {
    final c = RoundController(sounds: SoundEngine.silent());
    var loads = 0;
    c.loadConfig = () async {
      loads++;
      return fast;
    };
    await c.onAppResumed();
    expect(loads, 1);
    expect(c.round.config.gatheringStability, fast.round.gatheringStability);
  });

  group('straggler messages', () {
    const pool = ['a', 'b', 'c', 'd', 'e', 'f'];

    /// Runs a two-finger Race where one finger never lifts and returns the
    /// teasing lines shown, in order.
    List<String> teasesShown(RoundController c) {
      final shown = <String>[];
      c.round.fingerDown(1, const Point(0, 0), Duration.zero);
      c.round.fingerDown(2, const Point(0, 0), Duration.zero);
      // Drive through the controller so effects reach it: simulate the
      // timer by advancing and feeding effects back in.
      var t = Duration.zero;
      while (c.round.phase != RoundPhase.results) {
        t += const Duration(milliseconds: 250);
        c.debugAdvance(t);
        if (c.round.phase == RoundPhase.race && c.round.heldFingers.length == 2) {
          c.debugLift(1, t);
        }
        final m = c.stragglerMessage;
        if (m != null && (shown.isEmpty || shown.last != m)) shown.add(m);
      }
      return shown;
    }

    test('each Race draws distinct lines from the pool in random order', () {
      const config = AppConfig(
        round: RoundConfig(stragglerMessageCount: 4),
        stragglerMessages: pool,
      );
      final orders = <List<String>>[];
      for (var seed = 0; seed < 5; seed++) {
        final c = RoundController(
          sounds: SoundEngine.silent(),
          config: config,
          random: Random(seed),
        );
        final shown = teasesShown(c);
        expect(shown, hasLength(4));
        expect(shown.toSet(), hasLength(4), reason: 'no repeats within a Race');
        expect(pool, containsAll(shown));
        orders.add(shown);
      }
      expect(orders.map((o) => o.join()).toSet().length, greaterThan(1),
          reason: 'different seeds give different draws');
    });

    test('a pool smaller than the count cycles without adjacent repeats', () {
      const config = AppConfig(
        round: RoundConfig(stragglerMessageCount: 5),
        stragglerMessages: ['x', 'y'],
      );
      for (var seed = 0; seed < 5; seed++) {
        final c = RoundController(
          sounds: SoundEngine.silent(),
          config: config,
          random: Random(seed),
        );
        // teasesShown collapses consecutive duplicates, so five distinct
        // consecutive lines means no adjacent repeats happened.
        final shown = teasesShown(c);
        expect(shown, hasLength(5));
        expect(shown.toSet(), {'x', 'y'});
      }
    });
  });
}
