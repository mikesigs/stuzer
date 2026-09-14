import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../domain/modes/race/race_session.dart';
import '../../domain/round.dart';
import '../finger_label.dart';
import 'game_mode.dart';

class RaceMode extends GameMode {
  const RaceMode();

  @override
  String get id => 'race';
  @override
  String get name => 'Race';
  @override
  String get tagline => 'After GO, fastest finger off the screen goes first';
  @override
  IconData get icon => Icons.flag;

  @override
  ModeSession createSession(
    List<Finger> fingers,
    Duration lockInAt,
    AppConfig config,
    Random random,
  ) =>
      RaceSession(
        fingers: fingers,
        lockInAt: lockInAt,
        beat: config.round.beat,
        config: config.race,
      );

  @override
  ModeUi createUi() => RaceUi();
}

/// Label for [finger] given the Race's current state.
///
/// Final placements win once the Race has closed. During Racing a
/// legitimate Lift shows its provisional place, which is already final
/// because later Lifts cannot beat it. A False Start shows "!" until Results.
FingerLabel raceLabelFor(Finger finger, RaceSession race, List<Finger> all) {
  final placements = race.placements;
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
  final goAt = race.goAt;
  if (liftedAt == null) return FingerLabel.none;
  if (goAt == null || liftedAt < goAt) {
    return const FingerLabel(big: '!', alarm: true);
  }
  final place = all.where((f) {
    final t = f.liftedAt;
    if (t == null || t < goAt) return false;
    if (t != liftedAt) return t < liftedAt;
    return f.landedAt < finger.landedAt ||
        (f.landedAt == finger.landedAt && f.ordinal <= finger.ordinal);
  }).length;
  return FingerLabel(big: ordinal(place), small: formatOffset(liftedAt - goAt));
}

class RaceUi extends ModeUi {
  Duration? lastTickAt;
  int? lastTickNumber;
  String? stragglerMessage;
  List<String> _teaseOrder = const [];

  @override
  void onRoundReset() {
    lastTickAt = null;
    lastTickNumber = null;
    stragglerMessage = null;
    _teaseOrder = const [];
  }

  @override
  void onEffect(RoundEffect effect, ModeUiContext ctx) {
    switch (effect) {
      case CountdownTick(:final number):
        ctx.sounds.tick();
        HapticFeedback.selectionClick();
        lastTickAt = ctx.now;
        lastTickNumber = number;
      case Go():
        ctx.sounds.go();
        HapticFeedback.heavyImpact();
        lastTickAt = ctx.now;
        lastTickNumber = 0;
        _teaseOrder = _drawTeases(ctx);
      case FalseStarted(:final finger):
        HapticFeedback.vibrate();
        ctx.burst(BurstKind.falseStart, finger);
      case Lifted(:final finger, :final isWinner):
        if (isWinner) ctx.sounds.ding();
        HapticFeedback.lightImpact();
        ctx.burst(BurstKind.ripple, finger);
      case StragglersTeased(:final messageIndex):
        stragglerMessage = _teaseOrder.isEmpty
            ? null
            : _teaseOrder[messageIndex % _teaseOrder.length];
      case RoundFinished():
        stragglerMessage = null;
        // Celebrate only legitimate Lifts; an all-false-start Race has no
        // hero.
        final placements = _race(ctx.round)?.placements ?? const [];
        for (final p in placements) {
          if (p.kind != LiftKind.legitimate) continue;
          if (p.place == 1) {
            ctx.sounds.fanfare();
            ctx.burst(BurstKind.confetti, p.finger);
          } else if (p.place <= 3) {
            ctx.burst(BurstKind.flourish, p.finger);
          }
        }
      case Aborted():
        onRoundReset();
    }
  }

  /// A fresh random order of the message pool, long enough for one Race.
  /// No line repeats until the whole pool has been used.
  List<String> _drawTeases(ModeUiContext ctx) {
    final pool = ctx.config.stragglerMessages;
    if (pool.isEmpty) return const [];
    final needed = ctx.config.race.stragglerMessageCount;
    final out = <String>[];
    while (out.length < needed) {
      final batch = List.of(pool)..shuffle(ctx.random);
      // Across the seam between batches, avoid showing the same line twice
      // in a row when the pool has more than one line.
      if (out.isNotEmpty && batch.length > 1 && batch.first == out.last) {
        batch.add(batch.removeAt(0));
      }
      out.addAll(batch);
    }
    return out.take(needed).toList();
  }

  RaceSession? _race(Round round) =>
      round.session is RaceSession ? round.session! as RaceSession : null;

  @override
  FingerLabel labelFor(Finger finger, Round round) {
    final race = _race(round);
    if (race == null) return FingerLabel.none;
    return raceLabelFor(finger, race, round.fingers);
  }

  @override
  FingerStyle styleFor(Finger finger, Round round, Duration now) =>
      finger.isHeld ? FingerStyle.normal : const FingerStyle(alpha: 0.6);

