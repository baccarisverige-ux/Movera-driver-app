import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/location/driver_location_service.dart';

// D3.6: DriverLocationService guards that must hold on every platform,
// not only where the platform plugin happens to enforce them.

class _FakeGeolocator extends GeolocatorPlatform {
  Completer<Position> current = Completer<Position>();
  Position? lastKnown;
  /// Null: the platform cannot tell (like the web plugin).
  LocationAccuracyStatus? accuracy = LocationAccuracyStatus.precise;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      accuracy ?? (throw UnimplementedError('not on this platform'));
  // Like geolocator_web 4.1.4: no Dart-side timeout, so a browser that
  // never answers never completes this future.
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      current.future;
  /// Like geolocator_web 4.1.4: getLastKnownPosition throws at once.
  bool lastKnownUnsupported = false;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) => lastKnownUnsupported
      ? throw UnsupportedError('getLastKnownPosition is not supported')
      : Future.value(lastKnown);
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      const Stream<Position>.empty();
}

void main() {
  late GeolocatorPlatform original;
  late _FakeGeolocator fake;
  setUp(() {
    original = GeolocatorPlatform.instance;
    fake = _FakeGeolocator();
    GeolocatorPlatform.instance = fake;
  });
  tearDown(() => GeolocatorPlatform.instance = original);

  testWidgets('driver-18: a GPS one-shot that never answers gives up after '
      '8 s even when the platform does not enforce the time limit',
      (tester) async {
    Object? error;
    var done = false;
    unawaited(const DriverLocationService().getCurrentPosition().then(
      (_) => done = true,
      onError: (Object e) {
        error = e;
        done = true;
      },
    ));
    await tester.pump(const Duration(seconds: 7));
    expect(done, isFalse, reason: 'still inside the 8 s limit');
    await tester.pump(const Duration(seconds: 2));
    expect(done, isTrue,
        reason: 'a hung one-shot must not block Home and the trip');
    expect(error, isA<TimeoutException>());
  });

  test('driver-r4-22: where last known is unsupported (web) the real GPS '
      'error still reaches the caller', () async {
    fake.lastKnownUnsupported = true;
    fake.current
      ..future.ignore() // the service listens only after its checks
      ..completeError(const PositionUpdateException('no fix'));
    await expectLater(const DriverLocationService().getCurrentPosition(),
        throwsA(isA<PositionUpdateException>()));
  });

  test('driver-u24: approximate-only location is refused with its own '
      'error instead of passing the permission check', () async {
    fake.accuracy = LocationAccuracyStatus.reduced;
    fake.current.complete(Position(
      latitude: 59.33,
      longitude: 18.06,
      timestamp: DateTime.now(),
      accuracy: 1800,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ));
    const service = DriverLocationService();
    await expectLater(service.getCurrentPosition(),
        throwsA(isA<PreciseLocationRequiredException>()));
    await expectLater(service.watchPosition(distanceFilterMeters: 0),
        emitsError(isA<PreciseLocationRequiredException>()));
  });

  test('driver-u24: precise location, or a platform that cannot tell, '
      'still gets its fix', () async {
    fake.accuracy = null;
    fake.current.complete(Position(
      latitude: 59.33,
      longitude: 18.06,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    ));
    final fix = await const DriverLocationService().getCurrentPosition();
    expect(fix.accuracyMeters, 5);
  });
}
