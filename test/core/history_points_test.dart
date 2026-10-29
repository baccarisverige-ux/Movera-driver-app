import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Contract v0.17.0 §25: a past ride keeps its pickup and drop-off points
/// on this phone, so its map shows the two pins even when the server
/// cannot be asked for the route.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pickup = GeoPoint(59.1955, 17.6253);
  const dropoff = GeoPoint(59.1960, 17.6268);
  WaybillRecord receipt(String id) => WaybillRecord(
    tripId: id,
    statusLabel: 'Current trip',
    issuedAt: DateTime(2026, 10, 29, 12),
    fare: '68,64 kr',
    service: 'Premium',
    riderName: 'Rider',
    pickup: 'Klockarvägen 37',
    dropoff: 'Södertälje centrum',
    source: 'Movera Radar',
    driverName: 'Driver',
    vehicle: 'Car',
    licensePlate: 'ABC 123',
    passengerCapacity: 4,
  );

  setUp(() async {
    await PrefsTripHistoryRepository.settle();
    await CompletionJournal.settle();
    SharedPreferences.setMockInitialValues({});
  });

  test('the journal hands the points to History', () async {
    final history = PrefsTripHistoryRepository();
    await CompletionJournal(
      active: MemoryActiveRideRepository(),
      history: history,
    ).finish(receipt('trp_pins'), pickupPoint: pickup, dropoffPoint: dropoff);
    final row = (await history.list()).single;
    expect(row.pickupPoint, pickup);
    expect(row.dropoffPoint, dropoff);
  });

  test('an older row, or one with a bad point, has none', () async {
    final history = PrefsTripHistoryRepository();
    await history.archive(receipt('trp_old'));
    expect((await history.list()).single.pickupPoint, isNull);
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(PrefsTripHistoryRepository.key)!)
            as Map<String, dynamic>;
    final row = (stored['rows'] as List).single as Map<String, dynamic>;
    row['pickupLat'] = 120;
    row['pickupLng'] = 18;
    row['dropoffLat'] = 'x';
    await prefs.setString(PrefsTripHistoryRepository.key, jsonEncode(stored));
    final read = (await history.list()).single;
    expect(read.pickupPoint, isNull);
    expect(read.dropoffPoint, isNull);
    expect(
      PrefsTripHistoryRepository.pointOf(59.3, 18.0),
      const GeoPoint(59.3, 18.0),
    );
  });
}
