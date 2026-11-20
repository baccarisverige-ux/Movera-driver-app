import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// App-lifecycle audit 2026-11-20 item 1: an SOS Movera has not confirmed
/// yet, kept on the phone so it is sent again after a network loss or an
/// app restart. Its Idempotency-Key stays the same, so Movera gets one SOS.
class PendingSos {
  const PendingSos({required this.key, required this.body, this.tripId});

  final String key;
  final String? tripId;
  final Map<String, Object?> body;

  Map<String, Object?> toJson() => {
    'key': key,
    if (tripId != null) 'tripId': tripId,
    'body': body,
  };

  static PendingSos? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = json['key'];
    final body = json['body'];
    final trip = json['tripId'];
    if (key is! String || key.isEmpty || body is! Map) return null;
    return PendingSos(
      key: key,
      tripId: trip is String && trip.isNotEmpty ? trip : null,
      body: Map<String, Object?>.from(body),
    );
  }
}

/// Where the one pending SOS is kept (the phone's preferences).
class PendingSosStore {
  const PendingSosStore();

  static const prefKey = 'pending_sos_v1';

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
