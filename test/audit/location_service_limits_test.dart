import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movera/core/location/driver_location_service.dart';

// D3.6: DriverLocationService guards that must hold on every platform,
// not only where the platform plugin happens to enforce them.

class _FakeGeolocator extends GeolocatorPlatform {
  Completer<Position> current = Completer<Position>();
  Position? lastKnown;
  LocationAccuracyStatus accuracy = LocationAccuracyStatus.precise;

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracy;
  // Like geolocator_web 4.1.4: no Dart-side timeout, so a browser that
  // never answers never completes this future.
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      current.future;
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => lastKnown;
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
}
