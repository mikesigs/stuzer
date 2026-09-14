import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/round.dart';
import 'finger_palette.dart';
import 'round_controller.dart';

/// The single screen of Stuzer. A full-screen [Listener] feeds raw pointer
/// events to the controller; a [CustomPainter] draws everything.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final RoundController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((_) => setState(() {}))..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.onAppHidden();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: c.onPointerDown,
        onPointerMove: c.onPointerMove,
        onPointerUp: c.onPointerUp,
        onPointerCancel: c.onPointerCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GamePainter(c)),
            _Overlay(controller: c),
            Align(
              alignment: Alignment.topRight,
              child: _MuteButton(controller: c),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text that sits above the painted layer: hints, countdown, messages.
class _Overlay extends StatelessWidget {
  const _Overlay({required this.controller});

  final RoundController controller;

  @override
  Widget build(BuildContext context) {
    final round = controller.round;
    final now = controller.now;
    final style = Theme.of(context).textTheme;

    Widget? message;
    switch (round.phase) {
      case RoundPhase.gathering:
        if (round.fingers.isEmpty) {
          message = _Hint('Everyone, put a finger on the screen');
        } else if (round.fingers.length < round.config.minFingers) {
          message = _Hint('Add more fingers');
        }
      case RoundPhase.locked:
        message = _Hint('Locked in', emphasis: true);
      case RoundPhase.countdown:
      case RoundPhase.race:
        final number = controller.lastTickNumber;
        final at = controller.lastTickAt;
        if (number != null && at != null) {
          final progress =
              (now - at).inMicroseconds / round.config.beat.inMicroseconds;
          message = _Marquee(
            text: number == 0 ? 'GO' : '$number',
            progress: progress.clamp(0.0, 1.0),
            color: number == 0 ? const Color(0xFF7CFF6B) : Colors.white,
          );
        }
        if (round.phase == RoundPhase.race &&
            controller.stragglerMessage != null) {
          message = Stack(children: [
            ?message,
            Align(
              alignment: const Alignment(0, 0.6),
              child: _Hint(controller.stragglerMessage!),
            ),
          ]);
        }
      case RoundPhase.results:
        message = const Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: 24),
            child: _Hint('Touch to play again', small: true),
          ),
        );
      case RoundPhase.aborted:
        final reason = controller.abortReason;
        message = _Hint(
          reason == AbortReason.lostFocus
              ? 'Interrupted. Touch to start over.'
              : 'Too many fingers, the device gave up.\nTouch to start over.',
          emphasis: true,
        );
    }

    return IgnorePointer(
      child: DefaultTextStyle(
        style: style.headlineMedium!.copyWith(color: Colors.white),
        child: message ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.emphasis = false, this.small = false});

  final String text;
  final bool emphasis;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: small ? 18 : (emphasis ? 44 : 28),
          fontWeight: emphasis ? FontWeight.w800 : FontWeight.w400,
          color: Colors.white.withValues(alpha: emphasis ? 0.95 : 0.7),
          letterSpacing: emphasis ? 2 : 0,
        ),
      ),
    );
  }
}

/// A countdown number sweeping right-to-left across the centre over one beat.
class _Marquee extends StatelessWidget {
  const _Marquee({
    required this.text,
    required this.progress,
    required this.color,
  });

  final String text;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Ease so the number lingers in the middle and rushes at the edges.
    final eased = Curves.easeInOutCubic.transform(progress);
    final x = 1.4 - 2.8 * eased; // Alignment x from off-right to off-left
    final fade = (1 - (x.abs() - 0.9).clamp(0.0, 0.5) * 2).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment(x, 0),
      child: Opacity(
        opacity: fade,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 220,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: [
              Shadow(color: color.withValues(alpha: 0.6), blurRadius: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.controller});

  final RoundController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.round.phase;
    final visible =
        phase == RoundPhase.gathering || phase == RoundPhase.results;
    if (!visible) return const SizedBox.shrink();
    final muted = controller.sounds.muted;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: IconButton(
          icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
          color: Colors.white54,
          onPressed: controller.toggleMute,
        ),
      ),
    );
  }
}

/// Draws finger discs, place labels, and transient bursts.
class _GamePainter extends CustomPainter {
  _GamePainter(this.c) : super(repaint: c);

  final RoundController c;

  static const discRadius = 56.0;

  @override
  void paint(Canvas canvas, Size size) {
    final now = c.now;
    final round = c.round;

    _paintBursts(canvas, now);

    final placements = round.placements;
    for (final finger in round.fingers) {
      final pos = Offset(finger.position.x, finger.position.y);
      final color = fingerColor(finger.ordinal);
      Placement? placement;
      if (placements != null) {
        placement = placements.firstWhere((p) => p.finger == finger);
      }
      _paintDisc(canvas, pos, color, finger, placement, round, now);
    }
  }

