import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:movera/core/storage/local_write_session.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/core/storage/local_quarantine.dart';

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
  }) => _serial(() async {
    final prefs = await load();
    // Do not overwrite an earlier unfinished transaction.
    if (prefs.getString(key) != null) {
      await _replay(prefs);
    }
    final terminalAt = DateTime.now();
    final payload = {
      'schemaVersion': 2,
      'tripId': record.tripId,
      'status': status.name,
      'authoritative': authoritative,
      'completedAt': terminalAt.toIso8601String(),
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
      },
      if (cancellationReasonCode != null)
        'cancellation': {
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
    await _serial(() async => outcome = await _replay(await load()));
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
        reason: '$error',
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
          source: 'Local demo',
          driverName: 'Unavailable',
          vehicle: 'Unavailable',
          licensePlate: 'Unavailable',
          passengerCapacity: 0,
        ),
        completedAt: at,
        status: status,
        paymentMethod: row['paymentMethod'] is String
            ? row['paymentMethod'] as String
            : null,
        cashCollected: row['cashCollected'] is String
            ? row['cashCollected'] as String
            : null,
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
    final next = entry.next;
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
    TripStatus.completed => 'Completed',
    TripStatus.cancelledByRider => 'Cancelled by rider',
    TripStatus.cancelledByDriver => 'Cancelled by driver',
    TripStatus.cancelledByAdmin => 'Cancelled by Movera',
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
    final status = TripStatus.values.byName(data['status'] as String);
    if (!status.isTerminal) {
      throw const FormatException('Invalid terminal journal');
    }
    final record = Map<String, dynamic>.from(data['record'] as Map);
    for (final field in ['fare', 'service', 'riderName', 'pickup', 'dropoff']) {
      if (record[field] is! String) {
        throw FormatException('Journal record field $field missing');
      }
    }
    final completedAt = DateTime.parse(data['completedAt'] as String);
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
