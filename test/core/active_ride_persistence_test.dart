import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active ride snapshot round-trips JSON and keeps next trip', () async {
    final original = PersistedActiveRide(
      tripId: 'nearby-1',
      stage: ActiveRideStage.onTrip,
      savedAt: DateTime.now(),
      riderName: 'Angelica',
      fare: '104,80 kr',
      category: 'Comfort',
      matchedVia: 'Movera Radar',
      pickupAddress: 'Kungsgatan 42, Stockholm',
      pickupArea: 'Stockholm',
      dropoffAddress: 'Hornstull, Stockholm',
      stopAddresses: const <String>[
        'Vasagatan 10, Stockholm',
        'Liljeholmen, Stockholm',
      ],
      stopPoints: const <GeoPoint>[
        GeoPoint(59.3300, 18.0580),
        GeoPoint(59.3100, 18.0220),
      ],
      pickupLat: 59.3343,
      pickupLng: 18.0615,
      dropoffLat: 59.3157,
      dropoffLng: 18.0335,
      waitSeconds: 12,
      stopIndex: 1,
      paidStopWait: true,
      startedAt: DateTime.utc(2026, 9, 29, 12),
      next: const PersistedQueuedTrip(
        tripId: 'on-trip-radar-demo-1',
        riderName: 'Maya',
        fare: '128,40 kr',
        category: 'Comfort',
        pickup: 'Vasagatan 10, Stockholm',
        dropoff: 'Södermalm, Stockholm',
        pickupLat: 59.3328,
        pickupLng: 18.0587,
        dropoffLat: 59.3142,
        dropoffLng: 18.0735,
      ),
    );

    final decoded = PersistedActiveRide.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(original.toJson())) as Map,
      ),
    );

    expect(decoded, isNotNull);
    expect(decoded!.tripId, 'nearby-1');
    expect(decoded.stage, ActiveRideStage.onTrip);
    expect(decoded.isFresh, isTrue);
    expect(decoded.riderName, 'Angelica');
    expect(decoded.pickupLat, 59.3343);
    expect(decoded.stopAddresses, <String>[
      'Vasagatan 10, Stockholm',
      'Liljeholmen, Stockholm',
    ]);
    expect(decoded.next?.tripId, 'on-trip-radar-demo-1');
    expect(decoded.next?.riderName, 'Maya');
    expect(decoded.stopIndex, 1);
    expect(decoded.paidStopWait, isTrue);
    expect(decoded.startedAt!.toUtc(), DateTime.utc(2026, 9, 29, 12));
    expect(decoded.stopPoints, const <GeoPoint>[
      GeoPoint(59.3300, 18.0580),
      GeoPoint(59.3100, 18.0220),
    ]);
  });

  test('stale snapshots older than six hours are not fresh', () async {
    final stale = PersistedActiveRide(
      tripId: 'old-1',
      stage: ActiveRideStage.headingToPickup,
      savedAt: DateTime.now().subtract(const Duration(hours: 7)),
    );
    expect(stale.isFresh, isFalse);

    final live = PersistedActiveRide(
      tripId: 'live-1',
      stage: ActiveRideStage.waitingForRider,
      savedAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
    expect(live.isFresh, isTrue);
  });

  test(
    'prefs repository restores a fresh ride and drops a stale one',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsActiveRideRepository();

      await store.save(
        const PersistedActiveRide(
          tripId: 'trip-live',
          stage: ActiveRideStage.waitingForRider,
          riderName: 'Angelica',
          pickupAddress: 'Kungsgatan 42, Stockholm',
          dropoffAddress: 'Hornstull, Stockholm',
        ),
      );

      final restored = await store.read();
      expect(restored, isNotNull);
      expect(restored!.tripId, 'trip-live');
      expect(restored.stage, ActiveRideStage.waitingForRider);
      expect(restored.savedAt, isNotNull);
    },
  );

  test('prefs repository retains stale snapshot for recovery', () async {
    SharedPreferences.setMockInitialValues({
      PrefsActiveRideRepository.key: jsonEncode(
        PersistedActiveRide(
          tripId: 'trip-stale',
          stage: ActiveRideStage.onTrip,
          savedAt: DateTime.now().subtract(const Duration(hours: 8)),
        ).toJson(),
      ),
    });
    final staleStore = PrefsActiveRideRepository();
    expect((await staleStore.read())?.tripId, 'trip-stale');
  });

  test(
    'clear wins over an in-flight save so a cancelled trip cannot revive',
    () async {
      SharedPreferences.setMockInitialValues({});
      // Only the save's storage load waits, so the save is still in flight
      // when clear() is called.
      final saveGate = Completer<SharedPreferences>();
      var loads = 0;
      final store = PrefsActiveRideRepository(
        load: () =>
            loads++ == 0 ? saveGate.future : SharedPreferences.getInstance(),
      );
      final save = store.save(
        const PersistedActiveRide(
          tripId: 'trip-cancel',
          stage: ActiveRideStage.headingToPickup,
        ),
      );
      final clear = store.clear();
      saveGate.complete(await SharedPreferences.getInstance());
      await Future.wait([save, clear]);
      expect(await store.read(), isNull);
    },
  );

  test('a previous trip clear cannot delete a newly accepted trip', () async {
    SharedPreferences.setMockInitialValues({});
    final loadGate = Completer<SharedPreferences>();
    final store = PrefsActiveRideRepository(load: () => loadGate.future);

    final oldSave = store.save(
      const PersistedActiveRide(
        tripId: 'trip-A',
        stage: ActiveRideStage.onTrip,
      ),
    );
    final oldClear = store.clear();
    final newSave = store.save(
      const PersistedActiveRide(
        tripId: 'trip-B',
        stage: ActiveRideStage.headingToPickup,
      ),
    );
    loadGate.complete(await SharedPreferences.getInstance());
    await Future.wait([oldSave, oldClear, newSave]);

    expect((await store.read())?.tripId, 'trip-B');
  });

  test('controller restore skips a stale snapshot', () async {
    final store = MemoryActiveRideRepository();
    await store.save(
      PersistedActiveRide(
        tripId: 'nearby-1',
        stage: ActiveRideStage.onTrip,
        savedAt: DateTime.now().subtract(const Duration(hours: 9)),
      ),
    );

    final ride = ActiveRideController(tripId: 'nearby-1', repository: store);
    await ride.restore();
    expect(ride.stage, ActiveRideStage.headingToPickup);
  });

  test(
    'controller initialStage restores mid-trip without walking transitions',
    () async {
      final ride = ActiveRideController(
        tripId: 'nearby-1',
        initialStage: ActiveRideStage.onTrip,
      );
      expect(ride.stage, ActiveRideStage.onTrip);
      expect(await ride.complete(), isTrue);
    },
  );

  test(
    'fromPersisted reconstructs the same trip so Home can reopen it',
    () async {
      final snapshot = PersistedActiveRide(
        tripId: 'nearby-1',
        stage: ActiveRideStage.waitingForRider,
        riderName: 'Angelica',
        riderRating: 4.96,
        fare: '104,80 kr',
        category: 'Comfort',
        matchedVia: 'Movera direct match',
        pickupAddress: 'Kungsgatan 42, Stockholm',
        pickupArea: 'Stockholm',
        dropoffAddress: 'Hornstull, Stockholm',
        stopAddresses: const <String>['Vasagatan 10, Stockholm'],
        stopPoints: const <GeoPoint>[GeoPoint(59.3300, 18.0580)],
        pickupLat: 59.3343,
        pickupLng: 18.0615,
        dropoffLat: 59.3157,
        dropoffLng: 18.0335,
        waitSeconds: 42,
      );

      final ride = AcceptRide.fromPersisted(snapshot);
      expect(ride.tripId, 'nearby-1');
      expect(ride.offerId, isNull);
      expect(ride.initialStage, ActiveRideStage.waitingForRider);
      expect(ride.riderName, 'Angelica');
      expect(ride.fare, '104,80 kr');
      expect(ride.pickupAddress, 'Kungsgatan 42, Stockholm');
      expect(ride.dropoffAddress, 'Hornstull, Stockholm');
      expect(ride.stopAddresses, <String>['Vasagatan 10, Stockholm']);
      expect(ride.stopPositions.single.latitude, 59.3300);
      expect(ride.pickupPosition.latitude, 59.3343);
      expect(ride.dropoffPosition.longitude, 18.0335);
      expect(ride.initialWaitSeconds, 42);
      expect(ride.matchedVia, 'Movera direct match');
    },
  );

  test(
    'active ride map is not rebuilt from the live vehicle pose ticker',
    () async {
      final source = File(
        'lib/presentation/driver/accept ride/accept_ride.dart',
      ).readAsStringSync();
      expect(source.contains('valueListenable: _vehicle.pose'), isFalse);
      expect(source.contains('_ThrottledVehicleMap'), isTrue);
      expect(source.contains("ValueKey<String>('active-ride-map')"), isTrue);
    },
  );
}
