import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

WaybillRecord _waybill(String id) => WaybillRecord(
  tripId: id,
  statusLabel: 'Current trip',
  issuedAt: DateTime(2026, 10, 9),
  fare: '100 kr',
  service: 'Movera',
  riderName: 'Demo rider',
  pickup: 'Pickup',
  dropoff: 'Dropoff',
  source: 'Local demo',
  driverName: 'Driver',
  vehicle: 'Vehicle',
  licensePlate: 'ABC123',
  passengerCapacity: 4,
);

Map<String, dynamic> _vehicle(String id) => {
  'id': id,
  'make': 'Volvo',
  'model': 'XC60',
  'year': '2024',
  'plate': 'ABC123',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WaybillStore.reset();
  });

  tearDown(WaybillStore.reset);

  test('same-microsecond quarantines preserve both raw payloads', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 10, 9);
    final first = await LocalQuarantine.store(
      prefs,
      source: 'history',
      raw: 'first',
      reason: 'bad',
      now: now,
    );
    final second = await LocalQuarantine.store(
      prefs,
      source: 'history',
      raw: 'second',
      reason: 'bad',
      now: now,
    );
    expect(first, isNot(second));
    final raws = [
      first,
      second,
    ].map((key) => (jsonDecode(prefs.getString(key)!) as Map)['raw']).toSet();
    expect(raws, {'first', 'second'});
  });

  test('invalid vehicle identity cannot poison future reads', () async {
    final store = LocalVehicleStore();
    await expectLater(
      store.upsert({..._vehicle('car-1'), 'year': 2024}),
      throwsA(isA<FormatException>()),
    );
    expect((await store.list()).single['id'], LocalVehicleStore.demo['id']);
    await store.upsert(_vehicle('valid'));
    expect((await store.list()).last['id'], 'valid');
  });

  test('malformed vehicle photo cannot poison future reads', () async {
    final store = LocalVehicleStore();
    await expectLater(
      store.upsert({..._vehicle('car-1'), 'registrationPhoto': 'not@base64'}),
      throwsA(isA<FormatException>()),
    );
    expect((await store.list()).single['id'], LocalVehicleStore.demo['id']);
    await store.upsert({..._vehicle('car-1'), 'registrationPhoto': 'AQID'});
    expect((await store.list()).last['registrationPhoto'], 'AQID');
  });

  test(
    'removing an unknown vehicle does not persist the demo fallback',
    () async {
      final store = LocalVehicleStore();
      final prefs = await SharedPreferences.getInstance();
      final before = LocalVehicleStore.changes.value;
      await store.remove('not-present');
      expect(LocalVehicleStore.changes.value, before);
      expect(prefs.getKeys().where((k) => k.contains('vehicles')), isEmpty);
    },
  );

  test('stale current waybill cannot overwrite a different active trip', () {
    final repo = InMemoryWaybillRepository.instance;
    final active = _waybill('A');
    repo.beginCurrent(active);
    repo.beginCurrent(_waybill('B'));
    expect(identical(repo.current, active), isTrue);
    repo.completeCurrent();
    repo.beginCurrent(_waybill('B'));
    expect(repo.current?.tripId, 'B');
  });

  test(
    'secured next waybill requires an explicit clear before replacement',
    () {
      final repo = InMemoryWaybillRepository.instance;
      repo.secureNext(_waybill('next-A'));
      repo.secureNext(_waybill('next-B'));
      expect(repo.next?.tripId, 'next-A');
      repo.clearNext();
      repo.secureNext(_waybill('next-B'));
      expect(repo.next?.tripId, 'next-B');
    },
  );
}
