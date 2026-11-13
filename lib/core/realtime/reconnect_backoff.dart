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

/// Owner 2026-11-13 (R3; contract `realtime.streamClose`, v0.18.68): a
/// stream counts as connected, and its backoff starts again from the
/// shortest wait, only after a real event (a `data:` block) or once it
/// stayed open this long. A stream the server ends right after it opened
/// (B1.9: a busy server closes it after its reads fail) is one more failed
/// try, so quick repeated closes back off. A `: heartbeat` or a bare `id:`
/// cursor is not an event.
const streamConnectedAfter = Duration(seconds: 30);

/// The longest Retry-After a stream honours (as the location sender).
const streamMaxRetryAfter = Duration(seconds: 60);

/// The wait a 503 or 429 asks for in its `Retry-After` header (seconds),
/// at most [streamMaxRetryAfter]; null for any other answer or no header.
Duration? streamRetryAfter(int status, Map<String, String> headers) {
  if (status != 503 && status != 429) return null;
  final seconds = int.tryParse(headers['retry-after']?.trim() ?? '');
  if (seconds == null || seconds <= 0) return null;
  final wait = Duration(seconds: seconds);
  return wait > streamMaxRetryAfter ? streamMaxRetryAfter : wait;
}
