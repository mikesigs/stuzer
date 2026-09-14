import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/config/app_config.dart';
import 'package:stuzer/config/round_config_json.dart';
import 'package:stuzer/domain/round_config.dart';
import 'package:stuzer/domain/straggler_messages.dart';

void main() {
  test('round-trips the defaults', () {
    const defaults = AppConfig();
    final json = appConfigToJson(defaults);
    expect(json, {
      'minFingers': 2,
      'gatheringStabilitySeconds': 3,
      'beatSeconds': 1,
      'countdownFrom': 3,
      'straggler': {
        'afterSeconds': 2,
        'messageCount': 3,
        'messageSeconds': 1,
        'messages': defaultStragglerMessages,
      },
    });
    final back = appConfigFromJson(json);
    expect(back.round.gatheringStability, defaults.round.gatheringStability);
    expect(back.round.beat, defaults.round.beat);
    expect(back.round.countdownFrom, defaults.round.countdownFrom);
    expect(back.round.stragglerAfter, defaults.round.stragglerAfter);
    expect(back.round.stragglerMessageCount, 3);
    expect(back.round.stragglerMessageInterval, const Duration(seconds: 1));
    expect(back.round.raceDuration, const Duration(seconds: 5));
    expect(back.stragglerMessages, defaultStragglerMessages);
  });

  test('race length derives from the straggler section', () {
    final c = appConfigFromJson({
      'straggler': {
        'afterSeconds': 1.5,
        'messageCount': 4,
        'messageSeconds': 0.75,
        'messages': ['a', ' b ', '', 3],
      },
    });
    expect(c.round.stragglerAfter, const Duration(milliseconds: 1500));
    expect(c.round.stragglerMessageCount, 4);
    expect(c.round.stragglerMessageInterval, const Duration(milliseconds: 750));
    expect(c.round.raceDuration, const Duration(milliseconds: 4500));
    expect(c.stragglerMessages, ['a', 'b']);
  });

  test('fractional seconds and partial files', () {
    final c = appConfigFromJson({
      'gatheringStabilitySeconds': 1.5,
      'beatSeconds': 0.8,
    });
    expect(c.round.gatheringStability, const Duration(milliseconds: 1500));
    expect(c.round.beat, const Duration(milliseconds: 800));
    expect(c.round.countdownFrom, 3);
    expect(c.round.raceDuration, const Duration(seconds: 5));
    expect(c.stragglerMessages, defaultStragglerMessages);
  });

  test('the old flat stragglerAfterSeconds key still works', () {
    final c = appConfigFromJson({'stragglerAfterSeconds': 3});
    expect(c.round.stragglerAfter, const Duration(seconds: 3));
  });

  test('nonsense falls back to defaults', () {
    final c = appConfigFromJson({
      'minFingers': 1,
      'gatheringStabilitySeconds': 'soon',
      'beatSeconds': -2,
      'countdownFrom': 0,
      'straggler': 'lots',
    });
    expect(c.round.minFingers, 2);
    expect(c.round.gatheringStability, const Duration(seconds: 3));
    expect(c.round.beat, const Duration(seconds: 1));
    expect(c.round.countdownFrom, 3);
    expect(c.round.raceDuration, const Duration(seconds: 5));
  });

  test('zero straggler messages closes the Race right at afterSeconds', () {
    final c = appConfigFromJson({
      'straggler': {'messageCount': 0},
    });
    expect(c.round.stragglerMessageCount, 0);
    expect(c.round.raceDuration, const Duration(seconds: 2));
  });

  test('describes itself for the debug caption', () {
    expect(describeRoundConfig(const RoundConfig()),
        'lock-in 3s · beat 1s · 3-2-1 · race 5s');
    expect(
        describeRoundConfig(appConfigFromJson({
          'gatheringStabilitySeconds': 1.5,
          'countdownFrom': 5,
        }).round),
        'lock-in 1.5s · beat 1s · 5-4-3-2-1 · race 5s');
  });
}
