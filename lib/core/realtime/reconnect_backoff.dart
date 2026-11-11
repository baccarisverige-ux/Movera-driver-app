import 'dart:math' as math;

final math.Random _random = math.Random();

/// D12-6: the offer feed and the trip stream wait 1 s, 2 s, 4 s … up to
/// 30 s between tries, each with ±10 % jitter (as the config stream, #548),
/// so a deploy does not bring every phone back in the same second.
Duration reconnectBackoff(int attempt, {math.Random? random}) {
  final step = math.min(30, 1 << math.min(attempt, 5)) * 1000;
  final factor = 0.9 + 0.2 * (random ?? _random).nextDouble();
  return Duration(milliseconds: (step * factor).round());
}
