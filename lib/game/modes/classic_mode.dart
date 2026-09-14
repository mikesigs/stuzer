import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../domain/modes/classic/classic_session.dart';
import '../../domain/round.dart';
import 'game_mode.dart';

class ClassicMode extends GameMode {
  const ClassicMode();

  @override
  String get id => 'classic';
  @override
  String get name => 'Classic';
  @override
  String get tagline => 'Hold still. The light picks one of you';
  @override
  IconData get icon => Icons.casino;

  @override
  ModeSession createSession(
    List<Finger> fingers,
    Duration lockInAt,
    AppConfig config,
    Random random,
  ) =>
      ClassicSession(
        fingers: fingers,
        lockInAt: lockInAt,
        beat: config.round.beat,
        config: config.classic,
        random: random,
      );

  @override
  ModeUi createUi() => ClassicUi();
}

class ClassicUi extends ModeUi {
  Duration? lastHopAt;
  Duration? chosenAt;

  @override
  void onRoundReset() {
    lastHopAt = null;
    chosenAt = null;
  }

  @override
  void onEffect(RoundEffect effect, ModeUiContext ctx) {
    switch (effect) {
      case SpotlightMoved():
        ctx.sounds.tick();
        HapticFeedback.selectionClick();
        lastHopAt = ctx.now;
      case DroppedOut():
        HapticFeedback.lightImpact();
      case Chosen(:final finger):
        chosenAt = ctx.now;
        ctx.sounds.fanfare();
        HapticFeedback.heavyImpact();
        ctx.burst(BurstKind.confetti, finger);
        ctx.burst(BurstKind.ripple, finger);
      case Aborted():
        onRoundReset();
    }
  }

  ClassicSession? _classic(Round round) =>
      round.session is ClassicSession ? round.session! as ClassicSession : null;

  @override
  FingerStyle styleFor(Finger finger, Round round, Duration now) {
    final c = _classic(round);
    if (c == null) return FingerStyle.normal;
    if (!finger.isHeld && c.chosen != finger) {
      return const FingerStyle(alpha: 0.25);
    }
    final lit = c.chosen ?? c.spotlight;
    if (lit == null) return FingerStyle.normal;
    if (finger == lit) {
      // The lit finger wears a bright ring; once Chosen it pulses.
      final since = chosenAt == null ? 0.0 : (now - chosenAt!).inMicroseconds / 1e6;
      final pulse = c.chosen == null ? 0.0 : 0.5 + 0.5 * sin(since * 6);
      return FingerStyle(
        alpha: 1,
        ring: 10 + 6 * pulse,
        ringColor: Colors.white.withValues(alpha: 0.95),
      );
    }
    // Everyone else recedes a little while the light is elsewhere.
    return FingerStyle(alpha: c.chosen == null ? 0.55 : 0.35);
  }

  @override
  Widget? buildOverlay(BuildContext context, Round round, Duration now) {
    final c = _classic(round);
    if (c == null) return null;
    if (c.phase == ClassicPhase.locked) {
      return Center(
        child: Text(
          'Locked in',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
      );
    }
    if (c.chosen != null) {
      return Align(
        alignment: const Alignment(0, -0.75),
        child: Text(
          'You go first',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      );
    }
    return null;
  }
}
