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

/// Why the driver was set offline, as far as the app knows it (owner
/// 2026-10-31 "new set offline message": the card says the real reason).
enum DriverOfflineReason {
  /// G3-R1: the server's job, no position for `noFixMinutes` (contract
  /// `driverHome.setOffline` reason `no_position`, bell notice kind
  /// `set_offline`).
  noPosition,

  /// Contract `autoOffline`: `missedExclusive` Exclusive offers in a row
  /// missed or declined (the app's own count, or the offer event's
  /// `driverOffline: true`).
  missedOffers,

  /// Decision 3: the app restarted while the driver was online (contract
  /// `driverHome.setOffline` reason `app_restart`).
  appRestart,

  /// v0.18.6 `vehicle_blocked`: an admin rejected or blocked his car
  /// (with the admin's note).
  vehicleBlocked,

  /// v0.18.6 `fleet_removed`: removed from his fleet, or the fleet was
  /// blocked.
  fleetRemoved,

  /// v0.18.6 `account_status`: an admin paused the account.
  accountStatus,

  /// v0.18.6 `admin`, or the server set him offline without saying why.
  movera;

  /// `Driver.offlineReason` (contract v0.18.6); null for an unknown one.
  static DriverOfflineReason? fromServer(String? reason) => switch (reason) {
    'no_position' => noPosition,
    'missed_offers' => missedOffers,
    'vehicle_blocked' => vehicleBlocked,
    'fleet_removed' => fleetRemoved,
    'account_status' => accountStatus,
    'admin' => movera,
    _ => null,
  };
}

/// Decision 3 + G3-R1: the driver was set offline without asking (the app
/// restarted while he was online, the server's job after
/// `autoOffline.noFixMinutes` without a position, missed offers, the
/// server for another reason). Home shows the "You're offline" card with
/// [reason] until he goes online, taps OK, or 2 minutes pass.
class DriverSetOfflineNotice extends ValueNotifier<bool> {
  DriverSetOfflineNotice() : super(false);

  static final DriverSetOfflineNotice instance = DriverSetOfflineNotice();

  DriverOfflineReason _reason = DriverOfflineReason.movera;
  int? _count;
  String? _note;

  /// Why; [DriverOfflineReason.movera] when nothing says.
  DriverOfflineReason get reason => _reason;

  /// [DriverOfflineReason.missedOffers]: how many in a row;
  /// [DriverOfflineReason.noPosition]: the minutes without a position.
  int? get count => _count;

  /// [DriverOfflineReason.vehicleBlocked]: the admin's note.
  String? get note => _note;

  void show({
    DriverOfflineReason reason = DriverOfflineReason.movera,
    int? count,
    String? note,
  }) {
    _reason = reason;
    _count = count;
    _note = note;
    if (value) {
      notifyListeners();
    } else {
      value = true;
    }
  }

  void clear() => value = false;
}
