import '../domain/round.dart';

/// What to write on a Finger's disc right now.
class FingerLabel {
  const FingerLabel({this.big, this.small, this.alarm = false});

  /// Large text: a place like "1st", or "!" for a False Start mid-Countdown.
  final String? big;

  /// Small text under it: a time, "early", or "Held".
  final String? small;

  /// True when the label should be drawn in the False Start red.
  final bool alarm;

  static const none = FingerLabel();

  @override
  bool operator ==(Object other) =>
      other is FingerLabel &&
      other.big == big &&
      other.small == small &&
      other.alarm == alarm;

  @override
  int get hashCode => Object.hash(big, small, alarm);

  @override
  String toString() => 'FingerLabel($big, $small, alarm: $alarm)';
}

/// Label for [finger] given the Round's current state.
///
/// Final placements win once the Race has closed. During the Race a
/// legitimate Lift shows its provisional place, which is already final
/// because later Lifts cannot beat it. A False Start shows "!" until Results.
FingerLabel labelFor(Finger finger, Round round) {
  final placements = round.placements;
  if (placements != null) {
    final p = placements.firstWhere((p) => p.finger == finger);
    return switch (p.kind) {
      LiftKind.legitimate => FingerLabel(
          big: ordinal(p.place),
          small: formatOffset(p.offsetFromGo!),
        ),
      LiftKind.falseStart => FingerLabel(
          big: ordinal(p.place),
          small: '${formatOffset(-p.offsetFromGo!, signed: false)} early',
          alarm: true,
        ),
      LiftKind.straggler => FingerLabel(big: ordinal(p.place), small: 'Held'),
    };
  }

  final liftedAt = finger.liftedAt;
  final goAt = round.goAt;
  if (liftedAt == null) return FingerLabel.none;
  if (goAt == null || liftedAt < goAt) {
    return const FingerLabel(big: '!', alarm: true);
  }
  final place = round.fingers.where((f) {
    final t = f.liftedAt;
    if (t == null || t < goAt) return false;
    if (t != liftedAt) return t < liftedAt;
    return f.landedAt < finger.landedAt ||
        (f.landedAt == finger.landedAt && f.ordinal <= finger.ordinal);
  }).length;
  return FingerLabel(big: ordinal(place), small: formatOffset(liftedAt - goAt));
}

String ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// "+0.213s" style. Millisecond precision is all a human can read.
String formatOffset(Duration d, {bool signed = true}) {
  final ms = d.inMilliseconds.abs();
  final body = '${(ms / 1000).toStringAsFixed(3)}s';
  if (!signed) return body;
  return '${d.isNegative ? '-' : '+'}$body';
}
