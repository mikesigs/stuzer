import 'dart:math';

/// One tracked touch, from landing until it lifts.
class Finger {
  Finger({
    required this.id,
    required this.ordinal,
    required this.landedAt,
    required this.position,
  });

  /// Platform pointer id. Unique for the life of the touch.
  final int id;

  /// Landing order within the Round, starting at 0. Drives colour and ties.
  final int ordinal;

  /// Monotonic timestamp of landing.
  final Duration landedAt;

  /// Where the Finger is, or where it was when it lifted.
  Point<double> position;

  Duration? _liftedAt;

  /// Monotonic timestamp of the Lift, or null while still held.
  Duration? get liftedAt => _liftedAt;

  bool get isHeld => _liftedAt == null;

  void moveTo(Point<double> p) => position = p;

  void lift(Duration at) => _liftedAt = at;

  @override
  String toString() => 'Finger($id, #$ordinal)';
}
