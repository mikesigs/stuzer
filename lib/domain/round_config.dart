/// Timing and threshold rules for a Round. Defaults match the spec.
class RoundConfig {
  const RoundConfig({
    this.minFingers = 2,
    this.gatheringStability = const Duration(seconds: 3),
    this.beat = const Duration(seconds: 1),
    this.countdownFrom = 3,
    this.stragglerAfter = const Duration(seconds: 2),
    this.stragglerMessageCount = 3,
    this.stragglerMessageInterval = const Duration(seconds: 1),
  });

  /// Fewest Fingers that can Lock-in.
  final int minFingers;

  /// How long the set of Fingers must stay unchanged before Lock-in.
  final Duration gatheringStability;

  /// Length of one Countdown beat. Locked also lasts one beat.
  final Duration beat;

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
