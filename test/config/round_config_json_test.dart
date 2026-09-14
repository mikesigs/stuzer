import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/config/round_config_json.dart';
import 'package:stuzer/domain/round_config.dart';

void main() {
  test('round-trips the defaults', () {
    const defaults = RoundConfig();
    final json = roundConfigToJson(defaults);
    expect(json, {
      'minFingers': 2,
      'gatheringStabilitySeconds': 3,
      'beatSeconds': 1,
      'countdownFrom': 3,
      'stragglerAfterSeconds': 2,
      'raceDurationSeconds': 5,
    });
    final back = roundConfigFromJson(json);
    expect(back.gatheringStability, defaults.gatheringStability);
    expect(back.beat, defaults.beat);
    expect(back.countdownFrom, defaults.countdownFrom);
    expect(back.stragglerAfter, defaults.stragglerAfter);
    expect(back.raceDuration, defaults.raceDuration);
    expect(back.minFingers, defaults.minFingers);
  });

  test('fractional seconds and partial files', () {
    final c = roundConfigFromJson({
      'gatheringStabilitySeconds': 1.5,
      'beatSeconds': 0.8,
    });
    expect(c.gatheringStability, const Duration(milliseconds: 1500));
    expect(c.beat, const Duration(milliseconds: 800));
    expect(c.countdownFrom, 3);
    expect(c.raceDuration, const Duration(seconds: 5));
  });

  test('nonsense falls back to defaults', () {
    final c = roundConfigFromJson({
      'minFingers': 1,
      'gatheringStabilitySeconds': 'soon',
      'beatSeconds': -2,
      'countdownFrom': 0,
      'raceDurationSeconds': null,
    });
    expect(c.minFingers, 2);
    expect(c.gatheringStability, const Duration(seconds: 3));
    expect(c.beat, const Duration(seconds: 1));
    expect(c.countdownFrom, 3);
    expect(c.raceDuration, const Duration(seconds: 5));
  });

  test('describes itself for the debug caption', () {
    expect(describeRoundConfig(const RoundConfig()),
        'lock-in 3s · beat 1s · 3-2-1 · race 5s');
    expect(
        describeRoundConfig(roundConfigFromJson({
          'gatheringStabilitySeconds': 1.5,
          'countdownFrom': 5,
        })),
        'lock-in 1.5s · beat 1s · 5-4-3-2-1 · race 5s');
  });
}
