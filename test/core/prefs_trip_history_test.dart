import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final waybill = WaybillRecord(
    tripId: 'trip-42',
    statusLabel: 'Current trip',
    issuedAt: DateTime(2026, 9, 29, 9),
    fare: '126,75 kr',
    service: 'Comfort',
    riderName: 'Rider',
    pickup: 'Pickup',
    dropoff: 'Drop-off',
    source: 'Radar',
    driverName: 'Driver',
    vehicle: 'Vehicle',
    licensePlate: 'ABC 123',
    passengerCapacity: 4,
  );

  test(
    'a completed trip survives a repository restart and archives once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = PrefsTripHistoryRepository();
      await first.archive(waybill, completedAt: DateTime(2026, 9, 29, 10));
      await first.archive(waybill, completedAt: DateTime(2026, 9, 29, 11));

      final restarted = PrefsTripHistoryRepository();
      final rows = await restarted.list();
      expect(rows, hasLength(1));
      expect(rows.single.tripId, 'trip-42');
      expect(rows.single.pickup, 'Pickup');
      expect(rows.single.completedAt, DateTime(2026, 9, 29, 10));
      expect(rows.single.tip, '—');
      expect(rows.single.paymentMethod, '—');
    },
  );
  test('known optional trip metadata round-trips without defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PrefsTripHistoryRepository();
    await repo.archive(
      waybill,
      completedAt: DateTime(2026, 9, 29, 10),
      distance: '6.8 km',
      duration: '18 min',
      tip: '20 kr',
      paymentMethod: 'Card',
    );

    final row = (await PrefsTripHistoryRepository().list()).single;
    expect(row.distance, '6.8 km');
    expect(row.duration, '18 min');
    expect(row.tip, '20 kr');
    expect(row.paymentMethod, 'Card');
  });
}
