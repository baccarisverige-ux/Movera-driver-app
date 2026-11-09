import 'dart:async';

/// Contract v0.18.45 §68 (L-a Q7 "Live push", owner 2026-11-06): the
/// booked-rides list is read again at sign-in, on every settings-stream
/// reconnect and on every `driver_reservations_changed` hint, but at most
/// once every [gap] (2 s). A request inside the gap is not lost: one more
/// read runs when the gap ends, however many requests came in it.
class ReservationsRefresh {
  ReservationsRefresh({
    required Future<void> Function() read,
    this.gap = const Duration(seconds: 2),
  }) : _read = read;

  final Future<void> Function() _read;
  final Duration gap;

  Timer? _wait;
  bool _again = false;
  bool _disposed = false;

  /// Asks for a read: now when none ran in the last [gap], else one at the
  /// end of it.
  void request() {
    if (_disposed) return;
    if (_wait != null) {
      _again = true;
      return;
    }
    _run();
  }

  void _run() {
    _again = false;
    unawaited(_read().catchError((Object _) {}));
    _wait = Timer(gap, () {
      _wait = null;
      if (_again && !_disposed) _run();
    });
  }

  void dispose() {
    _disposed = true;
    _wait?.cancel();
    _wait = null;
  }
}
