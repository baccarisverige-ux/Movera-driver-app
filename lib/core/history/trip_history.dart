import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/earnings/cash_balance.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';

/// A stored payment method as the driver reads it: 'Cash' and 'Card'
/// (kept in English) in the driver's language, anything else (a method
/// name such as Swish, or '—') as stored (driver-u155).
String paymentMethodText(String? method) =>
    switch (method?.trim().toLowerCase()) {
      'cash' => tr.cash,
      'card' => tr.paymentCard,
      null || '' => '—',
      _ => method!.trim(),
    };

/// Completed-trip projection for History (D7).
///
/// Distinct from [WaybillRecord]: a waybill is the live/queued slip, history
/// is the finished row. Screens bind this record instead of dummy copy.
class TripHistoryRecord {
  const TripHistoryRecord({
    required this.tripId,
    required this.riderName,
    required this.whenLabel,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.category,
    this.distance = '—',
    this.duration = '—',
    this.tip = '—',
    this.paymentMethod = '—',
    this.completedAt,
    this.status = TripStatus.completed,
    this.fareMinorUnits,
    this.cancellationActor,
    this.cancellationReasonCode,
    this.cashCollected,
    this.driverBonus,
  });

  final String tripId;
  final String riderName;
  final String whenLabel;
  final String pickup;
  final String dropoff;
  final String fare;
  final String category;
  final String distance;
  final String duration;
  final String tip;
  final String paymentMethod;
  final DateTime? completedAt;
  final TripStatus status;
  final int? fareMinorUnits;
  final String? cancellationActor;
  final String? cancellationReasonCode;

  /// R8-4: the cash taken from the rider, e.g. "250 kr"; it can differ
  /// from [fare] (rider promotions). Null when not recorded: an older
  /// cash trip then counts as its fare.
  final String? cashCollected;

  /// Q16/Q18: Movera's bonus already in [fare], e.g. "40 kr"; null for
  /// none. Shown as "incl. +40 kr Movera bonus".
  final String? driverBonus;

  /// The rider paid cash in the car (Q23).
  bool get paidByCash => paymentMethod.trim().toLowerCase() == 'cash';

  /// On a completed cash trip: fare − cash collected, owed by (−) or to
  /// (+) the driver. Null otherwise.
  CashBalance? get cashBalance => paidByCash && status == TripStatus.completed
      ? CashBalance.fromLabels(fare: fare, cashCollected: cashCollected ?? fare)
      : null;

  Money? get fareMoney => status != TripStatus.completed
      ? null
      : fareMinorUnits == null
      ? Money.parseSekLabel(fare)
      : Money.ore(fareMinorUnits!);
}

abstract interface class TripHistoryRepository {
  List<TripHistoryRecord> list();

  TripHistoryRecord? byTripId(String tripId);
}

class MemoryTripHistoryRepository implements TripHistoryRepository {
  MemoryTripHistoryRepository({List<TripHistoryRecord>? seed})
    : _rows = List<TripHistoryRecord>.from(seed ?? stockholmSeed);

  final List<TripHistoryRecord> _rows;

  static const stockholmSeed = <TripHistoryRecord>[
    TripHistoryRecord(
      tripId: 'ride-001',
      riderName: 'Angelica Holm',
      whenLabel: 'Today, 14:42',
      pickup: 'Central Station',
      dropoff: 'Södermalm',
      fare: '126 kr',
      category: 'Comfort',
      distance: '6.8 km',
      duration: '18 min',
    ),
    TripHistoryRecord(
      tripId: 'ride-002',
      riderName: 'Maya Lind',
      whenLabel: 'Today, 12:18',
      pickup: 'Vasastan',
      dropoff: 'Solna centrum',
      fare: '94 kr',
      category: 'Movera',
      distance: '8.1 km',
      duration: '22 min',
    ),
  ];

  @override
  List<TripHistoryRecord> list() => List<TripHistoryRecord>.unmodifiable(_rows);

  @override
  TripHistoryRecord? byTripId(String tripId) {
    for (final row in _rows) {
      if (row.tripId == tripId) {
        return row;
      }
    }
    return null;
  }
}