  @override
  Widget? buildOverlay(BuildContext context, Round round, Duration now) {
    final race = _race(round);
    if (race == null) return null;
    if (round.phase == RoundPhase.results) return null;

    final children = <Widget>[];
    if (race.phase == RacePhase.locked) {
      children.add(const _Centered('Locked in'));
    }
    final number = lastTickNumber;
    final at = lastTickAt;
    if (number != null && at != null && race.phase != RacePhase.locked) {
      final progress = (now - at).inMicroseconds / race.beat.inMicroseconds;
      children.add(FilmCountdown(
        text: number == 0 ? 'GO' : '$number',
        progress: progress.clamp(0.0, 1.0),
        isGo: number == 0,
      ));
    }
    final tease = stragglerMessage;
    if (race.phase == RacePhase.racing && tease != null) {
      children.add(Align(
        alignment: const Alignment(0, 0.7),
        child: Text(
          tease,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ));
    }
    if (children.isEmpty) return null;
    return Stack(fit: StackFit.expand, children: children);
  }
}

class _Centered extends StatelessWidget {
  const _Centered(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      );
}

/// An old film-leader countdown: a big number dead centre inside concentric
/// rings and crosshairs, with a radial wipe sweeping once round per beat.
class FilmCountdown extends StatelessWidget {
  const FilmCountdown({
    super.key,
    required this.text,
    required this.progress,
    required this.isGo,
  });

  final String text;

  /// 0..1 through the current beat.
  final double progress;
  final bool isGo;

  @override
  Widget build(BuildContext context) {
    final color = isGo ? const Color(0xFF7CFF6B) : Colors.white;
    // A quick pop as each number lands, then a settle.
    final pop = 1.0 +
        0.18 *
            (1 -
                Curves.easeOutCubic
                    .transform((progress / 0.18).clamp(0.0, 1.0)));
    // Projector flicker.
    final flicker = 0.9 + 0.1 * (0.5 + 0.5 * sin(progress * 47));
    return LayoutBuilder(builder: (context, constraints) {
      final side = min(constraints.maxWidth, constraints.maxHeight) * 0.92;
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: CustomPaint(
            painter: _FilmReelPainter(
              progress: progress,
              color: color,
              isGo: isGo,
            ),
            child: Center(
              child: Transform.scale(
                scale: pop,
                child: Opacity(
                  opacity: flicker,
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: isGo ? side * 0.42 : side * 0.62,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: color,
                      shadows: [
                        Shadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _FilmReelPainter extends CustomPainter {
  const _FilmReelPainter({
    required this.progress,
    required this.color,
    required this.isGo,
  });

  final double progress;
  final Color color;
  final bool isGo;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.35);
    final thick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withValues(alpha: 0.85);

    // Crosshairs out past the rings.
    canvas.drawLine(
        Offset(c.dx - r * 1.15, c.dy), Offset(c.dx + r * 1.15, c.dy), thin);
    canvas.drawLine(
        Offset(c.dx, c.dy - r * 1.15), Offset(c.dx, c.dy + r * 1.15), thin);

    // Rings.
    canvas.drawCircle(c, r * 0.98, thick);
    canvas.drawCircle(c, r * 0.86, thin);

    if (isGo) {
      // Rings burst outward on Go.
      final burst = Curves.easeOut.transform(progress);
      canvas.drawCircle(
        c,
        r * (0.98 + 0.6 * burst),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10 * (1 - burst) + 1
          ..color = color.withValues(alpha: 0.8 * (1 - burst)),
      );
      return;
    }

    // Radial wipe: a wedge sweeping clockwise from twelve o'clock, filled
    // faintly, with a bright leading hand.
    final sweep = 2 * pi * progress;
    final rect = Rect.fromCircle(center: c, radius: r * 0.86);
    canvas.drawArc(
      rect,
      -pi / 2,
      sweep,
      true,
      Paint()..color = color.withValues(alpha: 0.10),
    );
    final hand = Offset(c.dx + cos(-pi / 2 + sweep) * r * 0.86,
        c.dy + sin(-pi / 2 + sweep) * r * 0.86);
    canvas.drawLine(
      c,
      hand,
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.9),
    );

    // Tick marks around the outer ring, like sprocket holes.
    final tick = Paint()
      ..strokeWidth = 2
      ..color = color.withValues(alpha: 0.5);
    for (var i = 0; i < 24; i++) {
      final a = i * pi / 12;
      final inner = Offset(c.dx + cos(a) * r * 0.90, c.dy + sin(a) * r * 0.90);
      final outer = Offset(c.dx + cos(a) * r * 0.95, c.dy + sin(a) * r * 0.95);
      canvas.drawLine(inner, outer, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmReelPainter old) =>
      old.progress != progress || old.color != color || old.isGo != isGo;
}
