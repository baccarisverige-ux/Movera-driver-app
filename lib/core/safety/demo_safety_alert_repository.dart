import 'dart:async';

import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';

/// One step in the demo outbox: an alert sent or updated.
class SafetyAlertJournalEntry {
  const SafetyAlertJournalEntry(this.kind, this.alert, this.at);

  /// "sent" or "updated".
  final String kind;
  final SafetyAlert alert;
  final DateTime at;
}

/// Frontend/demo safety alerts. No backend: alerts are kept in memory and in
/// a journal so the demo and the tests can see what admin and Dispatch would
/// receive. A backend implementation replaces this class.
class DemoSafetyAlertRepository implements SafetyAlertRepository {
  DemoSafetyAlertRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<String, SafetyAlert> _alerts = <String, SafetyAlert>{};
  final List<SafetyAlertJournalEntry> _journal = <SafetyAlertJournalEntry>[];
  final StreamController<List<SafetyAlert>> _changes =
      StreamController<List<SafetyAlert>>.broadcast();
  int _sequence = 0;
  bool _disposed = false;

  /// Alerts as admin and Dispatch see them, oldest first.
  List<SafetyAlert> get alerts => List<SafetyAlert>.unmodifiable(_alerts.values);

  /// Every send and update, in order.
  List<SafetyAlertJournalEntry> get journal =>
      List<SafetyAlertJournalEntry>.unmodifiable(_journal);

  Stream<List<SafetyAlert>> watch() => _changes.stream;

  @override
  Future<SafetyAlert> send({
    required SafetyAlertTrip trip,
    required RideCheckTrigger trigger,
    required String reason,
    required String topic,
    required List<RideCheckAnswer> answers,
  }) async {
    _check();
    final at = _now();
    final alert = SafetyAlert(
      id: 'alert-${trip.tripId}-${++_sequence}',
      trip: trip,
      trigger: trigger,
      reason: reason,
      topic: topic,
      answers: List<RideCheckAnswer>.unmodifiable(answers),
      sentAt: at,
      updatedAt: at,
    );
    _alerts[alert.id] = alert;
    _record('sent', alert, at);
    return alert;
  }

  @override
  Future<SafetyAlert> update(String alertId, RideCheckAnswer answer) async {
    _check();
    final current = _alerts[alertId];
    if (current == null) {
      throw StateError('Unknown safety alert $alertId');
    }
    final next = current.withAnswer(answer);
    _alerts[alertId] = next;
    _record('updated', next, answer.at);
    return next;
  }

  void _record(String kind, SafetyAlert alert, DateTime at) {
    _journal.add(SafetyAlertJournalEntry(kind, alert, at));
    if (!_changes.isClosed) _changes.add(alerts);
  }

  void _check() {
    if (_disposed) throw StateError('Safety alerts are closed');
  }

  /// Logout: a new driver session starts with an empty outbox.
  void reset() {
    _alerts.clear();
    _journal.clear();
    _sequence = 0;
    if (!_changes.isClosed) _changes.add(alerts);
  }

  void dispose() {
    _disposed = true;
    _changes.close();
  }
}
