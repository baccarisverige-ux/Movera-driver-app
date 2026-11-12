import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'check_log.dart';
import 'driver_steps.dart';

/// Moves the phone's mock GPS during the run.
///
/// MainActivityTest feeds mock fixes every second around a target it reads
/// from a small file in the app's private files folder (path in
/// MOVERA_TL_MOCK_FILE, set by MainActivityTest before the app starts).
/// The test writes "lat,lng" there; the Java feeder picks up the new
/// target on its next round (<= 1 s). The file holds only coordinates.
class MockPosition {
  MockPosition(this.lat, this.lng)
    : _path = Platform.environment['MOVERA_TL_MOCK_FILE'];

  double lat;
  double lng;
  final String? _path;

  /// False when the run has no mock feeder (movera_tl_mock_location=0 or
  /// an older MainActivityTest): the position cannot be moved.
  bool get movable => _path != null;

  void _write(double toLat, double toLng) {
    final path = _path;
    if (path == null) return;
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      '${toLat.toStringAsFixed(7)},${toLng.toStringAsFixed(7)}',
      flush: true,
    );
    tmp.renameSync(path);
  }

  /// Drives in a straight line to ([toLat], [toLng]) at about
  /// [metersPerSecond], one new target a second, then holds there for
  /// [settle] (fixes keep coming, jittered 5-10 m by the feeder).
  Future<bool> driveTo(
    WidgetTester tester,
    double toLat,
    double toLng, {
    double metersPerSecond = 10,
    Duration settle = const Duration(seconds: 5),
  }) async {
    if (!movable) return false;
    final meters = distanceMeters(lat, lng, toLat, toLng);
    final steps = math.max(1, (meters / metersPerSecond).ceil());
    final fromLat = lat, fromLng = lng;
    CheckLog.say('STEP mock position drives ${meters.round()} m in $steps s');
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      lat = fromLat + (toLat - fromLat) * t;
      lng = fromLng + (toLng - fromLng) * t;
      _write(lat, lng);
      await wait(tester, const Duration(seconds: 1));
    }
    await wait(tester, settle);
    return true;
  }

  /// A point [north] m north and [east] m east of ([lat], [lng]).
  static (double, double) offset(
    double lat,
    double lng, {
    double north = 0,
    double east = 0,
  }) => (
    lat + north / 111320.0,
    lng + east / (111320.0 * math.cos(lat * math.pi / 180)),
  );

  static double distanceMeters(
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) {
    const r = 6371000.0;
    final dLat = (bLat - aLat) * math.pi / 180;
    final dLng = (bLng - aLng) * math.pi / 180;
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(aLat * math.pi / 180) *
            math.cos(bLat * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(h));
  }
}
