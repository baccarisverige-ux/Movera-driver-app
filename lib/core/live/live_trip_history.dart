import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/money/money.dart';

/// One page of `GET /driver/trips` (contract v0.18.124
/// `DriverTripHistoryPage`): the rows and the opaque next cursor (null on
/// the last page).
class DriverTripHistoryPage {
  const DriverTripHistoryPage({required this.items, this.nextCursor});

  final List<TripHistoryRecord> items;
  final String? nextCursor;
}

/// D18 (contract v0.18.124 C10 `driverTripHistory`; owner G11 Q10 "Load
/// from server (Recommended)", Rules decisions/driver-g11.md): the
/// driver's ride history from the server, so a reinstall or a new phone
/// shows the same trips. The phone copy ([PrefsTripHistoryRepository]) is
/// only for offline: [merge] lets the server rows win by tripId.
class LiveTripHistory {
  LiveTripHistory({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/driver/trips';

  /// Contract default page size (limit 1-50).
  static const pageSize = 20;

  /// One page, newest first. [from] / [to] (instants, sent in UTC) bound
  /// the trips' createdAt (D18b: any past month). Throws when the server
  /// could not answer.
  Future<DriverTripHistoryPage> page({
    String? cursor,
    int limit = pageSize,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = [
      'limit=$limit',
      if (cursor != null) 'cursor=${Uri.encodeQueryComponent(cursor)}',
      if (from != null)
        'from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}',
      if (to != null)
        'to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}',
    ].join('&');
    final body = await _api.get('$path?$query');
    final items = body['items'];
    return DriverTripHistoryPage(
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map<String, dynamic>) recordOf(item),
      ],
      nextCursor: body['nextCursor'] as String?,
    );
  }

  /// A `DriverTripHistoryItem` as the History row. The money is the
  /// server's `earned` (the trip's earnings entries, the same sum as
  /// `GET /driver/earnings`), never the rider's fare.
  static TripHistoryRecord recordOf(Map<String, dynamic> json) {
    final status =
        TripStatusWire.tryParse(json['status'] as String?) ??
        TripStatus.completed;
    final earnedJson = json['earned'];
    final earned = earnedJson is Map<String, dynamic>
        ? Money.fromJson(earnedJson)
        : null;
    final cashJson = json['cashCollected'];
    final cash = cashJson is Map<String, dynamic>
        ? Money.fromJson(cashJson)
        : null;
    final pickup = json['pickup'];
    final dropoff = json['dropoff'];
    final rider = json['rider'];
    final cancellation = json['cancellation'];
    final ended = DateTime.tryParse(
      '${json['endedAt'] ?? json['updatedAt'] ?? ''}',
    )?.toLocal();
    final meters = json['distanceMeters'];
    String address(Object? place) =>
        place is Map ? '${place['address'] ?? '—'}' : '—';
    return TripHistoryRecord(
      tripId: '${json['tripId']}',
      riderName: rider is Map ? '${rider['firstName'] ?? '—'}' : '—',
      whenLabel: '',
      pickup: address(pickup),
      dropoff: address(dropoff),
      fare: status == TripStatus.completed ? (earned?.formatted ?? '—') : '—',
      fareMinorUnits: status == TripStatus.completed
          ? earned?.minorUnits
          : null,
      feeEarned: status == TripStatus.completed ? null : earned?.formatted,
      category: CategoryCatalog.labelOf('${json['categoryId'] ?? ''}'),
      distance: meters is num ? driverDistanceMeters(meters.toDouble()) : '—',
      paymentMethod: '${json['paymentMethod'] ?? '—'}',
      completedAt: ended,
      status: status,
      cashCollected: cash?.formatted,
      cancellationActor: cancellation is Map
          ? cancellation['actor'] as String?
          : null,
      cancellationReasonCode: cancellation is Map
          ? cancellation['reasonCode'] as String?
          : null,
      pickupPoint: pickup is Map
          ? PrefsTripHistoryRepository.pointOf(pickup['lat'], pickup['lng'])
          : null,
      dropoffPoint: dropoff is Map
          ? PrefsTripHistoryRepository.pointOf(dropoff['lat'], dropoff['lng'])
          : null,
    );
  }

  /// The server rows, plus the phone rows the server did not send (no
  /// network yet, or older than the pages read), newest first. A trip on
  /// both shows the server's row.
  static List<TripHistoryRecord> merge({
    required List<TripHistoryRecord> server,
    required List<TripHistoryRecord> phone,
  }) {
    final ids = {for (final r in server) r.tripId};
    final all = [
      ...server,
      for (final r in phone)
        if (!ids.contains(r.tripId)) r,
    ];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    all.sort(
      (a, b) => (b.completedAt ?? epoch).compareTo(a.completedAt ?? epoch),
    );
    return all;
  }
}
