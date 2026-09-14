/// Rules for Race Mode. Beats come from the shared RoundConfig.
class RaceConfig {
  const RaceConfig({
    this.countdownFrom = 3,
    this.stragglerAfter = const Duration(seconds: 2),
    this.stragglerMessageCount = 3,
    this.stragglerMessageInterval = const Duration(seconds: 1),
  });

  /// First number spoken in the Countdown.
  final int countdownFrom;

  /// Time after Go at which held Fingers become Stragglers and teasing starts.
  final Duration stragglerAfter;

  /// How many teasing messages are shown before the Race closes.
  final int stragglerMessageCount;

  /// How long each teasing message stays up.
  final Duration stragglerMessageInterval;

  /// Time after Go at which the Race closes: the teasing window runs its
  /// full course, then the Race is over.
  Duration get raceDuration =>
      stragglerAfter + stragglerMessageInterval * stragglerMessageCount;
}
