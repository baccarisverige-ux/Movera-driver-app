import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

WaybillRecord receipt(String id) => WaybillRecord(
  tripId: id,
  statusLabel: 'Completed',
  issuedAt: DateTime(2026),
  fare: '10 kr',
  service: 'Demo',
  riderName: 'Rider',
  pickup: 'P',
  dropoff: 'D',
  source: 'Demo',
  driverName: 'Driver',
  vehicle: 'Car',
  licensePlate: 'ABC',
  passengerCapacity: 4,
);
Map<String, dynamic> vehicle(String id) => {
  'id': id,
  'make': 'Volvo',
  'model': 'XC60',
  'year': '2024',
  'plate': 'ABC 123',
};
Map<String, dynamic> historyRow(String id, DateTime at) => {
  'tripId': id,
  'riderName': 'Rider',
  'whenLabel': 'Today',
  'pickup': 'P',
  'dropoff': 'D',
  'fare': '10 kr',
  'category': 'Demo',
  'status': 'completed',
  'completedAt': at.toIso8601String(),
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    await SettingsRepository.settle();
    await LocalSupportRepository.settle();
    await PrefsTripHistoryRepository.settle();
    SharedPreferences.setMockInitialValues({});
  });
  test('R01 support captures nested data before queued save', () async {
    final gate = Completer<SharedPreferences>();
    final repo = LocalSupportRepository(load: () => gate.future);
    final first = repo.update('draft', {'subject': 'old'});
    final value = [
      {
        'subject': 'original',
        'preview': 'p',
        'messages': [
          {'text': 'original'},
        ],
      },
    ];
    final second = repo.update('tickets', value);
    value.first['subject'] = 'edited';
    (value.first['messages'] as List).first['text'] = 'edited';
    gate.complete(await SharedPreferences.getInstance());
    await first;
    await second;
    final data = await repo.read();
    expect(data['tickets'][0]['subject'], 'original');
    expect(data['tickets'][0]['messages'][0]['text'], 'original');
  });
  test('R02 vehicle captures edit before waiting for storage', () async {
    final gate = Completer<SharedPreferences>();
    final blocker = SettingsRepository(load: () => gate.future)
        .save('blocker', {});
    final data = vehicle('new');
    final pending = LocalVehicleStore().upsert(data);
    data['plate'] = 'CHANGED';
    gate.complete(await SharedPreferences.getInstance());
    await blocker;
    await pending;
    expect((await LocalVehicleStore().list()).last['plate'], 'ABC 123');
  });
  test(
    'R03 departing support session cannot read newly loaded user data',
    () async {
      final gate = Completer<SharedPreferences>();
      final repo = LocalSupportRepository(load: () => gate.future);
      final pending = repo.read();
      final check = expectLater(pending, throwsStateError);
      LocalWriteSession.beginCleanup();
      LocalWriteSession.endCleanup();
      gate.complete(await SharedPreferences.getInstance());
      await check;
    },
  );
  test(
    'R04 departing history session cannot read newly loaded receipts',
    () async {
      final gate = Completer<SharedPreferences>();
      final repo = PrefsTripHistoryRepository(load: () => gate.future);
      final pending = repo.list();
      final check = expectLater(pending, throwsStateError);
      LocalWriteSession.beginCleanup();
      LocalWriteSession.endCleanup();
      gate.complete(await SharedPreferences.getInstance());
      await check;
    },
  );
  test('R05 history rejects ongoing trips on write and restore', () async {
    final repo = PrefsTripHistoryRepository();
    await expectLater(
      repo.archive(receipt('active'), status: TripStatus.accepted),
      throwsArgumentError,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      PrefsTripHistoryRepository.key,
      jsonEncode({
        'schemaVersion': 1,
        'rows': [
          {...historyRow('active', DateTime(2026)), 'status': 'accepted'},
        ],
      }),
    );
    expect(await repo.list(), isEmpty);
  });
  test(
    'R06 blank trip IDs never produce unreadable history receipts',
    () async {
      final repo = PrefsTripHistoryRepository();
      await expectLater(repo.archive(receipt('   ')), throwsArgumentError);
      expect(await repo.list(), isEmpty);
    },
  );
  test(
    'R07 old backfilled receipt does not evict a newer one at capacity',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final rows = List.generate(
        PrefsTripHistoryRepository.maxReceipts,
        (i) => historyRow('ride-$i', DateTime(2026).add(Duration(minutes: i))),
      );
      await prefs.setString(
        PrefsTripHistoryRepository.key,
        jsonEncode({'schemaVersion': 1, 'rows': rows}),
      );
      final repo = PrefsTripHistoryRepository();
      await repo.archive(receipt('backfill'), completedAt: DateTime(2020));
      final restored = await repo.list();
      expect(restored, hasLength(PrefsTripHistoryRepository.maxReceipts));
      expect(restored.any((r) => r.tripId == 'backfill'), isFalse);
      expect(restored.any((r) => r.tripId == 'ride-0'), isTrue);
    },
  );

  test('R29 legacy duplicate receipts restore the newest version regardless of order', () async {
    final prefs = await SharedPreferences.getInstance();
    final old = {...historyRow('same', DateTime(2020)), 'fare': '10 kr'};
    final recent = {...historyRow('same', DateTime(2026)), 'fare': '20 kr'};
    for (final rows in [
      [old, recent],
      [recent, old],
    ]) {
      await prefs.setString(
        PrefsTripHistoryRepository.key,
        jsonEncode({'schemaVersion': 1, 'rows': rows}),
      );
      final restored = await PrefsTripHistoryRepository().list();
      expect(restored, hasLength(1));
      expect(restored.single.fare, '20 kr');
      expect(restored.single.completedAt, DateTime(2026));
    }
  });
}
