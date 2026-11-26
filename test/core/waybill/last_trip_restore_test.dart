import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/waybill/last_trip_restore.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Owner 2026-11-26 ("Why cant see last trip (amount in island)"; "Ok").
Map<String, dynamic> item({
  required String id,
  int total = 10480,
  String status = 'completed',
  String payment = 'cash',
  bool finish = true,
  String? endedBy,
}) => {
  'tripId': id,
  'status': status,
  'paymentMethod': payment,
  'updatedAt': '2026-11-26T19:47:30Z',
  'driverTotal': {'amountMinor': total, 'currency': 'SEK'},
  if (finish)
    'finish': {
      'endedEarly': endedBy != null,
      'endedBy': ?endedBy,
      'total': {'amountMinor': 12000, 'currency': 'SEK'},
      'cashToCollect': {'amountMinor': 12000, 'currency': 'SEK'},
      'driverTotal': {'amountMinor': total, 'currency': 'SEK'},
    },
};

WaybillRecord done(String id, String fare) => WaybillRecord(
  tripId: id,
  statusLabel: WaybillRecord.completed,
  issuedAt: DateTime.now(),
  fare: fare,
  service: 'Movera',
  riderName: 'A',
  pickup: 'P',
  dropoff: 'D',
  source: 'live',
  driverName: 'D',
  vehicle: 'V',
  licensePlate: 'ABC123',
  passengerCapacity: 4,
);

void main() {
  final repo = InMemoryWaybillRepository.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LastTripRestore.resetForTesting();
    repo.reset();
  });

  test(
    'restart: the server newest finished pay-in-car trip fills the island',
    () async {
      LastTripRestore.readTrips = () async => {
        'items': [item(id: 't1')],
      };
      await LastTripRestore.restore(repo);
      expect(repo.last?.tripId, 't1');
      expect(repo.last?.fare, contains('104,80'));
      expect(repo.last?.paidByCash, isTrue);
    },
  );

  test('restart offline: the phone copy is shown', () async {
    LastTripRestore.watch(repo);
    repo.beginCurrent(done('t2', '88,00 kr'));
    repo.completeCurrent();
    await pumpEventQueue();
    // The app restarted: memory is empty, the phone copy is kept.
    final saved = (await SharedPreferences.getInstance()).getString(
      LastTripRestore.prefsKey,
    );
    expect(saved, isNotNull);
    SharedPreferences.setMockInitialValues({LastTripRestore.prefsKey: saved!});
    repo.setLastForTesting(null);
    await pumpEventQueue();
    SharedPreferences.setMockInitialValues({LastTripRestore.prefsKey: saved});
    LastTripRestore.resetForTesting();
    LastTripRestore.readTrips = () async => throw Exception('offline');
    await LastTripRestore.restore(repo);
    expect(repo.last?.tripId, 't2');
    expect(repo.last?.fare, '88,00 kr');
  });

  test('no finished trip: nothing restored (the island shows "—")', () async {
    LastTripRestore.readTrips = () async => {
      'items': [item(id: 'c1', status: 'cancelled_by_rider', finish: false)],
    };
    await LastTripRestore.restore(repo);
    expect(repo.last, isNull);
  });

  test('a rider early end with the rider on board counts', () async {
    LastTripRestore.readTrips = () async => {
      'items': [
        item(id: 'c0', status: 'cancelled_by_driver', finish: false),
        item(
          id: 'e1',
          status: 'cancelled_by_rider',
          endedBy: 'rider',
          total: 5000,
        ),
      ],
    };
    await LastTripRestore.restore(repo);
    expect(repo.last?.tripId, 'e1');
    expect(repo.last?.fare, contains('50'));
  });

  test('a trip finished on this run is never replaced', () async {
    repo.beginCurrent(done('new', '99,00 kr'));
    repo.completeCurrent();
    LastTripRestore.readTrips = () async => {
      'items': [item(id: 'old')],
    };
    await LastTripRestore.restore(repo);
    expect(repo.last?.tripId, 'new');
  });

  test(
    'the server final money replaces the phone copy of the same trip',
    () async {
      SharedPreferences.setMockInitialValues({
        LastTripRestore.prefsKey:
            '{"tripId":"t3","fare":"10,00 kr","issuedAt":"2026-11-26T19:00:00Z","paidByCash":true}',
      });
      LastTripRestore.readTrips = () async => {
        'items': [item(id: 't3', total: 2000)],
      };
      await LastTripRestore.restore(repo);
      expect(repo.last?.tripId, 't3');
      expect(repo.last?.fare, contains('20'));
    },
  );
}
