import '../domain/round_config.dart';
import '../domain/straggler_messages.dart';

/// Everything the device config file can tune.
class AppConfig {
  const AppConfig({
    this.round = const RoundConfig(),
    this.stragglerMessages = defaultStragglerMessages,
  });

  final RoundConfig round;

  /// Pool of teasing lines. Each Race draws
  /// [RoundConfig.stragglerMessageCount] of them at random without repeats.
  final List<String> stragglerMessages;
}
