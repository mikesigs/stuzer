import '../../effects.dart';
import '../../finger.dart';

/// The Spotlight jumped to [finger].
class SpotlightMoved extends RoundEffect {
  const SpotlightMoved(this.finger);
  final Finger finger;
}

/// A Finger lifted during Locked or Suspense and is out of the draw.
class DroppedOut extends RoundEffect {
  const DroppedOut(this.finger);
  final Finger finger;
}

/// The Spotlight stopped. [finger] is first player.
class Chosen extends RoundEffect {
  const Chosen(this.finger);
  final Finger finger;
}
