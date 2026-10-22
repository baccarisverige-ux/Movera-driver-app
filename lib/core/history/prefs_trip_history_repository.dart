import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/logging/driver_log.dart';

import 'dart:convert';

import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/storage/local_write_session.dart';

import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local frontend archive. Trip IDs are unique: a retried completion cannot
/// add a second receipt. The backend adapter can replace this boundary later.
class PrefsTripHistoryRepository {
  PrefsTripHistoryRepository({
    Future<SharedPreferences> Function()? load,
    DateTime Function()? now,
  }) : _load = load ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static const key = 'movera_driver_completed_trips';
  final Future<SharedPreferences> Function() _load;
  final DateTime Function() _now;
  static Future<void>? _pending;
  final int _generation = LocalWriteSession.generation;
  static Future<void> settle() async {
    await _pending;
  }

  Future<List<TripHistoryRecord>> list() => _enqueue(() async {
    LocalWriteSession.check(_generation);
    final prefs = await _load();
    LocalWriteSession.check(_generation);
    final raw = prefs.getString(key);
    if (raw == null) {
      return const <TripHistoryRecord>[];
    }
    final decoded = _decode(raw);
    await _preserveInvalid(prefs, raw, decoded);
    return decoded.rows
        .map(
          (data) => TripHistoryRecord(
            tripId: data['tripId'] as String,
            riderName: data['riderName'] as String,
            whenLabel: data['whenLabel'] as String,
            pickup: data['pickup'] as String,
            dropoff: data['dropoff'] as String,
            fare: data['fare'] as String,
            category: data['category'] as String,
            distance: data['distance'] as String? ?? '—',
            duration: data['duration'] as String? ?? '—',
            tip: data['tip'] as String? ?? '—',
            paymentMethod: data['paymentMethod'] as String? ?? '—',
            // Wire name since contract v0.3; older rows are camelCase.
            status: TripStatusWire.parse(
              data['status'] as String? ?? 'completed',
            ),
            fareMinorUnits: data['fareMinorUnits'] as int?,
            cancellationActor: data['cancellationActor'] as String?,
            cancellationReasonCode: data['cancellationReasonCode'] as String?,
            cashCollected: data['cashCollected'] as String?,
            driverBonus: data['driverBonus'] as String?,
            waitingFee: data['waitingFee'] as String?,
            // Saved in UTC (driver-r4-14); older rows in local time.
            completedAt: DateTime.tryParse(
              data['completedAt'] as String? ?? '',
            )?.toLocal(),
          ),
        )
        .toList(growable: false);
  });

  /// A terminal status, or a driver cancel that sent the trip back to
  /// dispatch (contract v0.3: `searching` / `requested`).
  static bool _validStatus(Object? raw, Object? actor) {
    final status = raw is String ? TripStatusWire.tryParse(raw) : null;
    if (status == null) return false;
    return status.isTerminal ||
        (status.isReleasedToDispatch && actor == 'driver');
  }

  /// Rows kept whatever their age.
  static const maxReceipts = 500;

  /// Rows kept at most: older ones beyond [maxReceipts] stay while the
  /// Month or Week view counts them (driver-u18), up to this ceiling.
  static const maxPeriodReceipts = 5000;

