import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/realtime/reconnect_backoff.dart';

void main() {
  test('D12-6: same steps 1, 2, 4 … 30 s, each with ±10 % jitter', () {
    final random = math.Random(7);
    const steps = [1, 2, 4, 8, 16, 30, 30, 30];
    final waits = <int>{};
    for (var round = 0; round < 50; round++) {
      for (var attempt = 0; attempt < steps.length; attempt++) {
        final ms = reconnectBackoff(attempt, random: random).inMilliseconds;
        final base = steps[attempt] * 1000;
        expect(ms, inInclusiveRange(base * 0.9, base * 1.1));
        if (attempt == 5) waits.add(ms);
      }
    }
    expect(waits.length, greaterThan(10), reason: 'phones do not line up');
  });
}
