import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stuzer/domain/round.dart';
import 'package:stuzer/game/finger_label.dart';

const _o = Point<double>(0, 0);
Duration s(num seconds) => Duration(milliseconds: (seconds * 1000).round());

void main() {
  test('ordinals', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 101, 111].map(ordinal), [
      '1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd',
      '23rd', '101st', '111th',
    ]);
  });

  test('offsets format to milliseconds with a sign', () {
    expect(formatOffset(s(0.2134)), '+0.213s');
    expect(formatOffset(s(-1.5)), '-1.500s');
    expect(formatOffset(s(0.31), signed: false), '0.310s');
  });

  test('labels through a Round', () {
    final round = Round();
    round.fingerDown(1, _o, s(0));
    round.fingerDown(2, _o, s(0.1));
    round.fingerDown(3, _o, s(0.2));
    final fingers = {for (final f in round.fingers) f.id: f};
    expect(labelFor(fingers[1]!, round), FingerLabel.none);

    round.advance(s(3.2)); // Lock-in at 3.2, Go at 7.2
    round.fingerUp(1, s(5)); // False Start
    expect(labelFor(fingers[1]!, round), const FingerLabel(big: '!', alarm: true));

    round.advance(s(7.2));
    round.fingerUp(2, s(7.45));
    expect(labelFor(fingers[2]!, round), const FingerLabel(big: '1st', small: '+0.250s'));
    expect(labelFor(fingers[3]!, round), FingerLabel.none);

    round.advance(s(12.2)); // Race closes; 3 is a Straggler
    expect(labelFor(fingers[2]!, round), const FingerLabel(big: '1st', small: '+0.250s'));
    expect(labelFor(fingers[1]!, round),
        const FingerLabel(big: '2nd', small: '2.200s early', alarm: true));
    expect(labelFor(fingers[3]!, round), const FingerLabel(big: '3rd', small: 'Held'));
  });
}
