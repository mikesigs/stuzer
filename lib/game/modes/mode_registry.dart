import 'classic_mode.dart';
import 'game_mode.dart';
import 'race_mode.dart';

export 'classic_mode.dart';
export 'game_mode.dart';
export 'race_mode.dart';

/// Every Mode the picker offers, in display order. Race is the default.
const List<GameMode> allModes = [RaceMode(), ClassicMode()];

const GameMode defaultMode = RaceMode();

GameMode? modeById(String? id) {
  for (final m in allModes) {
    if (m.id == id) return m;
  }
  return null;
}
