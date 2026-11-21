/// Radar limits in the driver app (contract §3.3, `DriverAppConfig.offers.radarApp`,
/// admin Dispatch › Modes): how many Radar trips the full-screen list and
/// the offer cards over the map show, stopped and while driving with no
/// rider on board.
class RadarAppLimits {
  const RadarAppLimits({
    this.fullOn = true,
    this.full = 8,
    this.fullLockWhileDriving = true,
    this.popupOn = true,
    this.popup = 2,
    this.popupSplitByDriving = false,
    this.popupWhileDriving = 1,
  });

  /// The published `offers.radarApp`; a missing or bad value keeps [base]
  /// (the same ranges admin checks: list 1–20, cards 1–5).
  factory RadarAppLimits.fromJson(
    Map<dynamic, dynamic> json, {
    RadarAppLimits base = const RadarAppLimits(),
  }) {
    bool flag(String key, bool keep) =>
        json[key] is bool ? json[key] as bool : keep;
    int count(String key, int max, int keep) {
      final raw = json[key];
      return raw is num && raw == raw.roundToDouble() && raw >= 1 && raw <= max
          ? raw.toInt()
          : keep;
    }

    return RadarAppLimits(
      fullOn: flag('fullOn', base.fullOn),
      full: count('full', 20, base.full),
      fullLockWhileDriving: flag(
        'fullLockWhileDriving',
        base.fullLockWhileDriving,
      ),
      popupOn: flag('popupOn', base.popupOn),
      popup: count('popup', 5, base.popup),
      popupSplitByDriving: flag(
        'popupSplitByDriving',
        base.popupSplitByDriving,
      ),
      popupWhileDriving: count('popupWhileDriving', 5, base.popupWhileDriving),
    );
  }

  final bool fullOn;
  final int full;
  final bool fullLockWhileDriving;
  final bool popupOn;
  final int popup;
  final bool popupSplitByDriving;
  final int popupWhileDriving;

  /// Whether the full-screen Radar list may open now.
  bool listOpen({required bool moving}) =>
      fullOn && !(moving && fullLockWhileDriving);

  /// At most this many trips in the full-screen list.
  int get listLimit => fullOn ? full : 0;

  /// At most this many Radar cards over the map now.
  int cardLimit({required bool moving}) {
    if (!popupOn) return 0;
    return moving && popupSplitByDriving ? popupWhileDriving : popup;
  }
}

/// Splits the Home Radar deck at [limit] (§3.3): the first [limit] distinct
/// trips show as cards, the rest are held (never lost) until a slot frees;
/// trips that [gone] says ran out leave the held ones. A smaller limit
/// moves cards back to held; a larger one promotes held trips.
({List<T> shown, List<T> held}) splitRadarDeck<T>(
  Iterable<T> deck, {
  required int limit,
  required String Function(T) id,
  bool Function(T)? gone,
}) {
  final seen = <String>{};
  final shown = <T>[], held = <T>[];
  for (final item in deck) {
    if (!seen.add(id(item))) continue;
    (shown.length < limit ? shown : held).add(item);
  }
  if (gone != null) held.removeWhere(gone);
  return (shown: shown, held: held);
}

/// Stopped or driving, judged on the phone (`contract.json#driverMotion`):
/// moving once the speed stays at least [movingSpeedMps] for [hysteresis],
/// stopped once it stays below for as long, so a red light does not flicker.
class DriverMotion {
  DriverMotion({
    this.movingSpeedMps = 1,
    this.hysteresis = const Duration(seconds: 10),
  });

  final double movingSpeedMps;
  final Duration hysteresis;

  bool _moving = false;
  DateTime? _otherSince;

  bool get moving => _moving;

  /// Offline: back to stopped, no half-judged change kept.
  void reset() {
    _moving = false;
    _otherSince = null;
  }

  /// Feeds one fix; returns true when the state changed.
  bool update({required double? speedMps, required DateTime at}) {
    if (speedMps == null || !speedMps.isFinite || speedMps < 0) return false;
    final fast = speedMps >= movingSpeedMps;
    if (fast == _moving) {
      _otherSince = null;
      return false;
    }
    final since = _otherSince ??= at;
    if (at.difference(since) < hysteresis) return false;
    _moving = fast;
    _otherSince = null;
    return true;
  }
}
