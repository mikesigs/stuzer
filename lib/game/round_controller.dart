import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../audio/sound_engine.dart';
import '../config/app_config.dart';
import '../domain/round.dart';
import 'finger_palette.dart';
import 'modes/mode_registry.dart';

/// A transient visual triggered by an effect, drawn by the shared painter.
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

/// Drives a [Round] from Flutter pointer events and wall-clock timers, plays
/// shared sounds and haptics, hands Mode-specific effects to the active
/// [ModeUi], and exposes the visual state.
///
/// All times are on the pointer-event timeline (device uptime). Timers are
/// scheduled from the Round's [Round.nextDeadline] rather than polled.
class RoundController extends ChangeNotifier {
  RoundController({
    required this.sounds,
    AppConfig config = const AppConfig(),
    GameMode mode = defaultMode,
    Random? random,
  })  : _config = config,
        _mode = mode,
        _modeUi = mode.createUi(),
        _random = random ?? Random() {
    _round = _buildRound();
  }
  // ignore_for_file: prefer_initializing_formals

  final SoundEngine sounds;
  final Random _random;

  AppConfig _config;
  AppConfig get config => _config;

  GameMode _mode;
  GameMode get mode => _mode;

  ModeUi _modeUi;
  ModeUi get modeUi => _modeUi;

  late Round _round;
  Round get round => _round;

  final _clock = Stopwatch()..start();
  Duration? _timelineOffset; // pointer timestamp minus stopwatch elapsed
  Duration _floor = Duration.zero; // latest time the Round has been advanced to
  Timer? _timer;

  final bursts = <Burst>[];
  AbortReason? abortReason;
  bool _cancelledByOs = false;

  /// Optional source of fresh tuning, consulted on resume.
  Future<AppConfig> Function()? loadConfig;

  /// Called after the Mode changes, so the choice can be remembered.
  void Function(GameMode mode)? onModeChanged;

  /// Current time on the pointer-event timeline. Never runs backwards, even
  /// if the wall clock and the pointer clock disagree.
  Duration get now {
    final t = _clock.elapsed + (_timelineOffset ?? Duration.zero);
    return t > _floor ? t : _floor;
  }

  /// No Round in progress: safe to swap Mode or tuning.
  bool get isIdle => switch (round.phase) {
        RoundPhase.gathering => round.fingers.isEmpty,
        RoundPhase.results || RoundPhase.aborted => true,
        RoundPhase.playing => false,
      };

  Round _buildRound() => Round(
        config: _config.round,
        startMode: (fingers, at) =>
            _mode.createSession(fingers, at, _config, _random),
      );

  /// Swap in new tuning. Only takes effect while idle, so a live Round is
  /// never disturbed. Returns whether it applied.
  bool applyConfig(AppConfig config) {
    if (!isIdle) return false;
    _config = config;
    _restart();
    return true;
  }

  /// Switch Mode. Only while idle. Returns whether it applied.
  bool selectMode(GameMode mode) {
    if (!isIdle) return false;
    if (mode.id != _mode.id) {
      _mode = mode;
      _modeUi = mode.createUi();
      onModeChanged?.call(mode);
    }
    _restart();
    return true;
  }

  void _restart() {
    _timer?.cancel();
    _round = _buildRound();
    bursts.clear();
    abortReason = null;
    _modeUi.onRoundReset();
    notifyListeners();
  }

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

  /// Called when the app returns to the foreground. Reloads tuning from
  /// [loadConfig] if one was supplied.
  Future<void> onAppResumed() async {
    final loader = loadConfig;
    if (loader == null) return;
    final config = await loader();
    applyConfig(config);
  }

  // -------------------------------------------------------------- timing

  void _sync(Duration pointerTime) {
    _timelineOffset = pointerTime - _clock.elapsed;
    if (pointerTime > _floor) _floor = pointerTime;
  }

  void _schedule() {
    _timer?.cancel();
    final deadline = round.nextDeadline;
    if (deadline == null) return;
    var wait = deadline - now;
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, () {
      // The deadline has passed by construction; advance at least that far.
      if (deadline > _floor) _floor = deadline;
      _dispatch(round.advance(now));
    });
  }

  // ------------------------------------------------------------- effects

  void _dispatch(List<RoundEffect> effects, {bool schedule = true}) {
    for (final effect in effects) {
      _applyShared(effect);
      _modeUi.onEffect(effect, _context());
    }
    if (schedule) _schedule();
    notifyListeners();
  }

  ModeUiContext _context() => ModeUiContext(
        round: round,
        sounds: sounds,
        now: now,
        burst: _burst,
        random: _random,
        config: _config,
      );

  void _applyShared(RoundEffect effect) {
    switch (effect) {
      case FingerLanded(:final finger):
        abortReason = null;
        if (finger.ordinal == 0) {
          bursts.clear();
          _modeUi.onRoundReset();
        }
        sounds.fingerNote(finger.ordinal);
        HapticFeedback.lightImpact();
        _burst(BurstKind.ripple, finger);
      case LockedIn(:final fingers):
        sounds.lock();
        HapticFeedback.heavyImpact();
        for (final f in fingers) {
          _burst(BurstKind.ripple, f);
        }
      case Aborted(:final reason):
        abortReason = reason;
        bursts.clear();
        HapticFeedback.vibrate();
      default:
        break;
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

  /// Test hooks: drive the Round and apply effects without arming timers.
  @visibleForTesting
  void debugAdvance(Duration time) =>
      _dispatch(round.advance(time), schedule: false);

  @visibleForTesting
  void debugLift(int pointer, Duration time) =>
      _dispatch(round.fingerUp(pointer, time), schedule: false);

  static Point<double> _pt(Offset o) => Point(o.dx, o.dy);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
