import 'finger.dart';
import 'mode.dart';

/// Why a Round was Aborted.
enum AbortReason {
  /// The OS cancelled every touch, usually because the device's finger
  /// limit was exceeded.
  touchesCancelled,

  /// The app lost focus (call, notification shade, home).
  lostFocus,

  /// Every Finger lifted before the Mode could reach a decision.
  everyoneLetGo,
}

/// Something the presentation layer should react to (sound, haptic, visual).
/// The Round and its Mode emit these; they never play them themselves.
///
/// Shared effects live here. Each Mode defines its own subclasses in its
/// own folder, and only that Mode's presentation knows how to render them.
abstract class RoundEffect {
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

/// The Mode has decided. Carries the full Ranking.
class RoundFinished extends RoundEffect {
  const RoundFinished(this.ranking);
  final Ranking ranking;
}

class Aborted extends RoundEffect {
  const Aborted(this.reason);
  final AbortReason reason;
}
