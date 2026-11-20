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

  void _write(double toLat, double toLng, {double speed = 0}) {
    final path = _path;
    if (path == null) return;
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(
      '${toLat.toStringAsFixed(7)},${toLng.toStringAsFixed(7)}'
      '${speed > 0 ? ',${speed.toStringAsFixed(1)}' : ''}',
      flush: true,
    );
    tmp.renameSync(path);
  }

  /// Holds at the current point with mock fixes saying [speed] m/s
  /// (0 = standing; > 0 = the phone says it is moving, T7 test B).
  void hold({double speed = 0}) => _write(lat, lng, speed: speed);

  /// Drives in a straight line to ([toLat], [toLng]) at about
  /// [metersPerSecond], one new target a second, then holds there for
  /// [settle] (fixes keep coming, jittered 5-10 m by the feeder).
  Future<bool> driveTo(
    WidgetTester tester,
    double toLat,
    double toLng, {
    double metersPerSecond = 10,
    Duration settle = const Duration(seconds: 5),
    bool sayMoving = false,
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
      _write(lat, lng, speed: sayMoving ? metersPerSecond : 0);
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

/// T7 (owner 2026-11-19): turns the phone's Location / network off and on
/// through MainActivityTest (one word in MOVERA_TL_CONTROL_FILE; the
/// answer, the phone's switch states, comes back in the same name + .ack).
class PhoneSwitches {
  PhoneSwitches() : _path = Platform.environment['MOVERA_TL_CONTROL_FILE'];

  final String? _path;

  bool get usable => _path != null;

  /// Writes [word] (location-off, location-on, net-off, net-on) and waits
  /// up to 15 s for the phone's answer; returns it (null: none).
  ///
  /// [pump] false: plain time passes between reads, no frame is pumped
  /// (the app is really in the background then and frames are off; a
  /// pump would wait forever, run 6). Also words home, front, notif, top.
  Future<String?> send(
    WidgetTester tester,
    String word, {
    bool pump = true,
  }) async {
    final path = _path;
    if (path == null) return null;
    final ack = File('$path.ack');
    if (ack.existsSync()) ack.deleteSync();
    final tmp = File('$path.tmp');
    tmp.writeAsStringSync(word, flush: true);
    tmp.renameSync(path);
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(end)) {
      pump
          ? await wait(tester, const Duration(milliseconds: 500))
          : await Future<void>.delayed(const Duration(milliseconds: 500));
      if (ack.existsSync()) {
        final text = ack.readAsStringSync().trim();
        if (text.startsWith(word)) {
          CheckLog.say('STEP phone switch: $text');
          return text;
        }
      }
    }
    CheckLog.say('STEP phone switch $word: no answer in 15 s');
    return null;
  }
}
