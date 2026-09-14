import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../audio/sound_engine.dart';
import '../domain/round.dart';
import '../domain/straggler_messages.dart';
import 'finger_palette.dart';

/// A transient visual triggered by a Round effect, drawn by the painter.
class Burst {
  Burst({
    required this.kind,
    required this.position,
    required this.color,
    required this.startedAt,
  });

  final BurstKind kind;
  final Point<double> position;
  final Color color;
  final Duration startedAt;
}

enum BurstKind { ripple, falseStart, confetti, flourish }

/// Drives a [Round] from Flutter pointer events and wall-clock timers, plays
/// sounds and haptics for its effects, and exposes the visual state.
///
/// All times are on the pointer-event timeline (device uptime). Timers are
/// scheduled from the Round's [Round.nextDeadline] rather than polled.
class RoundController extends ChangeNotifier {
  RoundController({required this.sounds, Round? round})
      : round = round ?? Round();

  final Round round;
  final SoundEngine sounds;

  final _clock = Stopwatch()..start();
  Duration? _timelineOffset; // pointer timestamp minus stopwatch elapsed
  Timer? _timer;

  final bursts = <Burst>[];
  Duration? lastTickAt;
  int? lastTickNumber;
  String? stragglerMessage;
  AbortReason? abortReason;
  bool _cancelledByOs = false;

  /// Current time on the pointer-event timeline.
  Duration get now => _clock.elapsed + (_timelineOffset ?? Duration.zero);

  // ------------------------------------------------------------- pointers

  void onPointerDown(PointerDownEvent e) {
    _sync(e.timeStamp);
    _dispatch(round.fingerDown(e.pointer, _pt(e.localPosition), e.timeStamp));
  }

  void onPointerMove(PointerMoveEvent e) {
    round.fingerMove(e.pointer, _pt(e.localPosition));
    notifyListeners();
  }

  void onPointerUp(PointerUpEvent e) {
    _sync(e.timeStamp);
    _dispatch(round.fingerUp(e.pointer, e.timeStamp));
  }

  /// The platform cancelled a pointer. iOS cancels every touch at once when
  /// the finger limit is hit; Android cancels on gesture takeover or focus
  /// loss. Either way the Round cannot trust the finger set any more.
  void onPointerCancel(PointerCancelEvent e) {
    _sync(e.timeStamp);
    if (_cancelledByOs) return;
    _cancelledByOs = true;
    scheduleMicrotask(() => _cancelledByOs = false);
    _dispatch(round.cancelAll(e.timeStamp, AbortReason.touchesCancelled));
  }

  void toggleMute() {
    sounds.muted = !sounds.muted;
    notifyListeners();
  }

  void onAppHidden() {
    if (round.phase == RoundPhase.gathering && round.fingers.isEmpty) return;
    _dispatch(round.cancelAll(now, AbortReason.lostFocus));
  }

  // -------------------------------------------------------------- timing

  void _sync(Duration pointerTime) {
    _timelineOffset = pointerTime - _clock.elapsed;
  }

  void _schedule() {
    _timer?.cancel();
    final deadline = round.nextDeadline;
    if (deadline == null) return;
    var wait = deadline - now;
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, () => _dispatch(round.advance(now)));
  }

  // ------------------------------------------------------------- effects

  void _dispatch(List<RoundEffect> effects) {
    for (final effect in effects) {
      _apply(effect);
    }
    _schedule();
    notifyListeners();
  }

  void _apply(RoundEffect effect) {
    switch (effect) {
      case FingerLanded(:final finger):
        abortReason = null;
        if (finger.ordinal == 0) {
          bursts.clear();
          stragglerMessage = null;
          lastTickNumber = null;
        }
        sounds.fingerNote(finger.ordinal);
        HapticFeedback.lightImpact();
        _burst(BurstKind.ripple, finger);
      case FingerLeft():
        break;
      case LockedIn(:final fingers):
        sounds.lock();
        HapticFeedback.heavyImpact();
        for (final f in fingers) {
          _burst(BurstKind.ripple, f);
        }
      case CountdownTick(:final number):
        sounds.tick();
        HapticFeedback.selectionClick();
        lastTickAt = now;
        lastTickNumber = number;
      case Go():
        sounds.go();
        HapticFeedback.heavyImpact();
        lastTickAt = now;
        lastTickNumber = 0;
      case FalseStarted(:final finger):
        HapticFeedback.vibrate();
        _burst(BurstKind.falseStart, finger);
      case Lifted(:final finger, :final isWinner):
        if (isWinner) sounds.ding();
        HapticFeedback.lightImpact();
        _burst(BurstKind.ripple, finger);
      case StragglersTeased(:final messageIndex):
        stragglerMessage =
            stragglerMessages[messageIndex % stragglerMessages.length];
      case RaceClosed(:final placements):
        stragglerMessage = null;
        for (final p in placements) {
          if (p.kind != LiftKind.legitimate) continue;
          if (p.place == 1) {
            sounds.fanfare();
            _burst(BurstKind.confetti, p.finger);
          } else if (p.place <= 3) {
            _burst(BurstKind.flourish, p.finger);
          }
        }
      case Aborted(:final reason):
        abortReason = reason;
        bursts.clear();
        stragglerMessage = null;
        lastTickNumber = null;
        HapticFeedback.vibrate();
    }
  }

  void _burst(BurstKind kind, Finger finger) {
    bursts.add(Burst(
      kind: kind,
      position: finger.position,
      color: fingerColor(finger.ordinal),
      startedAt: now,
    ));
    if (bursts.length > 64) bursts.removeRange(0, bursts.length - 64);
  }

  static Point<double> _pt(Offset o) => Point(o.dx, o.dy);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
