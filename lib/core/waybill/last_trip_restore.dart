import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/trip_finish.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owner 2026-11-26 ("Why cant see last trip (amount in island)"; "Ok"):
/// Home's LAST TRIP amount survives an app restart. The last trip is kept
/// on the phone (offline) and, when the island has none, read back from
/// the server's newest finished trip (`GET /driver/trips`, the driver's
/// TripProjection with its `finish` block and `driverTotal`). The amount
/// is always the server's driverTotal, never worked out on the phone.
class LastTripRestore {
  LastTripRestore._();

  static const prefsKey = 'driver_last_trip_v1';

  /// Test seam: the `GET /driver/trips` body, null without a live server.
  static Future<Map<String, dynamic>?> Function()? readTrips;

  static WaybillRepository? _watched;
  static bool _busy = false;

  static Future<Map<String, dynamic>?> _readLive() async {
    final api = LiveDriverServices.instance?.api;
    if (api == null) return null;
    return api.get('/api/v1/driver/trips?limit=5');
  }

  /// Saves every new last trip on the phone, once per repository.
  static void watch(WaybillRepository waybills) {
    if (identical(_watched, waybills)) return;
    _watched = waybills;
    waybills.lastListenable.addListener(() => unawaited(_save(waybills.last)));
  }

  static Future<void> _save(WaybillRecord? last) async {
    final generation = LocalWriteSession.generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (last == null) {
        await prefs.remove(prefsKey);
        return;
      }
      if (!last.fare.contains(RegExp(r'\d'))) return;
      // Never write a departing driver's trip after sign-out began.
      if (!_sameSession(generation)) return;
      await prefs.setString(
        prefsKey,
        jsonEncode({
          'tripId': last.tripId,
          'fare': last.fare,
          'issuedAt': last.issuedAt.toUtc().toIso8601String(),
          'paidByCash': last.paidByCash,
        }),
      );
    } catch (_) {
      // A failed save only loses the offline copy.
    }
  }

  /// Fills an empty LAST TRIP: the phone's copy first, then the server's
  /// newest finished trip (newer than the phone's, or the same trip with
  /// its final money).
  static Future<void> restore(WaybillRepository waybills) async {
    watch(waybills);
    if (waybills.last != null || _busy || LocalWriteSession.clearing) return;
    final generation = LocalWriteSession.generation;
    _busy = true;
    try {
      final saved = await _readSaved();
      // A sign-out meanwhile: the next driver never sees this trip.
      if (!_sameSession(generation)) return;
      if (saved != null) waybills.restoreLast(saved);
      final Map<String, dynamic>? body;
      try {
        body = await (readTrips ?? _readLive)();
      } catch (_) {
        return;
      }
      final server = body == null ? null : newestFinished(body);
      if (server == null || !_sameSession(generation)) return;
      final shown = waybills.last;
      if (shown == null) {
        waybills.restoreLast(server);
      } else if (identical(shown, saved) &&
          (shown.tripId == server.tripId ||
              server.issuedAt.isAfter(shown.issuedAt))) {
        // Still the restored copy: the server's is newer or final.
        waybills.restoreLast(server, over: saved);
      }
    } finally {
      _busy = false;
    }
  }

  static bool _sameSession(int generation) =>
      !LocalWriteSession.clearing && LocalWriteSession.generation == generation;

  static Future<WaybillRecord?> _readSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _record(
        tripId: json['tripId'] as String,
        fare: json['fare'] as String,
        issuedAt: DateTime.parse(json['issuedAt'] as String).toLocal(),
        paidByCash: json['paidByCash'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// The newest item with a `finish` block (completed, ended early, a
  /// cancel with the rider on board) and the driver's own total.
  @visibleForTesting
  static WaybillRecord? newestFinished(Map<String, dynamic> body) {
    final items = body['items'];
    if (items is! List) return null;
    for (final item in items) {
      if (item is! Map) continue;
      final json = Map<String, dynamic>.from(item);
      final finish = TripFinishInfo.tryParse(json['finish']);
      if (finish == null) continue;
      Money? total;
      final raw = json['driverTotal'];
      if (raw is Map) {
        try {
          total = Money.fromJson(Map<String, dynamic>.from(raw));
        } on FormatException {
          total = null;
        }
      }
      total ??= finish.driverTotal;
      final id = json['tripId'];
      if (total == null || id is! String) continue;
      final ended =
          DateTime.tryParse(
            (json['endedAt'] ?? json['updatedAt'] ?? json['createdAt'] ?? '')
                as String,
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return _record(
        tripId: id,
        fare: total.formatted,
        issuedAt: ended,
        paidByCash: json['paymentMethod'] == 'cash',
      );
    }
    return null;
  }

  static WaybillRecord _record({
    required String tripId,
    required String fare,
    required DateTime issuedAt,
    required bool paidByCash,
  }) => WaybillRecord(
    tripId: tripId,
    statusLabel: WaybillRecord.completed,
    issuedAt: issuedAt,
    fare: fare,
    service: '',
    riderName: '',
    pickup: '',
    dropoff: '',
    source: WaybillRecord.restoredSource,
    driverName: '',
    vehicle: '',
    licensePlate: '',
    passengerCapacity: 0,
    paidByCash: paidByCash,
  );

  @visibleForTesting
  static void resetForTesting() {
    readTrips = null;
    _watched = null;
    _busy = false;
  }
}
