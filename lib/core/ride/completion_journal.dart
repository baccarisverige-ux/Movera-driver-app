import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:movera/core/storage/local_write_session.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/trip_transitions.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Result of applying a stored completion journal.
enum JournalReplayOutcome {
  /// No journal was stored.
  none,

  /// The stored transaction was applied completely.
  applied,

  /// The journal could not be decoded. Its raw text was quarantined.
  quarantinedCorrupt,

  /// Trip A was closed, but its queued trip conflicted with a newer active
  /// trip. The newer trip was kept and the journal was quarantined.
  quarantinedConflict,
}

/// Replayable local transaction. Navigation to B only occurs after reconciliation.
class CompletionJournal {
  CompletionJournal({
    required this.active,
    PrefsTripHistoryRepository? history,
    Future<SharedPreferences> Function()? load,
    this.afterWrite,
  }) : history = history ?? PrefsTripHistoryRepository(),
       load = load ?? SharedPreferences.getInstance;
  static const key = 'movera_driver_completion_journal';
  final ActiveRideRepository active;
  final PrefsTripHistoryRepository history;
  final Future<SharedPreferences> Function() load;
  final void Function(String step)? afterWrite;
  static Future<void>? _pending;
  final int _generation = LocalWriteSession.generation;

  /// Completes after every storage operation queued so far has finished.
  static Future<void> settle() async {
    final pending = _pending;
    if (pending != null) {
      await pending;
    }
  }

  @visibleForTesting
  static void resetForTesting() {
    _pending = null;
  }

  Future<void> _serial(Future<void> Function() action) {
    final previous = _pending;
    // Start an idle queue directly: do not retain a Future from another test zone.
    Future<void> currentAction() async {
      LocalWriteSession.check(_generation);
      await action();
    }

    final result = previous == null
        ? currentAction()
        : previous.then((_) => currentAction());
    final tail = result.catchError((Object _) {});
    _pending = tail;
    tail.then((_) {
      if (identical(_pending, tail)) {
        _pending = null;
      }
    });
    return result;
  }

  Future<void> finish(
    WaybillRecord record, {
    PersistedActiveRide? next,
    TripStatus status = TripStatus.completed,
    String? cancellationReasonCode,
    String? cancellationActor,
    bool authoritative = false,
    String? paymentMethod,
    String? cashCollected,
    DateTime? endedAt,
    String? feeEarned,
    GeoPoint? pickupPoint,
    GeoPoint? dropoffPoint,
  }) => _serial(() async {
    final prefs = await load();
    // Do not overwrite an earlier unfinished transaction.
    if (prefs.getString(key) != null) {
      await _replay(prefs);
    }
    // [endedAt]: a saved trip closed long after it was last alive ended
    // then, so its next trip keeps its own age (driver-r5-36).
    final terminalAt = endedAt ?? DateTime.now();
    final payload = {
      'schemaVersion': 2,
      'tripId': record.tripId,
      // Contract wire name (v0.3). Older saves used camelCase; both parse.
      'status': status.wireName,
      'authoritative': authoritative,
      // UTC, as local time has no offset (driver-r4-14).
      'completedAt': terminalAt.toUtc().toIso8601String(),
      'record': {
        'tripId': record.tripId,
        'riderName': record.riderName,
        'fare': record.fare,
        'service': record.service,
        'pickup': record.pickup,
        'dropoff': record.dropoff,
        // "Cash" for a cash trip: its details show the cash collected and
        // what is owed to Movera (Q23).
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        // R8-4: the cash taken, which can differ from the fare.
        if (cashCollected != null) 'cashCollected': cashCollected,
        // Q16/Q18: Movera's bonus in the fare, for the earnings history.
        if (record.driverBonus != null) 'driverBonus': record.driverBonus,
        // Q43 / driver-u19: the waiting fee in the fare (no Movera fee).
        if (record.waitingFee != null) 'waitingFee': record.waitingFee,
        // driver-r5-13: the cancel or no-show fee the driver earned.
        if (feeEarned != null) 'feeEarned': feeEarned,
        // v0.18.10 (owner G8 item 1): the rider's tip, all the driver's.
        if (record.tip != null) 'tip': record.tip!.amount.formatted,
        // v0.17.0: the past-ride map's pins without the server.
        if (pickupPoint != null && dropoffPoint != null) ...{
          'pickupLat': pickupPoint.latitude,
          'pickupLng': pickupPoint.longitude,
          'dropoffLat': dropoffPoint.latitude,
          'dropoffLng': dropoffPoint.longitude,
        },
      },
      if (cancellationReasonCode != null || cancellationActor != null)
        'cancellation': {
          if (cancellationReasonCode != null)
            'reasonCode': cancellationReasonCode,
          'actor': cancellationActor ?? 'unknown',
        },
      if (next != null) 'next': next.toJson(),
    };
    if (!await prefs.setString(key, jsonEncode(payload))) {
      throw StateError('Completion journal write failed');
    }
    afterWrite?.call('journal');
    await _replay(prefs);
  });

