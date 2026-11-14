import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BQ-F2c (Rules audits/impact/f2-driver-leave-now-supervisor.md follow-up
/// 2): a completed trip keeps its exact `fareMinorUnits` in its own
/// currency. The write read the fare as SEK only, so a TN ("12.350 DT") or
/// FR ("24,50 €") trip lost it.
WaybillRecord _record(String tripId, String fare) => WaybillRecord(
  tripId: tripId,
  statusLabel: WaybillRecord.currentTrip,
  issuedAt: DateTime(2026, 11, 14, 12),
  fare: fare,
  service: 'Movera',
  riderName: 'Sara',
  pickup: 'A',
  dropoff: 'B',
  source: WaybillRecord.moveraRadarSource,
  driverName: WaybillRecord.demoDriverName,
  vehicle: WaybillRecord.vehicleUnavailable,
  licensePlate: WaybillRecord.plateUnavailable,
  passengerCapacity: 4,
);

Future<Map<String, Object?>> _stored(String tripId) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = jsonDecode(prefs.getString(PrefsTripHistoryRepository.key)!);
  final rows = (raw is Map ? raw['rows'] ?? raw['trips'] : raw) as List;
  return Map<String, Object?>.from(
    rows.cast<Map>().firstWhere((row) => row['tripId'] == tripId),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Money.forgetZone);

  test('TND: 12.350 DT is kept as 12350 minor units', () async {
    Money.zoneCurrency = 'TND';
    final repo = PrefsTripHistoryRepository();
    await repo.archive(_record('tnd-trip', '12.350 DT'));
    expect((await _stored('tnd-trip'))['fareMinorUnits'], 12350);
    final row = (await repo.list()).single;
    expect(row.fareMinorUnits, 12350);
    expect(row.fareMoney, const Money(minorUnits: 12350, currency: 'TND'));
  });

  test('SEK: 224,50 kr is still kept as 22450 minor units', () async {
    final repo = PrefsTripHistoryRepository();
    await repo.archive(_record('sek-trip', '224,50 kr'));
    expect((await _stored('sek-trip'))['fareMinorUnits'], 22450);
    expect(
      (await repo.list()).single.fareMoney,
      const Money(minorUnits: 22450, currency: 'SEK'),
    );
  });

  test('EUR: 24,50 € is kept as 2450 minor units', () async {
    Money.zoneCurrency = 'EUR';
    final repo = PrefsTripHistoryRepository();
    await repo.archive(_record('eur-trip', '24,50 €'));
    expect((await _stored('eur-trip'))['fareMinorUnits'], 2450);
  });
}