  void _paintDisc(Canvas canvas, Offset pos, Color color, Finger finger,
      Placement? placement, Round round, Duration now) {
    final held = finger.isHeld;
    final lifted = !held;
    final falseStarted = lifted &&
        round.goAt != null &&
        finger.liftedAt! < round.goAt!;

    // Glow.
    final glow = Paint()
      ..color = color.withValues(alpha: held ? 0.45 : 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(pos, discRadius * 1.3, glow);

    // Disc.
    final disc = Paint()..color = color.withValues(alpha: held ? 0.95 : 0.55);
    canvas.drawCircle(pos, discRadius, disc);

    // Rim.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white.withValues(alpha: held ? 0.9 : 0.4);
    canvas.drawCircle(pos, discRadius, rim);

    // Label: place during/after the Race, red for false starts.
    String? big;
    String? small;
    Color labelColor = Colors.white;
    if (placement != null) {
      big = _ordinal(placement.place);
      switch (placement.kind) {
        case LiftKind.legitimate:
          small = _fmt(placement.offsetFromGo!);
        case LiftKind.falseStart:
          labelColor = const Color(0xFFFF3B3B);
          small = '${_fmt(-placement.offsetFromGo!)} early';
        case LiftKind.straggler:
          small = 'Held';
      }
    } else if (falseStarted) {
      big = '!';
      labelColor = const Color(0xFFFF3B3B);
    } else if (lifted && round.goAt != null) {
      // Provisional legitimate place during the Race.
      final place = round.fingers
          .where((f) =>
              f.liftedAt != null &&
              f.liftedAt! >= round.goAt! &&
              (f.liftedAt! < finger.liftedAt! ||
                  (f.liftedAt == finger.liftedAt &&
                      f.landedAt <= finger.landedAt)))
          .length;
      big = _ordinal(place);
      small = _fmt(finger.liftedAt! - round.goAt!);
    }

    if (big != null) {
      _text(canvas, big, pos.translate(0, small == null ? 0 : -10),
          fontSize: 40, color: labelColor, weight: FontWeight.w900);
    }
    if (small != null) {
      _text(canvas, small, pos.translate(0, 26),
          fontSize: 16, color: labelColor.withValues(alpha: 0.9));
    }
  }

  void _paintBursts(Canvas canvas, Duration now) {
    for (final b in c.bursts) {
      final t = (now - b.startedAt).inMicroseconds / 1e6;
      final pos = Offset(b.position.x, b.position.y);
      switch (b.kind) {
        case BurstKind.ripple:
          if (t > 0.8) continue;
          final p = t / 0.8;
          canvas.drawCircle(
            pos,
            discRadius + 160 * Curves.easeOut.transform(p),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6 * (1 - p)
              ..color = b.color.withValues(alpha: 0.7 * (1 - p)),
          );
        case BurstKind.falseStart:
          if (t > 1.0) continue;
          final p = t;
          for (var i = 0; i < 3; i++) {
            final lp = ((p - i * 0.12) / 0.7).clamp(0.0, 1.0);
            if (lp <= 0) continue;
            canvas.drawCircle(
              pos,
              discRadius + 260 * Curves.easeOutCubic.transform(lp),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 14 * (1 - lp) + 2
                ..color = const Color(0xFFFF2A2A).withValues(alpha: 0.9 * (1 - lp)),
            );
          }
          // Angry spikes.
          final spikes = Paint()
            ..color = const Color(0xFFFF2A2A).withValues(alpha: (1 - p) * 0.9)
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round;
          final r0 = discRadius + 10 + 180 * p;
          for (var i = 0; i < 12; i++) {
            final a = i * pi / 6 + p * 0.6;
            final from = pos + Offset(cos(a), sin(a)) * r0;
            final to = pos + Offset(cos(a), sin(a)) * (r0 + 40 * (1 - p) + 8);
            canvas.drawLine(from, to, spikes);
          }
        case BurstKind.confetti:
          if (t > 3.0) continue;
          _confetti(canvas, pos, t, 90, 620, seedBase: b.startedAt.inMilliseconds);
        case BurstKind.flourish:
          if (t > 1.6) continue;
          _confetti(canvas, pos, t, 28, 320, seedBase: b.startedAt.inMilliseconds);
      }
    }
  }

  void _confetti(Canvas canvas, Offset origin, double t, int count,
      double speed, {required int seedBase}) {
    final rnd = Random(seedBase);
    for (var i = 0; i < count; i++) {
      final angle = rnd.nextDouble() * 2 * pi;
      final v = speed * (0.4 + rnd.nextDouble() * 0.6);
      final hue = rnd.nextDouble() * 360;
      final spin = rnd.nextDouble() * 12 - 6;
      final size = 6 + rnd.nextDouble() * 8;
      final life = 1.6 + rnd.nextDouble() * 1.4;
      if (t > life) continue;
      final p = t / life;
      final x = origin.dx + cos(angle) * v * t * (1 - 0.35 * p);
      final y = origin.dy + sin(angle) * v * t * (1 - 0.35 * p) + 380 * t * t;
      final paint = Paint()
        ..color = HSLColor.fromAHSL(1 - p, hue, 0.9, 0.6).toColor();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin * t);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.6), paint);
      canvas.restore();
    }
  }

  void _text(Canvas canvas, String s, Offset center,
      {required double fontSize,
      required Color color,
      FontWeight weight = FontWeight.w600}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  static String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  static String _fmt(Duration d) {
    final sign = d.isNegative ? '-' : '+';
    final ms = d.inMilliseconds.abs();
    return '$sign${(ms / 1000).toStringAsFixed(3)}s';
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}