  /// Applies any interrupted transaction. Never leaves a journal behind that
  /// would block later trips: undecodable or conflicting entries are moved to
  /// quarantine and reported through the returned outcome.
  Future<JournalReplayOutcome> reconcile() async {
    var outcome = JournalReplayOutcome.none;
    await _serial(() async {
      final SharedPreferences prefs;
      try {
        prefs = await load();
      } catch (error) {
        throw ActiveRideStorageUnavailable(error);
      }
      outcome = await _replay(prefs);
    });
    return outcome;
  }

  Future<JournalReplayOutcome> _replay(SharedPreferences prefs) async {
    final raw = prefs.getString(key);
    if (raw == null) {
      return JournalReplayOutcome.none;
    }
    final _DecodedJournal entry;
    try {
      entry = _DecodedJournal.parse(raw);
    } catch (error) {
      await LocalQuarantine.store(
        prefs,
        source: 'completion_journal',
        raw: raw,
        reason: '${DriverLog.scrub(error)}',
      );
      if (!await prefs.remove(key)) {
        throw StateError('Completion journal cleanup failed');
      }
      return JournalReplayOutcome.quarantinedCorrupt;
    }
    final data = entry.data;
    final id = entry.tripId;
    final status = entry.status;
    final row = entry.record;
    final at = entry.completedAt;
    {
      await history.archive(
        WaybillRecord(
          tripId: id,
          statusLabel: _statusLabel(status),
          issuedAt: at,
          fare: row['fare'] as String,
          service: row['service'] as String,
          riderName: row['riderName'] as String,
          pickup: row['pickup'] as String,
          dropoff: row['dropoff'] as String,
          source: WaybillRecord.localDemoSource,
          driverName: WaybillRecord.unavailable,
          vehicle: WaybillRecord.unavailable,
          licensePlate: WaybillRecord.unavailable,
          passengerCapacity: 0,
          driverBonus: row['driverBonus'] is String
              ? row['driverBonus'] as String
              : null,
          waitingFee: row['waitingFee'] is String
              ? row['waitingFee'] as String
              : null,
        ),
        completedAt: at,
        status: status,
        paymentMethod: row['paymentMethod'] is String
            ? row['paymentMethod'] as String
            : null,
        cashCollected: row['cashCollected'] is String
            ? row['cashCollected'] as String
            : null,
        feeEarned: row['feeEarned'] is String
            ? row['feeEarned'] as String
            : null,
        tip: row['tip'] is String ? row['tip'] as String : null,
        pickupPoint: PrefsTripHistoryRepository.pointOf(
          row['pickupLat'],
          row['pickupLng'],
        ),
        dropoffPoint: PrefsTripHistoryRepository.pointOf(
          row['dropoffLat'],
          row['dropoffLng'],
        ),
        authoritative: data['authoritative'] == true,
        cancellationActor: data['cancellation'] is Map
            ? (data['cancellation'] as Map)['actor'] as String?
            : null,
        cancellationReasonCode: data['cancellation'] is Map
            ? (data['cancellation'] as Map)['reasonCode'] as String?
            : null,
      );
      afterWrite?.call('archive');
    }
    final cancellation = data['cancellation'];
    final cancellationMap = cancellation is Map
        ? Map<String, dynamic>.from(cancellation)
        : null;
    final repository = active;
    if (repository is TerminalRideRepository) {
      await (repository as TerminalRideRepository).markTerminal(
        id,
        status,
        reasonCode: cancellationMap?['reasonCode'] as String?,
        actor: cancellationMap?['actor'] as String?,
        occurredAt: at,
        authoritative: data['authoritative'] == true,
      );
    }
    afterWrite?.call('terminal');
    // Stamped when trip A ended, not now: a journal replayed days later
    // must leave B as old as it is, so Home still asks before restoring
    // it (driver-u37).
    final next = entry.next?.stamped(at);
    if (next != null) {
      try {
        if (repository is RideHandoffRepository) {
          await (repository as RideHandoffRepository).handoff(id, next);
        } else {
          final current = await active.read();
          if (current != null &&
              current.tripId != id &&
              current.tripId != next.tripId) {
            throw RideOwnershipConflict(
              'Queued handoff conflicts with a newer active trip',
            );
          }
          if (current?.tripId != next.tripId) {
            await active.save(next);
          }
        }
      } on RideOwnershipConflict catch (error) {
        // Trip A is already archived and terminal above. Keep the newer trip
        // and retain the queued trip's data in quarantine for diagnosis.
        await LocalQuarantine.store(
          prefs,
          source: 'completion_journal',
          raw: raw,
          reason: error.message,
        );
        if (!await prefs.remove(key)) {
          throw StateError('Completion journal cleanup failed');
        }
        afterWrite?.call('cleanup');
        return JournalReplayOutcome.quarantinedConflict;
      }
    } else {
      // Clear only A; do not erase an independently accepted newer trip.
      if (repository is TerminalRideRepository) {
        await (repository as TerminalRideRepository).clearForTrip(id);
      } else {
        final current = await active.read();
        if (current == null || current.tripId == id) {
          await active.clear();
        }
      }
    }
    afterWrite?.call('snapshot');
    if (!await prefs.remove(key)) {
      throw StateError('Completion journal cleanup failed');
    }
    afterWrite?.call('cleanup');
    return JournalReplayOutcome.applied;
  }

