import 'dart:math';
import 'dart:typed_data';

/// Builds short 16-bit mono WAV clips in memory so the app ships no audio
/// assets. Every sound in Stuzer is a few sine partials with an envelope.
class Synth {
  Synth({this.sampleRate = 44100});

  final int sampleRate;

  /// A pleasing note: fundamental plus soft partials, quick attack, gentle
  /// exponential decay.
  Uint8List note(double hz, {double seconds = 0.9, double gain = 0.6}) {
    return _render(seconds, (t) {
      final env = _attack(t, 0.008) * exp(-3.2 * t / seconds);
      final v = sin(2 * pi * hz * t) +
          0.35 * sin(2 * pi * hz * 2 * t) +
          0.12 * sin(2 * pi * hz * 3 * t);
      return gain * env * v / 1.47;
    });
  }

  /// Countdown tick: short, dry, slightly woody.
  Uint8List tick({double hz = 1200, double seconds = 0.08}) {
    return _render(seconds, (t) {
      final env = _attack(t, 0.002) * exp(-40 * t);
      return 0.6 * env * (sin(2 * pi * hz * t) + 0.3 * sin(2 * pi * hz * 2.7 * t));
    });
  }

  /// Go: a bright rising chirp with a firm body.
  Uint8List go({double seconds = 0.35}) {
    return _render(seconds, (t) {
      final hz = 600 + 900 * (t / seconds);
      final env = _attack(t, 0.004) * exp(-6 * t);
      return 0.8 * env * (sin(2 * pi * hz * t) + 0.4 * sin(2 * pi * hz * 2 * t));
    });
  }

  /// Lock-in: a low, weighty thunk with a metallic tail.
  Uint8List lock({double seconds = 0.5}) {
    return _render(seconds, (t) {
      final env = _attack(t, 0.003) * exp(-9 * t);
      return 0.8 *
          env *
          (sin(2 * pi * 110 * t) +
              0.5 * sin(2 * pi * 220 * t) +
              0.25 * sin(2 * pi * 1760 * t) * exp(-30 * t));
    });
  }

  /// Winner's ding: a bell.
  Uint8List ding({double hz = 1568, double seconds = 1.2}) {
    return _render(seconds, (t) {
      final env = _attack(t, 0.002) * exp(-3.5 * t);
      return 0.7 *
          env *
          (sin(2 * pi * hz * t) +
              0.6 * sin(2 * pi * hz * 2.76 * t) * exp(-6 * t) +
              0.3 * sin(2 * pi * hz * 5.4 * t) * exp(-10 * t)) /
          1.9;
    });
  }

  /// Fanfare: a quick ascending major arpeggio ending on a held chord.
  Uint8List fanfare() {
    const seconds = 1.6;
    const steps = [523.25, 659.25, 783.99, 1046.5]; // C5 E5 G5 C6
    return _render(seconds, (t) {
      var v = 0.0;
      for (var i = 0; i < steps.length; i++) {
        final start = i * 0.12;
        if (t < start) continue;
        final lt = t - start;
        final hold = i == steps.length - 1 ? 1.0 : 0.25;
        final env = _attack(lt, 0.006) * exp(-4 * lt / hold);
        v += env * (sin(2 * pi * steps[i] * lt) + 0.3 * sin(2 * pi * steps[i] * 2 * lt));
      }
      // Sustained chord under the final note.
      if (t > 0.36) {
        final lt = t - 0.36;
        final env = _attack(lt, 0.02) * exp(-2.2 * lt);
        for (final hz in [523.25, 659.25, 783.99]) {
          v += 0.35 * env * sin(2 * pi * hz * lt);
        }
      }
      return 0.35 * v;
    });
  }

  double _attack(double t, double a) => t < a ? t / a : 1.0;

  Uint8List _render(double seconds, double Function(double t) f) {
    final n = (seconds * sampleRate).round();
    final data = ByteData(44 + n * 2);
    // RIFF header.
    _ascii(data, 0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    _ascii(data, 8, 'WAVE');
    _ascii(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    _ascii(data, 36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (var i = 0; i < n; i++) {
      final v = f(i / sampleRate).clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  void _ascii(ByteData d, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      d.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}

/// Pentatonic scale (C major pentatonic across two octaves) for Finger notes.
const pentatonicHz = <double>[
  261.63, 293.66, 329.63, 392.00, 440.00, // C4 D4 E4 G4 A4
  523.25, 587.33, 659.25, 783.99, 880.00, // C5 D5 E5 G5 A5
];
