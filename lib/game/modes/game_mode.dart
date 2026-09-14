import 'dart:math';

import 'package:flutter/material.dart';

import '../../audio/sound_engine.dart';
import '../../config/app_config.dart';
import '../../domain/round.dart';
import '../finger_label.dart';

/// A way of choosing the first player. Wires a pure-Dart [ModeSession] to
/// the presentation that knows how to show it. Register new Modes in
/// mode_registry.dart.
abstract class GameMode {
  const GameMode();

  /// Stable id, also the key in the config file's `modes` section.
  String get id;
  String get name;

  /// One short line telling players what to do.
  String get tagline;
  IconData get icon;

  ModeSession createSession(
    List<Finger> fingers,
    Duration lockInAt,
    AppConfig config,
    Random random,
  );

  /// A fresh presentation for one controller. Holds per-Round visual state.
  ModeUi createUi();
}

/// Transient visual triggered by an effect, drawn by the shared painter.
enum BurstKind { ripple, falseStart, confetti, flourish }

/// What the controller offers a [ModeUi] while it reacts to an effect.
class ModeUiContext {
  const ModeUiContext({
    required this.round,
    required this.sounds,
    required this.now,
    required this.burst,
    required this.random,
    required this.config,
  });

  /// The Round the effect came from; its session carries Mode detail.
  final Round round;
  final SoundEngine sounds;
  final Duration now;
  final void Function(BurstKind kind, Finger finger) burst;
  final Random random;
  final AppConfig config;
}

/// How the shared painter should draw one Finger's disc right now.
class FingerStyle {
  const FingerStyle({this.alpha = 1, this.ring = 0, this.ringColor});

  /// 0..1 multiplier on the disc's opacity; dim the fingers that are out.
  final double alpha;

  /// Width of an extra ring around the disc, 0 for none.
  final double ring;
  final Color? ringColor;

  static const normal = FingerStyle();
}

/// Presentation hooks for the active Mode. The shared screen handles
/// Gathering hints, discs, bursts, Aborted, and the "play again" hint;
/// everything Mode-specific comes through here.
abstract class ModeUi {
  /// React to any effect the Round produced: sounds, haptics, bursts, state.
  void onEffect(RoundEffect effect, ModeUiContext ctx) {}

  /// A new Round began Gathering; forget the last one.
  void onRoundReset() {}

  FingerLabel labelFor(Finger finger, Round round) => FingerLabel.none;

  FingerStyle styleFor(Finger finger, Round round, Duration now) =>
      FingerStyle.normal;

  /// Extra painting above the discs.
  void paintOver(Canvas canvas, Size size, Round round, Duration now) {}

  /// Overlay while playing or showing Results, or null.
  Widget? buildOverlay(BuildContext context, Round round, Duration now) =>
      null;
}
