import 'dart:convert';

import 'package:movera/core/privacy/local_data.dart' show localDataOwnerKey;
import 'package:shared_preferences/shared_preferences.dart';

/// App-lifecycle audit 2026-11-20 item 1: an SOS Movera has not confirmed
/// yet, kept on the phone so it is sent again after a network loss or an
/// app restart. Its Idempotency-Key stays the same, so Movera gets one SOS.
class PendingSos {
  const PendingSos({
    required this.key,
    required this.body,
    this.tripId,
    this.driverId,
  });

  final String key;
  final String? tripId;

  /// The driver who pressed it (this phone's signed-in driver at press
  /// time): another driver signed in later never sends it. Never filled
  /// in later.
  final String? driverId;
  final Map<String, Object?> body;

  Map<String, Object?> toJson() => {
    'key': key,
    if (tripId != null) 'tripId': tripId,
    if (driverId != null) 'driverId': driverId,
    'body': body,
  };

  static PendingSos? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final body = json['body'];
    final trip = json['tripId'];
    final driver = json['driverId'];
    if (key is! String || key.isEmpty || body is! Map) return null;
    return PendingSos(
      key: key,
      tripId: trip is String && trip.isNotEmpty ? trip : null,
      driverId: driver is String && driver.isNotEmpty ? driver : null,
      body: Map<String, Object?>.from(body),
    );
  }
}

/// Where the one pending SOS is kept (the phone's preferences). One slot:
/// a newer press replaces an older unconfirmed one (each press is one
/// incident on the same trip, so the newest carries the latest GPS).
class PendingSosStore {
  const PendingSosStore();

  static const prefKey = 'pending_sos_v1';

  /// The driver signed in on this phone now (the local data owner,
  /// `local_data.dart`); null when none.
  Future<String?> owner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(localDataOwnerKey);
      return id == null || id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  Future<PendingSos?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      return raw == null ? null : PendingSos.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PendingSos sos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, jsonEncode(sos.toJson()));
    } catch (_) {
      // No storage: the in-memory retries still go on.
    }
  }

  /// Clears only the SOS with [key], so a newer press is never dropped.
  Future<void> clear(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = await read();
      if (now == null || now.key == key) await prefs.remove(prefKey);
    } catch (_) {}
  }
}
