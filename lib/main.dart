import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/sound_engine.dart';
import 'game/game_screen.dart';
import 'game/round_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await WakelockPlus.enable();

  final sounds = await SoundEngine.create();
  runApp(StuzerApp(controller: RoundController(sounds: sounds)));
}

class StuzerApp extends StatelessWidget {
  const StuzerApp({super.key, required this.controller});

  final RoundController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stuzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: GameScreen(controller: controller),
    );
  }
}
