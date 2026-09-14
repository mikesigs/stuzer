import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/config/app_config.dart';
import 'package:stuzer/config/app_config_json.dart';
import 'package:stuzer/domain/modes/race/straggler_messages.dart';

void main() {
  test('round-trips the defaults', () {
    const defaults = AppConfig();
    final json = appConfigToJson(defaults);
    expect(json, {
      'minFingers': 2,
      'gatheringStabilitySeconds': 3,
      'beatSeconds': 1,
      'modes': {
        'race': {
          'countdownFrom': 3,
          'straggler': {
            'afterSeconds': 2,
            'messageCount': 3,
            'messageSeconds': 1,
            'messages': defaultStragglerMessages,
          },
        },
        'classic': {
          'suspenseSeconds': 3,
          'firstHopMs': 90,
          'hopGrowth': 1.16,
          'maxHopMs': 450,
        },
      },
    });
    final back = appConfigFromJson(json);
    expect(back.round.gatheringStability, defaults.round.gatheringStability);
    expect(back.round.beat, defaults.round.beat);
    expect(back.race.countdownFrom, 3);
    expect(back.race.stragglerAfter, const Duration(seconds: 2));
    expect(back.race.stragglerMessageCount, 3);
    expect(back.race.stragglerMessageInterval, const Duration(seconds: 1));
    expect(back.race.raceDuration, const Duration(seconds: 5));
    expect(back.classic.suspense, const Duration(seconds: 3));
    expect(back.classic.firstHop, const Duration(milliseconds: 90));
    expect(back.classic.hopGrowth, 1.16);
    expect(back.classic.maxHop, const Duration(milliseconds: 450));
    expect(back.stragglerMessages, defaultStragglerMessages);
  });

  test('per-mode sections', () {
    final c = appConfigFromJson({
      'modes': {
        'race': {
          'countdownFrom': 5,
          'straggler': {
            'afterSeconds': 1.5,
            'messageCount': 4,
            'messageSeconds': 0.75,
            'messages': ['a', ' b ', '', 3],
          },
        },
        'classic': {
          'suspenseSeconds': 4.5,
          'firstHopMs': 60,
          'hopGrowth': 1.3,
          'maxHopMs': 600,
        },
      },
    });
    expect(c.race.countdownFrom, 5);
    expect(c.race.stragglerAfter, const Duration(milliseconds: 1500));
    expect(c.race.stragglerMessageCount, 4);
    expect(c.race.stragglerMessageInterval, const Duration(milliseconds: 750));
    expect(c.race.raceDuration, const Duration(milliseconds: 4500));
    expect(c.stragglerMessages, ['a', 'b']);
    expect(c.classic.suspense, const Duration(milliseconds: 4500));
    expect(c.classic.firstHop, const Duration(milliseconds: 60));
    expect(c.classic.hopGrowth, 1.3);
    expect(c.classic.maxHop, const Duration(milliseconds: 600));
  });

  test('fractional seconds and partial files', () {
    final c = appConfigFromJson({
      'gatheringStabilitySeconds': 1.5,
      'beatSeconds': 0.8,
    });
    expect(c.round.gatheringStability, const Duration(milliseconds: 1500));
    expect(c.round.beat, const Duration(milliseconds: 800));
    expect(c.race.countdownFrom, 3);
    expect(c.race.raceDuration, const Duration(seconds: 5));
    expect(c.stragglerMessages, defaultStragglerMessages);
  });

  test('older flat Race keys are still read', () {
    final c = appConfigFromJson({
      'countdownFrom': 4,
      'stragglerAfterSeconds': 3,
      'straggler': {'messageCount': 2, 'messages': ['old']},
    });
    expect(c.race.countdownFrom, 4);
    expect(c.race.stragglerAfter, const Duration(seconds: 3));
    expect(c.race.stragglerMessageCount, 2);
    expect(c.stragglerMessages, ['old']);
  });

  test('nonsense falls back to defaults', () {
    final c = appConfigFromJson({
      'minFingers': 1,
      'gatheringStabilitySeconds': 'soon',
      'beatSeconds': -2,
      'modes': {
        'race': {'countdownFrom': 0, 'straggler': 'lots'},
        'classic': {'hopGrowth': 0.5, 'suspenseSeconds': null},
      },
    });
    expect(c.round.minFingers, 2);
    expect(c.round.gatheringStability, const Duration(seconds: 3));
    expect(c.round.beat, const Duration(seconds: 1));
    expect(c.race.countdownFrom, 3);
    expect(c.race.raceDuration, const Duration(seconds: 5));
    expect(c.classic.hopGrowth, 1.16);
    expect(c.classic.suspense, const Duration(seconds: 3));
  });

  test('zero straggler messages closes the Race right at afterSeconds', () {
    final c = appConfigFromJson({
      'modes': {
        'race': {
          'straggler': {'messageCount': 0},
        },
      },
    });
    expect(c.race.stragglerMessageCount, 0);
    expect(c.race.raceDuration, const Duration(seconds: 2));
  });

  test('describes itself per mode for the debug caption', () {
    const c = AppConfig();
    expect(describeConfig(c, 'race'), 'lock-in 3s · beat 1s · 3-2-1 · race 5s');
    expect(describeConfig(c, 'classic'), 'lock-in 3s · beat 1s · suspense 3s');
    expect(
        describeConfig(
            appConfigFromJson({
              'gatheringStabilitySeconds': 1.5,
              'modes': {
                'race': {'countdownFrom': 5},
              },
            }),
            'race'),
        'lock-in 1.5s · beat 1s · 5-4-3-2-1 · race 5s');
  });
}
