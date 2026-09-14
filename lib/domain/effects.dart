import 'finger.dart';
import 'standings.dart';

/// Why a Round was Aborted.
enum AbortReason {
  /// The OS cancelled every touch, usually because the device's finger
  /// limit was exceeded.
  touchesCancelled,

  /// The app lost focus (call, notification shade, home).
  lostFocus,

  /// Every Finger lifted during Locked, before the Countdown began.
  everyoneLetGo,
}

/// Something the presentation layer should react to (sound, haptic, visual).
/// The Round emits these; it never plays them itself.
sealed class RoundEffect {
  const RoundEffect();
}

class FingerLanded extends RoundEffect {
  const FingerLanded(this.finger);
  final Finger finger;
}

/// A Finger left during Gathering. No consequence.
class FingerLeft extends RoundEffect {
  const FingerLeft(this.finger);
  final Finger finger;
}

class LockedIn extends RoundEffect {
  const LockedIn(this.fingers);
  final List<Finger> fingers;
}

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

/// Held Fingers are being teased. Fires once per beat after [stragglerAfter].
class StragglersTeased extends RoundEffect {
  const StragglersTeased(this.stragglers, this.messageIndex);
  final List<Finger> stragglers;

  /// Increments each tease so the UI can rotate messages.
  final int messageIndex;
}

class RaceClosed extends RoundEffect {
  const RaceClosed(this.placements);
  final List<Placement> placements;
}

class Aborted extends RoundEffect {
  const Aborted(this.reason);
  final AbortReason reason;
}
