import '../domain/modes/classic/classic_config.dart';
import '../domain/modes/race/race_config.dart';
import '../domain/modes/race/straggler_messages.dart';
import '../domain/round_config.dart';

/// Everything the device config file can tune.
class AppConfig {
  const AppConfig({
    this.round = const RoundConfig(),
    this.race = const RaceConfig(),
    this.classic = const ClassicConfig(),
    this.stragglerMessages = defaultStragglerMessages,
  });

  /// Shared: Gathering, Lock-in, the beat.
  final RoundConfig round;

  final RaceConfig race;
  final ClassicConfig classic;

  /// Race Mode's pool of teasing lines. Each Race draws
  /// [RaceConfig.stragglerMessageCount] of them at random without repeats.
  final List<String> stragglerMessages;
}
