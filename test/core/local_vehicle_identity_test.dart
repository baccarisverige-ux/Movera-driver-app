import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _vehicle(String id) => {
  'id': id,
  'make': 'Volvo',
  'model': id,
  'year': '2024',
  'plate': id.toUpperCase(),
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'saving primary vehicle photos preserves Profile and waybill identity',
    () async {
      final store = LocalVehicleStore();
      await store.upsert(_vehicle('second'));
      final before = await store.primaryIdentity();
      final primary = (await store.list()).first;
      await LocalVehicleStore().upsert({
        ...primary,
        'registrationPhoto': 'AQID',
      });
      final restored = LocalVehicleStore();
      expect(await restored.primaryIdentity(), before);
      final rows = await restored.list();
      expect(rows.map((r) => r['id']), [
        LocalVehicleStore.demo['id'],
        'second',
      ]);
      expect(rows.first['registrationPhoto'], 'AQID');
      expect(rows.last['plate'], 'SECOND');
    },
  );

  test(
    'updating a secondary vehicle preserves its position and other rows',
    () async {
      final store = LocalVehicleStore();
      await store.upsert(_vehicle('second'));
      await store.upsert(_vehicle('third'));
      await store.upsert({
        ..._vehicle('second'),
        'model': 'XC60',
        'insurancePhoto': 'AQID',
      });
      final rows = await LocalVehicleStore().list();
      expect(rows.map((r) => r['id']), [
        LocalVehicleStore.demo['id'],
        'second',
        'third',
      ]);
      expect(rows[1]['model'], 'XC60');
      expect(rows[1]['insurancePhoto'], 'AQID');
      expect(rows[2]['model'], 'third');
      expect(await store.primaryIdentity(), (
        vehicle: 'Mercedes-Benz E 220',
        plate: 'MVR 418',
      ));
    },
  );
  test('single photo budget accepts its exact decoded limit and rejects one byte more', () async {
    final store = LocalVehicleStore();
    final atLimit = base64Encode(Uint8List(LocalVehicleStore.maxPhotoBytes));
    await store.upsert({
      ...LocalVehicleStore.demo,
      'registrationPhoto': atLimit,
    });
    expect((await store.list()).first['registrationPhoto'], atLimit);
    await expectLater(
      store.upsert({
        ...LocalVehicleStore.demo,
        'registrationPhoto': base64Encode(
          Uint8List(LocalVehicleStore.maxPhotoBytes + 1),
        ),
      }),
      throwsA(isA<VehiclePhotoBudgetExceeded>()),
    );
    expect((await store.list()).first['registrationPhoto'], atLimit);
  });

  test('combined photo budget uses decoded bytes at its exact limit', () async {
    final store = LocalVehicleStore();
    final large = base64Encode(Uint8List(LocalVehicleStore.maxPhotoBytes));
    final remaining =
        LocalVehicleStore.maxStoredPhotoBytes -
        2 * LocalVehicleStore.maxPhotoBytes;
    await store.upsert({...LocalVehicleStore.demo, 'registrationPhoto': large});
    await store.upsert({..._vehicle('second'), 'registrationPhoto': large});
    final thirdPhoto = base64Encode(Uint8List(remaining));
    await store.upsert({..._vehicle('third'), 'insurancePhoto': thirdPhoto});
    await expectLater(
      store.upsert({
        ..._vehicle('third'),
        'insurancePhoto': base64Encode(Uint8List(remaining + 1)),
      }),
      throwsA(isA<VehiclePhotoBudgetExceeded>()),
    );
    final rows = await store.list();
    expect(rows, hasLength(3));
    expect(rows.last['insurancePhoto'], thirdPhoto);
    expect(rows.first['registrationPhoto'], large);
  });
}
