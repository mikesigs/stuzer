import '../../finger.dart';
import '../../mode.dart';

/// Why a Finger earned the Place it did in a Race.
enum LiftKind {
  /// Lifted after Go.
  legitimate,

  /// Lifted between Lock-in and Go.
  falseStart,

  /// Still held when the Race closed.
  straggler,
}

/// A Finger's final standing in a Race.
class Placement {
  const Placement({
    required this.finger,
    required this.place,
    required this.kind,
    required this.offsetFromGo,
  });

  final Finger finger;

  /// 1-based Place. Ties are always broken, so Places are unique.
  final int place;

  final LiftKind kind;

  /// Lift time minus Go. Negative for False Starts, null for Stragglers.
  final Duration? offsetFromGo;

  @override
  String toString() => '$place: $finger $kind $offsetFromGo';
}

/// Orders Fingers by the Race rules.
///
/// Legitimate Lifts first (earliest Lift wins), then False Starts (the
/// earliest jump is last), then Stragglers. Every tie is broken by landing
/// order: the Finger that landed first wins.
List<Placement> rankFingers(Iterable<Finger> fingers, Duration goAt) {
  final byLanding = Ranking.byLanding;

  final legit = <Finger>[];
  final falseStarts = <Finger>[];
  final stragglers = <Finger>[];
  for (final f in fingers) {
    final lifted = f.liftedAt;
    if (lifted == null) {
      stragglers.add(f);
    } else if (lifted < goAt) {
      falseStarts.add(f);
    } else {
      legit.add(f);
    }
  }

  legit.sort((a, b) {
    final c = a.liftedAt!.compareTo(b.liftedAt!);
    return c != 0 ? c : byLanding(a, b);
  });
  falseStarts.sort((a, b) {
    // Later jump ranks better; the earliest jump is last.
    final c = b.liftedAt!.compareTo(a.liftedAt!);
    return c != 0 ? c : byLanding(a, b);
  });
  stragglers.sort(byLanding);

  final out = <Placement>[];
  var place = 1;
  for (final f in legit) {
    out.add(Placement(
      finger: f,
      place: place++,
      kind: LiftKind.legitimate,
      offsetFromGo: f.liftedAt! - goAt,
    ));
  }
  for (final f in falseStarts) {
    out.add(Placement(
      finger: f,
      place: place++,
      kind: LiftKind.falseStart,
      offsetFromGo: f.liftedAt! - goAt,
    ));
  }
  for (final f in stragglers) {
    out.add(Placement(
      finger: f,
      place: place++,
      kind: LiftKind.straggler,
      offsetFromGo: null,
    ));
  }
  return out;
}
