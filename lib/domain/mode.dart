import 'effects.dart';
import 'finger.dart';

/// The full ordering a Mode produces, with how many leading Places it
/// actually decided. Undecided Places are filled by landing order and the
/// presentation does not show them.
class Ranking {
  Ranking(this.ordered, {required this.decidedPlaces})
      : assert(decidedPlaces >= 0 && decidedPlaces <= ordered.length);

  final List<Finger> ordered;
  final int decidedPlaces;

  /// 1-based Place, or null when the Mode did not decide this Finger's Place.
  int? placeOf(Finger finger) {
    final i = ordered.indexOf(finger);
    if (i < 0 || i >= decidedPlaces) return null;
    return i + 1;
  }

  Finger? get first => ordered.isEmpty || decidedPlaces == 0 ? null : ordered.first;

  /// Orders Fingers by landing: the shared tie rule.
  static int byLanding(Finger a, Finger b) {
    final c = a.landedAt.compareTo(b.landedAt);
    return c != 0 ? c : a.ordinal.compareTo(b.ordinal);
  }
}

/// One Mode's play, from Lock-in until it has a Ranking.
///
/// Pure Dart. The Round shell owns the Fingers and forwards events; the
/// session decides what they mean. It signals the end by exposing a
/// non-null [ranking], or asks for an abort by returning an [Aborted] effect.
abstract class ModeSession {
  /// When the next time-driven transition is due, or null.
  Duration? get nextDeadline;

  /// A held Finger lifted at [time]. The shell has already recorded the Lift
  /// on the Finger.
  List<RoundEffect> fingerUp(Finger finger, Duration time);

  /// Fire every time-driven transition due at or before [time].
  List<RoundEffect> advance(Duration time);

  /// The decision, once made.
  Ranking? get ranking;
}

/// Builds a Mode's session for a locked set of Fingers.
typedef ModeSessionFactory = ModeSession Function(
  List<Finger> fingers,
  Duration lockInAt,
);
