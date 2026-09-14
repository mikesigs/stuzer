/// Rules shared by every Mode: how Fingers gather and lock in.
class RoundConfig {
  const RoundConfig({
    this.minFingers = 2,
    this.gatheringStability = const Duration(seconds: 3),
    this.beat = const Duration(seconds: 1),
  });

  /// Fewest Fingers that can Lock-in.
  final int minFingers;

  /// How long the set of Fingers must stay unchanged before Lock-in.
  final Duration gatheringStability;

  /// The Round's pulse: Locked lasts one beat, and Modes count in beats.
  final Duration beat;
}
