import 'package:flutter/foundation.dart';

/// Driver group 3 (contract v0.18.4 §29, G3-R2): the server says whether
/// the driver's latest position is outside all of his own zones
/// (`outsideArea`, with `areaZones` names when true) on the go-online
/// answer, `GET /driver/profile` and every `DriverLocationAck`. Home shows
/// "You are not eligible to drive in this area" when it turns true, and
/// again only after it was false (or after going offline).
class DriverAreaWatch extends ChangeNotifier {
  DriverAreaWatch();

  static final DriverAreaWatch instance = DriverAreaWatch();

  bool? _outside;

  /// The zone names of a popup Home has not shown yet; null: none due.
  List<String>? _pending;

  bool? get outside => _outside;
  List<String>? get pendingZones => _pending;

  /// Reads `outsideArea` / `areaZones` of a server answer; a missing value
  /// (the server has no position yet) changes nothing.
  void observe(Map<String, dynamic>? json) {
    final value = json?['outsideArea'];
    if (value is! bool) return;
    final was = _outside;
    _outside = value;
    if (!value) {
      if (_pending != null) {
        _pending = null;
        notifyListeners();
      }
      return;
    }
    if (was == true) return;
    _pending = [
      if (json?['areaZones'] case final List zones)
        for (final zone in zones)
          if (zone is Map && zone['name'] is String && zone['name'] != '')
            zone['name'] as String,
    ];
    notifyListeners();
  }

  /// The popup's zone names, once.
  List<String>? take() {
    final zones = _pending;
    _pending = null;
    return zones;
  }

  /// Offline: the next go-online outside his zones says so again.
  void reset() {
    _outside = null;
    _pending = null;
  }
}

/// Decision 3 + G3-R1: the driver was set offline without asking (the app
/// restarted while he was online, or the server's job after
/// `autoOffline.noFixMinutes` without a position). Home shows "You were
/// set offline – tap to go online again" until he goes online or taps it.
class DriverSetOfflineNotice extends ValueNotifier<bool> {
  DriverSetOfflineNotice() : super(false);

  static final DriverSetOfflineNotice instance = DriverSetOfflineNotice();

  void show() => value = true;
  void clear() => value = false;
}
