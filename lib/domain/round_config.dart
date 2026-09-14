/// Timing and threshold rules for a Round. Defaults match the spec.
class RoundConfig {
  const RoundConfig({
    this.minFingers = 2,
    this.gatheringStability = const Duration(seconds: 3),
    this.beat = const Duration(seconds: 1),
    this.countdownFrom = 5,
    this.stragglerAfter = const Duration(seconds: 2),
    this.raceDuration = const Duration(seconds: 5),
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

  /// Time after Go at which the Race closes.
  final Duration raceDuration;
}
