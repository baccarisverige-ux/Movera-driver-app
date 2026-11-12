/// F2 (supervisor 2026-11-12): the zone of the phone's POSITION, held
/// before it is used for the driver's settings, so a driver parked on a
/// zone line with GPS jitter does not read `GET /driver/config` and reopen
/// its stream on every flip.
///
/// The first zone known applies at once. After that, another zone (or
/// none) is used only once it was seen in [count] position updates in a
/// row AND [hold] passed since the first of them; seeing the zone in use
/// again, or a third zone, starts over. 2 updates and 15 s: the online
/// reporter sends every 10 s and Home's GPS about every second, so a real
/// crossing applies within about 15 to 20 s, while jitter that flips back
/// inside 15 s never does. A trip's zone (`TripProjection.zoneId`) does
/// not go through here: it applies at once.
class PositionZoneHold {
  PositionZoneHold({
    DateTime Function()? now,
    this.hold = const Duration(seconds: 15),
    this.count = 2,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration hold;
  final int count;

  bool _known = false;
  String? _stable;
  String? _candidate;
  DateTime? _since;
  int _seen = 0;

  /// True once a first zone was seen.
  bool get known => _known;

  /// The zone in use (null: none known, or the phone is in no zone).
  String? get zone => _stable;

  /// One position update in [zone] (null: in no open zone). Returns the
  /// zone in use after it.
  String? observe(String? zone) {
    if (!_known) {
      if (zone == null) return null;
      _known = true;
      _stable = zone;
      return zone;
    }
    if (zone == _stable) {
      _candidate = null;
      _seen = 0;
      return _stable;
    }
    final at = _now();
    if (_seen == 0 || zone != _candidate) {
      _candidate = zone;
      _since = at;
      _seen = 1;
    } else {
      _seen++;
    }
    if (_seen >= count && at.difference(_since!) >= hold) {
      _stable = zone;
      _candidate = null;
      _seen = 0;
    }
    return _stable;
  }
}
