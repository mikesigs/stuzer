import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/sound_engine.dart';
import 'config/config_store.dart';
import 'domain/round.dart';
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

  final store = ConfigStore();
  final config = await store.load();
  final sounds = await SoundEngine.create();
  final controller = RoundController(
    sounds: sounds,
    round: Round(config: config),
  )..loadConfig = store.load;
  runApp(StuzerApp(controller: controller));
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
