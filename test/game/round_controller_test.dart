import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/audio/sound_engine.dart';
import 'package:stuzer/domain/round.dart';
import 'package:stuzer/game/round_controller.dart';

void main() {
  const fast = RoundConfig(gatheringStability: Duration(milliseconds: 500));

  test('applyConfig swaps the Round only while idle', () {
    final c = RoundController(sounds: SoundEngine.silent());
    expect(c.applyConfig(fast), isTrue);
    expect(c.round.config.gatheringStability, fast.gatheringStability);

    // A finger is down: not idle.
    c.round.fingerDown(1, const Point(0, 0), Duration.zero);
    expect(c.applyConfig(const RoundConfig()), isFalse);
    expect(c.round.config.gatheringStability, fast.gatheringStability);
    expect(c.round.fingers, hasLength(1));

    // Results are idle again.
    c.round.fingerDown(2, const Point(0, 0), Duration.zero);
    // Lock-in 0.5, Locked to 1.5, ticks 1.5/2.5/3.5, Go 4.5, close 9.5.
    c.round.advance(const Duration(seconds: 5));
    expect(c.round.phase, RoundPhase.race);
    expect(c.applyConfig(const RoundConfig()), isFalse);
    c.round.fingerUp(1, const Duration(seconds: 5));
    c.round.fingerUp(2, const Duration(seconds: 5));
    expect(c.round.phase, RoundPhase.results);
    expect(c.applyConfig(const RoundConfig()), isTrue);
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
    expect(c.round.config.gatheringStability, fast.gatheringStability);
  });
}
