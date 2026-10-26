import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';

class _FlakySessionRepository implements DriverSessionRepository {
  bool failRead = false;
  bool failNextWrite = false;
  bool? value;

  @override
  Future<bool?> readOnline() async {
    if (failRead) throw StateError('read unavailable');
    return value;
  }

  @override
  Future<void> saveOnline(bool isOnline) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('write unavailable');
    }
    value = isOnline;
  }

  @override
  Future<void> clear() async => value = null;
}

class _CountingRideRepository implements ActiveRideRepository {
  int saves = 0;
  PersistedActiveRide? snapshot;

  @override
  Future<PersistedActiveRide?> read() async => snapshot;

  @override
  Future<void> save(PersistedActiveRide ride) async {
    saves++;
    snapshot = ride;
  }

  @override
  Future<void> clear() async => snapshot = null;
}

void main() {
  test('GPS course of exactly north is a valid heading', () {
    const previous = GeoPoint(58.999, 18);
    const current = GeoPoint(59, 18);
    expect(
      current.resolvedHeading(gpsHeading: 0, previous: previous, fallback: 90),
      closeTo(61.2, 0.01),
    );
  });

  test('unavailable negative GPS course falls back to movement bearing', () {
    const previous = GeoPoint(59, 17.99);
    const current = GeoPoint(59, 18);
    final heading = current.resolvedHeading(
      gpsHeading: -1,
      previous: previous,
      fallback: 180,
    );
    expect(heading, closeTo(151.2, 1));
  });

  test('negative initial angles are normalized into a compass heading', () {
    expect(GeoPoint.shortestAngleLerp(-30, -10, 0.5), 340);
  });

  test('antipodal distance remains finite despite floating point rounding', () {
    const a = GeoPoint(0, 0);
    const b = GeoPoint(0, 180);
    expect(a.distanceMetersTo(b).isFinite, isTrue);
    expect(a.distanceMetersTo(b), greaterThan(20000000));
  });

  test('suspension during an active trip is deferred until end of trip', () {
    final session = DriverSessionController()..setOnline(true);
    addTearDown(session.dispose);
    session.beginTrip('journey');
    session.suspend();
    expect(session.status, DriverOnlineStatus.onTrip);
    expect(session.activeTripId, 'journey');
    session.endTrip();
    expect(session.status, DriverOnlineStatus.suspended);
    expect(session.availableForOffers, isFalse);
  });

  test(
    'successful next session write clears stale persistence error',
    () async {
      final store = _FlakySessionRepository()..failNextWrite = true;
      final session = DriverSessionController(repository: store);
      addTearDown(session.dispose);
      session.setOnline(true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(session.persistenceError, isNotNull);
      session.setOnline(false);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(session.persistenceError, isNull);
      expect(await store.readOnline(), isFalse);
    },
  );

  test('failed session restore cannot preserve initial online state', () async {
    final store = _FlakySessionRepository()..failRead = true;
    final session = DriverSessionController(
      initialOnline: true,
      repository: store,
    );
    addTearDown(session.dispose);
    await session.restore();
    expect(session.status, DriverOnlineStatus.offline);
    expect(session.persistenceError, isNotNull);
    expect(session.availableForOffers, isFalse);
  });

  test('duplicate realtime stage projections never rewrite the ride', () async {
    final repository = _CountingRideRepository();
    final ride = ActiveRideController(tripId: 'one', repository: repository);
    addTearDown(ride.dispose);
    expect(await ride.applyProjection(TripStatus.accepted), isTrue);
    expect(await ride.applyProjection(TripStatus.driverToPickup), isTrue);
    expect(repository.saves, 0);
    expect(await ride.applyProjection(TripStatus.arrived), isTrue);
    expect(repository.saves, 1);
    expect(await ride.applyProjection(TripStatus.arrived), isTrue);
    expect(repository.saves, 1);
  });
}
