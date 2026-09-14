import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio/sound_engine.dart';
import 'config/config_store.dart';
import 'game/game_screen.dart';
import 'game/modes/mode_registry.dart';
import 'game/round_controller.dart';

const _modePrefKey = 'stuzer.mode';

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
  final prefs = await SharedPreferences.getInstance();
  final mode = modeById(prefs.getString(_modePrefKey)) ?? defaultMode;
  final sounds = await SoundEngine.create();
  final controller = RoundController(sounds: sounds, config: config, mode: mode)
    ..loadConfig = store.load
    ..onModeChanged = (m) => prefs.setString(_modePrefKey, m.id);
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
