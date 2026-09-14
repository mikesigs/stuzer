/// What to write on a Finger's disc right now. Modes decide the content.
class FingerLabel {
  const FingerLabel({this.big, this.small, this.alarm = false});

  /// Large text: a place like "1st", or "!" for a False Start mid-Countdown.
  final String? big;

  /// Small text under it: a time, "early", or "Held".
  final String? small;

  /// True when the label should be drawn in the alarm red.
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
