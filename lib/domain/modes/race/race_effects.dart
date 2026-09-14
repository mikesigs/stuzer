import '../../effects.dart';
import '../../finger.dart';

class CountdownTick extends RoundEffect {
  const CountdownTick(this.number);
  final int number;
}

class Go extends RoundEffect {
  const Go();
}

class FalseStarted extends RoundEffect {
  const FalseStarted(this.finger);
  final Finger finger;
}

/// A Finger lifted after Go. [place] is final: later Lifts cannot beat it.
class Lifted extends RoundEffect {
  const Lifted(this.finger, this.place);
  final Finger finger;
  final int place;
  bool get isWinner => place == 1;
}

/// Held Fingers are being teased. Fires [RaceConfig.stragglerMessageCount]
/// times, every [RaceConfig.stragglerMessageInterval], starting
/// [RaceConfig.stragglerAfter] after Go.
class StragglersTeased extends RoundEffect {
  const StragglersTeased(this.stragglers, this.messageIndex);
  final List<Finger> stragglers;

  /// 0-based tease number within this Race.
  final int messageIndex;
}
