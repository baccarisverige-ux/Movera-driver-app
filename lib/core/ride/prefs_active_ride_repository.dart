import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';

import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:movera/core/storage/local_write_session.dart';

import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable [ActiveRideRepository] backed by SharedPreferences.
///
/// On Flutter web this is `localStorage` key `flutter.movera_driver_active_ride`.
/// Stale snapshots older than [PersistedActiveRide.freshnessWindow] are dropped
/// so an abandoned trip cannot revive days later.
class PrefsActiveRideRepository
    implements
        ActiveRideRepository,
        TerminalRideRepository,
        RideHandoffRepository,
        UnreadableRideRecovery {
  PrefsActiveRideRepository({
    Future<SharedPreferences> Function()? load,
    bool sharedAcrossTabs = kIsWeb,
  }) : _loadCached = load ?? SharedPreferences.getInstance,
       _sharedAcrossTabs = sharedAcrossTabs;

  /// SharedPreferences key. Web localStorage prefix is `flutter.`.
  static const key = 'movera_driver_active_ride';
  static const terminalKey = 'movera_driver_terminal_trips';
  static const maxTerminalMarkers = 256;
  static const terminalRetention = Duration(days: 90);

  final Future<SharedPreferences> Function() _loadCached;

  /// Web: other tabs of the app share this localStorage, and the
  /// SharedPreferences cache never sees their writes. Each operation
  /// re-reads storage first, so its guards (ownership, no rewind, terminal
  /// trips) check what is really stored (driver-r4-23).
  final bool _sharedAcrossTabs;

  Future<SharedPreferences> _load() async {
    final SharedPreferences prefs;
    try {
      prefs = await _loadCached();
    } catch (error) {
      throw ActiveRideStorageUnavailable(error);
    }
    if (_sharedAcrossTabs) await prefs.reload();
    return prefs;
  }

  final int _generation = LocalWriteSession.generation;

  // SharedPreferences operations are asynchronous. Keep them in invocation
  // order so a previous ride's cleanup cannot remove a newer ride's snapshot.
  static Future<void>? _pending;

  /// Completes after every storage operation queued so far has finished.
  static Future<void> settle() async {
    final pending = _pending;
    if (pending != null) {
      await pending;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final previous = _pending;
    final result = previous == null
        ? operation()
        : previous.then((_) => operation());
    final tail = result.then<void>((_) {}).catchError((
      Object error,
      StackTrace stack,
    ) {
      DriverLog.error('Active-ride storage operation failed', error, stack);
    });
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) {
        _pending = null;
      }
    });
    return result;
  }

  @override
  Future<PersistedActiveRide?> read() => _enqueue(() async {
    // A failing storage plugin is transient: let it propagate for Retry.
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final PersistedActiveRide ride;
    try {
      ride = _decodeSnapshot(raw);
    } catch (error, stack) {
      DriverLog.error('Active-ride snapshot parse failed', error, stack);
      throw ActiveRideUnreadable(error);
    }
    final terminal = prefs.getStringList(terminalKey) ?? <String>[];
    if (terminal.any((item) => _terminalTripId(item) == ride.tripId)) {
      return null;
    }
    return ride;
  });

  static PersistedActiveRide _decodeSnapshot(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Malformed active ride');
    }
    final ride = PersistedActiveRide.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (ride == null) {
      throw const FormatException('Unsupported or malformed active ride');
    }
    return ride;
  }

  /// Moves an unreadable snapshot aside so the driver can continue.
  ///
  /// Only acts when the stored record really cannot be decoded; a readable
  /// trip is never discarded through this path.
  @override
  Future<void> quarantineUnreadable() => _enqueue(() async {
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      _decodeSnapshot(raw);
      return;
    } catch (error) {
      await LocalQuarantine.store(
        prefs,
        source: 'active_ride',
        raw: raw,
        reason: '${DriverLog.scrub(error)}',
      );
    }
    if (!await prefs.remove(key)) {
      throw StateError('Unreadable trip could not be closed');
    }
  });

  @override
  Future<void> save(PersistedActiveRide ride) => _enqueue(() async {
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    final terminal = prefs.getStringList(terminalKey) ?? <String>[];
    if (terminal.any((item) => _terminalTripId(item) == ride.tripId)) {
      throw StateError('Cannot revive a terminal trip');
    }
    final raw = prefs.getString(key);
    if (raw != null) {
      final current = jsonDecode(raw);
      if (current is! Map ||
          (current['tripId'] != ride.tripId &&
              !terminal.any(
                (item) => _terminalTripId(item) == current['tripId'],
              ))) {
        throw RideOwnershipConflict('Another trip owns the active snapshot');
      }
      final stage = ActiveRideStage.values.byName(current['stage'] as String);
      if (current['tripId'] == ride.tripId && stage.index > ride.stage.index) {
        throw StateError('Cannot rewind trip progress');
      }
    }
    if (!await prefs.setString(key, jsonEncode(ride.stamped().toJson()))) {
      throw StateError('Active ride could not be saved');
    }
  });

  @override
  Future<void> handoff(String expectedTripId, PersistedActiveRide next) =>
      _enqueue(() async {
        final prefs = await _load();
        LocalWriteSession.check(_generation);
        final raw = prefs.getString(key);
        if (raw != null) {
          final current = jsonDecode(raw);
          if (current is! Map ||
              (current['tripId'] != expectedTripId &&
                  current['tripId'] != next.tripId)) {
            throw RideOwnershipConflict(
              'Queued handoff conflicts with a newer active trip',
            );
          }
          if (current['tripId'] == next.tripId) {
            return;
          } // Never rewind an already progressing next trip.
        }
        final terminal = prefs.getStringList(terminalKey) ?? <String>[];
        if (terminal.any((item) => _terminalTripId(item) == next.tripId)) {
          throw RideOwnershipConflict('Queued trip is already terminal');
        }
        // Keeps a stamp the journal gave it (driver-u37).
        final stamped = next.stamped(next.savedAt);
        if (!await prefs.setString(key, jsonEncode(stamped.toJson()))) {
          throw StateError('Queued handoff write failed');
        }
      });

  @override
  Future<void> markTerminal(
    String tripId,
    TripStatus status, {
    String? reasonCode,
    String? actor,
    DateTime? occurredAt,
    bool authoritative = false,
  }) => _enqueue(() async {
    // A driver cancel before pickup hands the trip back to dispatch
    // (contract v0.3): it is over for this phone, so it is marked too.
    if (!status.endsDriverTrip) {
      throw ArgumentError('Terminal status required');
    }
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    final ids = prefs.getStringList(terminalKey) ?? <String>[];
    final at = (occurredAt ?? DateTime.now()).toUtc();
    final existing = ids.where((item) => _terminalTripId(item) == tripId);
    final marker = existing.isNotEmpty && !authoritative
        ? existing.first
        : [
            tripId,
            status.wireName,
            reasonCode ?? '',
            actor ?? '',
            at.toIso8601String(),
          ].map(_escapeField).join('|');

    ids.removeWhere((item) => _terminalTripId(item) == tripId);
    ids.add(marker);

    final retained = _pruneTerminalMarkers(ids, currentTripId: tripId, now: at);
    if (!await prefs.setStringList(terminalKey, retained)) {
      throw StateError('Terminal marker could not be saved');
    }
  });

  static List<String> _pruneTerminalMarkers(
    List<String> markers, {
    required String currentTripId,
    required DateTime now,
  }) {
    final seen = <String>{};
    final newestFirst = <String>[];

    for (final marker in markers.reversed) {
      final id = _terminalTripId(marker);
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }

      if (id != currentTripId) {
        final timestamp = _terminalTimestamp(marker);
        if (timestamp != null &&
            now.difference(timestamp) > terminalRetention) {
          continue;
        }
      }

      newestFirst.add(marker);
      if (newestFirst.length >= maxTerminalMarkers) {
        break;
      }
    }

    return newestFirst.reversed.toList(growable: false);
  }

  static DateTime? _terminalTimestamp(String marker) {
    final parts = marker.split('|');
    if (parts.length < 5 || parts[4].isEmpty) {
      return null;
    }
    return DateTime.tryParse(_unescapeField(parts[4]))?.toUtc();
  }

  static String _terminalTripId(String marker) {
    final separator = marker.indexOf('|');
    return _unescapeField(
      separator < 0 ? marker : marker.substring(0, separator),
    );
  }

  /// Marker fields are pipe-separated; escape the delimiter so an ID or
  /// reason containing '|' cannot change which trip a marker protects.
  /// Fields without '%' or '|' encode to themselves, so legacy markers parse.
  static String _escapeField(String value) =>
      value.replaceAll('%', '%25').replaceAll('|', '%7C');

  static String _unescapeField(String value) =>
      value.replaceAll('%7C', '|').replaceAll('%25', '%');

  @override
  Future<void> clearForTrip(String tripId) => _enqueue(() async {
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    final raw = prefs.getString(key);
    if (raw == null) {
      return;
    }
    final data = jsonDecode(raw);
    if (data is! Map || data['tripId'] != tripId) {
      return;
    }
    if (!await prefs.remove(key)) {
      throw StateError('Trip cleanup failed');
    }
  });

  @override
  Future<void> clear() => _enqueue(() async {
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    if (!await prefs.remove(key)) {
      throw StateError('Active ride could not be cleared');
    }
  });
}
