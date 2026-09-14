import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/audio/sound_engine.dart';
import 'package:stuzer/domain/round.dart';
import 'package:stuzer/game/finger_label.dart';
import 'package:stuzer/game/round_controller.dart';
import 'package:stuzer/main.dart';

Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

/// Fingers land at 0, Lock-in 3, ticks 3/2/1 at 4/5/6, Go 7, close 12.

/// Disc labels are painted on a canvas, so read them through [labelFor].
FingerLabel labelOf(RoundController c, int pointer) {
  final finger = c.round.fingers.singleWhere((f) => f.id == pointer);
  return labelFor(finger, c.round);
}

Future<RoundController> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = RoundController(sounds: SoundEngine.silent());
  await tester.pumpWidget(StuzerApp(controller: controller));
  return controller;
}

void main() {
  testWidgets('two fingers play a full Round through the real screen',
      (tester) async {
    final controller = await pumpApp(tester);
    expect(find.text('Everyone, put a finger on the screen'), findsOneWidget);

    // Two fingers land at t=0.
    final left = await tester.startGesture(const Offset(300, 400), pointer: 1);
    await tester.pump();
    expect(find.text('Add more fingers'), findsOneWidget);
    expect(controller.round.phase, RoundPhase.gathering);

    final right =
        await tester.startGesture(const Offset(1300, 400), pointer: 2);
    await tester.pump();
    expect(controller.round.fingers.length, 2);

    // Lock-in after 3 seconds of stability.
    await tester.pump(s(3));
    expect(controller.round.phase, RoundPhase.locked);
    expect(find.text('Locked in'), findsOneWidget);

    // Countdown 3, 2, 1, one per beat.
    for (final n in [3, 2, 1]) {
      await tester.pump(s(1));
      expect(controller.round.phase, RoundPhase.countdown);
      expect(find.text('$n'), findsOneWidget, reason: 'expected $n on screen');
    }

    // Go at 7 s.
    await tester.pump(s(1));
    expect(controller.round.phase, RoundPhase.race);
    expect(controller.round.goAt, s(7));
    expect(find.text('GO'), findsOneWidget);

    // Right finger lifts first and wins; left lifts next.
    await right.up(timeStamp: s(7.2));
    await tester.pump();
    expect(controller.round.phase, RoundPhase.race);
    expect(labelOf(controller, 2),
        const FingerLabel(big: '1st', small: '+0.200s'));

    await left.up(timeStamp: s(7.5));
    await tester.pump();
    expect(controller.round.phase, RoundPhase.results);
    expect(labelOf(controller, 1),
        const FingerLabel(big: '2nd', small: '+0.500s'));
    expect(find.text('Touch to play again'), findsOneWidget);
    expect(controller.bursts.where((b) => b.kind == BurstKind.confetti),
        hasLength(1));

    // A new finger starts a fresh Round.
    final again = await tester.startGesture(const Offset(800, 400), pointer: 3);
    await tester.pump();
    expect(controller.round.phase, RoundPhase.gathering);
    expect(find.text('Add more fingers'), findsOneWidget);
    await again.up(timeStamp: s(20));
    await tester.pump();
  });

  testWidgets('a False Start shows the alarm, and Stragglers get teased',
      (tester) async {
    final controller = await pumpApp(tester);

    final a = await tester.startGesture(const Offset(300, 400), pointer: 1);
    final b = await tester.startGesture(const Offset(800, 400), pointer: 2);
    final c = await tester.startGesture(const Offset(1300, 400), pointer: 3);
    await tester.pump(s(5)); // locked at 3, "3" at 4, "2" at 5

    await a.up(timeStamp: s(5.5)); // False Start
    await tester.pump();
    expect(labelOf(controller, 1), const FingerLabel(big: '!', alarm: true));
    expect(controller.bursts.where((x) => x.kind == BurstKind.falseStart),
        hasLength(1));

    await tester.pump(s(2)); // 7.5 s: Go was at 7
    expect(controller.round.phase, RoundPhase.race);

    await b.up(timeStamp: s(7.3));
    await tester.pump(s(2)); // 9.5 s: first tease at 9
    expect(controller.stragglerMessage, isNotNull);
    expect(find.text(controller.stragglerMessage!), findsOneWidget);

    await tester.pump(s(3)); // 12.5 s: Race closed at 12
    expect(controller.round.phase, RoundPhase.results);
    expect(labelOf(controller, 2),
        const FingerLabel(big: '1st', small: '+0.300s'));
    expect(labelOf(controller, 1),
        const FingerLabel(big: '2nd', small: '1.500s early', alarm: true));
    expect(
        labelOf(controller, 3), const FingerLabel(big: '3rd', small: 'Held'));
    expect(controller.stragglerMessage, isNull);

    await c.up(timeStamp: s(13));
    await tester.pump();
    expect(controller.round.phase, RoundPhase.results);
  });

  testWidgets('everyone letting go during Locked shows the abort message',
      (tester) async {
    final controller = await pumpApp(tester);
    final a = await tester.startGesture(const Offset(300, 400), pointer: 1);
    final b = await tester.startGesture(const Offset(1300, 400), pointer: 2);
    await tester.pump(s(3));
    expect(controller.round.phase, RoundPhase.locked);

    await a.up(timeStamp: s(3.2));
    await b.up(timeStamp: s(3.4));
    await tester.pump();
    expect(controller.round.phase, RoundPhase.aborted);
    expect(find.textContaining('Everyone let go'), findsOneWidget);
  });

  testWidgets('losing focus mid-Round aborts it with an explanation',
      (tester) async {
    final controller = await pumpApp(tester);
    final a = await tester.startGesture(const Offset(300, 400), pointer: 1);
    final b = await tester.startGesture(const Offset(1300, 400), pointer: 2);
    await tester.pump(s(4));
    expect(controller.round.phase, RoundPhase.countdown);

    controller.onAppHidden();
    await tester.pump();
    expect(controller.round.phase, RoundPhase.aborted);
    expect(find.textContaining('Interrupted'), findsOneWidget);

    await a.up(timeStamp: s(5));
    await b.up(timeStamp: s(5));
    await tester.pump();
    expect(controller.round.phase, RoundPhase.aborted);
  });
}
