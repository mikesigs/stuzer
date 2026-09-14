import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/round_config.dart';
import 'round_config_json.dart';

/// Reads the tuning file from the app's private storage on the device.
///
/// On Android that is `/data/data/com.mikesigs.stuzer/files/stuzer.json`.
/// A debug build can be updated over adb without reinstalling; see
/// `scripts/push-config.ps1`. If the file is missing the defaults are written
/// there so there is always something to edit.
class ConfigStore {
  ConfigStore({this.fileName = 'stuzer.json'});

  final String fileName;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<RoundConfig> load() async {
    const defaults = RoundConfig();
    try {
      final file = await _file();
      if (!await file.exists()) {
        await save(defaults);
        debugPrint('Stuzer config: wrote defaults to ${file.path}');
        return defaults;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        debugPrint('Stuzer config: ${file.path} is not a JSON object');
        return defaults;
      }
      final config = roundConfigFromJson(decoded);
      debugPrint('Stuzer config: ${describeRoundConfig(config)}');
      return config;
    } catch (e) {
      debugPrint('Stuzer config: unreadable, using defaults ($e)');
      return defaults;
    }
  }

  Future<void> save(RoundConfig config) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(roundConfigToJson(config))}\n');
  }
}
