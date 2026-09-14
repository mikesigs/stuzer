import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'synth.dart';

/// Plays Stuzer's sounds with low latency. All clips are synthesised at
/// startup and kept loaded so playback is a single call.
class SoundEngine {
  SoundEngine._();

  /// An engine that never plays anything. For tests and headless runs.
  factory SoundEngine.silent() => SoundEngine._();

  static Future<SoundEngine> create() async {
    final engine = SoundEngine._();
    try {
      await SoLoud.instance.init();
      await engine._loadAll();
      engine._ready = true;
    } catch (e, st) {
      debugPrint('SoundEngine unavailable: $e\n$st');
    }
    return engine;
  }

  bool _ready = false;
  bool muted = false;

  final _notes = <AudioSource>[];
  AudioSource? _tick;
  AudioSource? _go;
  AudioSource? _lock;
  AudioSource? _ding;
  AudioSource? _fanfare;

  Future<void> _loadAll() async {
    final synth = Synth();
    final soloud = SoLoud.instance;
    for (var i = 0; i < pentatonicHz.length; i++) {
      _notes.add(await soloud.loadMem('note$i.wav', synth.note(pentatonicHz[i])));
    }
    _tick = await soloud.loadMem('tick.wav', synth.tick());
    _go = await soloud.loadMem('go.wav', synth.go());
    _lock = await soloud.loadMem('lock.wav', synth.lock());
    _ding = await soloud.loadMem('ding.wav', synth.ding());
    _fanfare = await soloud.loadMem('fanfare.wav', synth.fanfare());
  }

  void _play(AudioSource? source) {
    if (!_ready || muted || source == null) return;
    SoLoud.instance.play(source);
  }

  /// The note for the Finger with this landing ordinal. Cycles the scale.
  void fingerNote(int ordinal) {
    if (_notes.isEmpty) return;
    _play(_notes[ordinal % _notes.length]);
  }
  void tick() => _play(_tick);
  void go() => _play(_go);
  void lock() => _play(_lock);
  void ding() => _play(_ding);
  void fanfare() => _play(_fanfare);

  void dispose() {
    if (_ready) SoLoud.instance.deinit();
  }
}