  /// Newest first: the newest [maxReceipts], then every row still in this
  /// calendar month or the last 7 days. A busy driver passes 500 rows
  /// before the month ends; dropping by count alone left the month's
  /// earnings short.
  List<Map<String, dynamic>> _retained(Iterable<Map<String, dynamic>> rows) {
    final now = _now();
    final month = DateTime(now.year, now.month);
    final week = now.subtract(const Duration(days: 7));
    final from = week.isBefore(month) ? week : month;
    final kept = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (kept.length >= maxPeriodReceipts) break;
      if (kept.length >= maxReceipts) {
        final at = DateTime.tryParse(row['completedAt'] as String? ?? '');
        if (at == null || at.isBefore(from)) break;
      }
      kept.add(row);
    }
    return kept;
  }

  _HistoryDecode _decode(String? raw) {
    if (raw == null) {
      return const _HistoryDecode([], invalid: true);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      DriverLog.warn('History JSON malformed: ${DriverLog.scrub(error)}');
      return const _HistoryDecode([], invalid: true);
    }
    if (decoded is Map) {
      if (decoded['schemaVersion'] != 1) {
        return const _HistoryDecode([], invalid: true, unsupported: true);
      }
      decoded = decoded['rows'];
    }
    if (decoded is! List) {
      DriverLog.warn('History rows are malformed');
      return const _HistoryDecode([], invalid: true);
    }
    final rows = <Map<String, dynamic>>[];
    bool invalid = false;
    for (final row in decoded) {
      if (row is! Map ||
          ![
            'tripId',
            'riderName',
            'whenLabel',
            'pickup',
            'dropoff',
            'fare',
            'category',
          ].every((key) => row[key] is String) ||
          (row['tripId'] as String).trim().isEmpty ||
          ![
            'distance',
            'duration',
            'tip',
            'paymentMethod',
            'cancellationActor',
            'cancellationReasonCode',
            'cashCollected',
            'driverBonus',
            'waitingFee',
          ].every((key) => row[key] == null || row[key] is String) ||
          (row['fareMinorUnits'] != null && row['fareMinorUnits'] is! int) ||
          (row['status'] != null &&
              !_validStatus(row['status'], row['cancellationActor'])) ||
          (row['completedAt'] != null &&
              (row['completedAt'] is! String ||
                  DateTime.tryParse(row['completedAt'] as String) == null))) {
        invalid = true;
        DriverLog.warn('Skipping malformed history row');
        continue;
      }
      rows.add(Map<String, dynamic>.from(row));
    }
    rows.sort(
      (a, b) =>
          (DateTime.tryParse(b['completedAt'] as String? ?? '') ??
                  DateTime(1970))
              .compareTo(
                DateTime.tryParse(a['completedAt'] as String? ?? '') ??
                    DateTime(1970),
              ),
    );
    // A legacy duplicate can be ordered oldest first. Select the latest
    // version after sorting rather than losing a corrected/newer receipt.
    final ids = <String>{};
    final unique = rows.where((row) => ids.add(row['tripId'] as String));
    return _HistoryDecode(_retained(unique), invalid: invalid);
  }

  Future<void> _preserveInvalid(
    SharedPreferences prefs,
    String raw,
    _HistoryDecode decoded,
  ) async {
    if (!decoded.invalid) return;
    LocalWriteSession.check(_generation);
    await LocalQuarantine.storeOnce(
      prefs,
      source: 'history',
      raw: raw,
      reason: 'Malformed or unsupported history data',
    );
  }

  Future<void> archive(
    WaybillRecord record, {
    DateTime? completedAt,
    String? distance,
    String? duration,
    String? tip,
    String? paymentMethod,
    String? cashCollected,
    TripStatus status = TripStatus.completed,
    String? cancellationActor,
    String? cancellationReasonCode,
    bool authoritative = false,
  }) {
    if (record.tripId.trim().isEmpty ||
        !(status.isTerminal ||
            (status.isReleasedToDispatch && cancellationActor == 'driver'))) {
      return Future<void>.error(
        ArgumentError('A terminal trip with a nonempty ID is required'),
      );
    }
    final at = (completedAt ?? DateTime.now()).toLocal();
    Future<void> write() async {
      final prefs = await _load();
      final raw = prefs.getString(key);
      LocalWriteSession.check(_generation);
      final decoded = _decode(raw);
      if (raw != null) {
        await _preserveInvalid(prefs, raw, decoded);
      }
      if (decoded.unsupported) {
        throw StateError('Unsupported history schema; original preserved');
      }
      final rows = List<Map<String, dynamic>>.of(decoded.rows);
      if (rows.whereType<Map>().any((row) => row['tripId'] == record.tripId)) {
        if (!authoritative) return;
        rows.removeWhere((row) => row['tripId'] == record.tripId);
      }
      rows.insert(0, <String, dynamic>{
        'tripId': record.tripId,
        'riderName': record.riderName,
        'whenLabel':
            '${at.day}/${at.month}/${at.year}, ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
        'pickup': record.pickup,
        'dropoff': record.dropoff,
        'fare': record.fare,
        'status': status.wireName,
        if (status == TripStatus.completed &&
            Money.parseSekLabel(record.fare) != null)
          'fareMinorUnits': Money.parseSekLabel(record.fare)!.minorUnits,
        if (cancellationActor != null) 'cancellationActor': cancellationActor,
        if (cancellationReasonCode != null)
          'cancellationReasonCode': cancellationReasonCode,
        'category': record.service,
        if (distance?.trim().isNotEmpty == true) 'distance': distance!.trim(),
        if (duration?.trim().isNotEmpty == true) 'duration': duration!.trim(),
        if (tip?.trim().isNotEmpty == true) 'tip': tip!.trim(),
        if (paymentMethod?.trim().isNotEmpty == true)
          'paymentMethod': paymentMethod!.trim(),
        if (cashCollected?.trim().isNotEmpty == true)
          'cashCollected': cashCollected!.trim(),
        if (record.driverBonus != null) 'driverBonus': record.driverBonus,
        // driver-u19: Movera takes no fee on it, as on the waybill.
        if (record.waitingFee != null) 'waitingFee': record.waitingFee,
        // UTC: a local time has no offset, so the repeated autumn hour
        // would read back an hour off (driver-r4-14).
        'completedAt': at.toUtc().toIso8601String(),
      });
      rows.sort(
        (a, b) =>
            (DateTime.tryParse(b['completedAt'] as String? ?? '') ??
                    DateTime(1970))
                .compareTo(
                  DateTime.tryParse(a['completedAt'] as String? ?? '') ??
                      DateTime(1970),
                ),
      );
      LocalWriteSession.check(_generation);
      final success = await prefs.setString(
        key,
        jsonEncode({
          'schemaVersion': 1,
          'rows': _retained(rows),
        }),
      );
      if (!success) {
        throw StateError('Could not archive completed trip');
      }
    }

    return _enqueue(write);
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

class _HistoryDecode {
  const _HistoryDecode(
    this.rows, {
    this.invalid = false,
    this.unsupported = false,
  });
  final List<Map<String, dynamic>> rows;
  final bool invalid;
  final bool unsupported;
}