  static String _statusLabel(TripStatus status) => switch (status) {
    TripStatus.completed => WaybillRecord.completed,
    TripStatus.cancelledByRider => 'Cancelled by rider',
    TripStatus.cancelledByDriver => 'Cancelled by driver',
    TripStatus.cancelledByAdmin => 'Cancelled by Movera',
    TripStatus.cancelledBySystem => 'Cancelled by Movera',
    TripStatus.searching ||
    TripStatus.requested => 'Cancelled by driver · reassigned',
    TripStatus.noShow => 'Rider no-show',
    TripStatus.expired => 'Expired',
    TripStatus.failed => 'Failed',
    _ => status.name,
  };
}

/// Fully validated journal entry. Any type or schema problem throws before a
/// single side effect is applied.
class _DecodedJournal {
  _DecodedJournal._(
    this.data,
    this.tripId,
    this.status,
    this.record,
    this.completedAt,
    this.next,
  );

  final Map<String, dynamic> data;
  final String tripId;
  final TripStatus status;
  final Map<String, dynamic> record;
  final DateTime completedAt;
  final PersistedActiveRide? next;

  static _DecodedJournal parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Completion journal is not an object');
    }
    final data = Map<String, dynamic>.from(decoded);
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw FormatException('Unsupported completion journal $schemaVersion');
    }
    final id = data['tripId'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Journal trip ID missing');
    }
    final status = TripStatusWire.parse(data['status'] as String);
    final cancellation = data['cancellation'];
    final releasedByDriver =
        status.isReleasedToDispatch &&
        cancellation is Map &&
        cancellation['actor'] == 'driver';
    if (!status.isTerminal && !releasedByDriver) {
      throw const FormatException('Invalid terminal journal');
    }
    final record = Map<String, dynamic>.from(data['record'] as Map);
    for (final field in ['fare', 'service', 'riderName', 'pickup', 'dropoff']) {
      if (record[field] is! String) {
        throw FormatException('Journal record field $field missing');
      }
    }
    // UTC since driver-r4-14; older journals saved local time.
    final completedAt = DateTime.parse(data['completedAt'] as String).toLocal();
    final nextData = data['next'];
    PersistedActiveRide? next;
    if (nextData != null) {
      next = nextData is Map
          ? PersistedActiveRide.fromJson(Map<String, dynamic>.from(nextData))
          : null;
      if (next == null || next.tripId == id) {
        throw const FormatException('Invalid queued trip');
      }
    }
    return _DecodedJournal._(data, id, status, record, completedAt, next);
  }
}
