/// Rules for Classic Mode: the Spotlight's rhythm.
class ClassicConfig {
  const ClassicConfig({
    this.suspense = const Duration(seconds: 3),
    this.firstHop = const Duration(milliseconds: 90),
    this.hopGrowth = 1.16,
    this.maxHop = const Duration(milliseconds: 450),
  });

  /// How long the Spotlight hops after Locked before it stops.
  final Duration suspense;

  /// Interval between the first two hops.
  final Duration firstHop;

  /// Each hop interval is the previous one times this, until [maxHop].
  final double hopGrowth;

  /// Slowest the Spotlight gets.
  final Duration maxHop;
}
