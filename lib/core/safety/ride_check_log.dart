import 'dart:convert';

import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ride checks per trip, for the trip details. Stays on the phone.
abstract interface class RideCheckLog {
  /// Adds [record], or replaces the one with the same id.
  Future<void> save(RideCheckRecord record);

  Future<List<RideCheckRecord>> forTrip(String tripId);
}

class MemoryRideCheckLog implements RideCheckLog {
  MemoryRideCheckLog([List<RideCheckRecord>? seed])
    : _rows = List<RideCheckRecord>.of(seed ?? const <RideCheckRecord>[]);

  final List<RideCheckRecord> _rows;

  List<RideCheckRecord> get rows => List<RideCheckRecord>.unmodifiable(_rows);

  @override
  Future<void> save(RideCheckRecord record) async {
    final index = _rows.indexWhere((row) => row.id == record.id);
    if (index < 0) {
      _rows.add(record);
    } else {
      _rows[index] = record;
    }
  }

  @override
  Future<List<RideCheckRecord>> forTrip(String tripId) async => [
    for (final row in _rows)
      if (row.tripId == tripId) row,
  ];
}

/// Local demo storage of Ride checks, cleared at logout like trip history.
class PrefsRideCheckLog implements RideCheckLog {
  PrefsRideCheckLog({Future<SharedPreferences> Function()? load})
    : _load = load ?? SharedPreferences.getInstance;

  static const key = 'movera_driver_ride_checks';
  static const maxRows = 200;
  final Future<SharedPreferences> Function() _load;
  static Future<void>? _pending;

  static Future<void> settle() async {
    await _pending;
  }

  /// A save that started before logout never writes after its cleanup.
  @override
  Future<void> save(RideCheckRecord record) {
    final generation = LocalWriteSession.generation;
    return _enqueue(() => _save(record, generation));
  }

  Future<void> _save(RideCheckRecord record, int generation) async {
    LocalWriteSession.check(generation);
    final prefs = await _load();
    LocalWriteSession.check(generation);
    final rows = _read(prefs)
      ..removeWhere((row) => row.id == record.id)
      ..add(record);
    rows.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    final ok = await prefs.setString(
      key,
      jsonEncode({
        'schemaVersion': 1,
        'rows': [for (final row in rows.take(maxRows)) row.toJson()],
      }),
    );
    if (!ok) throw StateError('Could not save the Ride check');
  }

  @override
  Future<List<RideCheckRecord>> forTrip(String tripId) => _enqueue(() async {
    final prefs = await _load();
    return [
      for (final row in _read(prefs).reversed)
        if (row.tripId == tripId) row,
    ];
  });

  List<RideCheckRecord> _read(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return <RideCheckRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['schemaVersion'] == 1) {
        final rows = decoded['rows'];
        if (rows is List) {
          return [
            for (final row in rows)
              if (RideCheckRecord.fromJson(row) case final record?) record,
          ];
        }
      }
    } on FormatException catch (error) {
      DriverLog.warn('Ride check log malformed: ${DriverLog.scrub(error)}');
    }
    return <RideCheckRecord>[];
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final previous = _pending;
    final result = previous == null ? action() : previous.then((_) => action());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) _pending = null;
    });
    return result;
  }
}
