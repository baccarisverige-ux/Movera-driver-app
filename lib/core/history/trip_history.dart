import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';

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
  /// The rider paid cash in the car (Q23).
  bool get paidByCash => paymentMethod.trim().toLowerCase() == 'cash';

  /// On a completed cash trip: what the driver owes Movera, its fee on the
  /// fare. It is taken from the next payout. Null otherwise.
  String? get owedToMovera => paidByCash && status == TripStatus.completed
      ? WaybillPayment.fromFare(fare)?.serviceFee
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
