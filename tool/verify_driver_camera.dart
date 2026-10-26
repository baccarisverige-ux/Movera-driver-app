import 'dart:async';
import 'dart:io';

import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/navigation/route_camera_geometry.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/routing/route_repository.dart';

void check(bool value, String label) {
  if (!value) {
    throw StateError(label);
  }
}

class RecordingCamera implements DriverCameraPort {
  final List<DriverCameraPose> commands = [];
  final List<Completer<void>> completions = [];
  int interrupts = 0;
  bool disposed = false;
  int previews = 0;
  @override
  Future<void> animate(DriverCameraPose pose) {
    commands.add(pose);
    final done = Completer<void>();
    completions.add(done);
    return done.future;
  }

  @override
  Future<void> overview(List<GeoPoint> points, double padding) async {
    previews++;
  }

  @override
  void retarget(DriverCameraPose pose) {}

  @override
  void interrupt() {
    interrupts++;
  }

  @override
  void dispose() {
    disposed = true;
  }

  void complete() {
    for (final c in completions) {
      if (!c.isCompleted) {
        c.complete();
      }
    }
  }
}

class TiltingCamera extends RecordingCamera implements DriverCameraTilting {
  @override
  double? currentZoom;
  @override
  double? currentTilt;
  final List<double> tilts = [];
  @override
  Future<void> tiltTo(double tilt) async {
    tilts.add(tilt);
    currentTilt = tilt;
  }
}

Future<void> runCameraContractTests() async {
  final now = DateTime.utc(2026, 10, 6);
  DriverLocation fix(GeoPoint point, {double heading = 0, double speed = 10}) =>
      DriverLocation(
        point: point,
        headingDegrees: heading,
        speedMetersPerSecond: speed,
        measuredAt: now,
        accuracyMeters: 5,
      );
  const origin = GeoPoint(59.33, 18.06);
  const turn = GeoPoint(59.334, 18.06);
  const end = GeoPoint(59.334, 18.066);
  RoadRoute route(RouteManeuverType type) => RoadRoute(
    points: const [origin, turn, end],
    distanceMeters: 790,
    durationSeconds: 80,
    instructions: [
      RouteInstruction(
        type: type,
        modifier: 'right',
        text: 'Turn right',
        distanceMeters: 445,
        maneuverLocation: turn,
      ),
      const RouteInstruction(
        type: RouteManeuverType.arrive,
        modifier: '',
        text: 'Arrive',
        distanceMeters: 345,
        maneuverLocation: end,
      ),
    ],
  );
  for (final type in [
    RouteManeuverType.turn,
    RouteManeuverType.roundabout,
    RouteManeuverType.rotary,
    RouteManeuverType.fork,
    RouteManeuverType.offRamp,
  ]) {
    final policy = DriverCameraPolicy();
    final road = route(type);
    final cruise = policy.resolve(
      location: fix(origin),
      route: road,
      navigating: true,
      immediate: true,
    );
    final preview = policy.resolve(
      location: fix(const GeoPoint(59.3327, 18.06)),
      route: road,
      navigating: true,
      immediate: true,
    );
    final close = policy.resolve(
      location: fix(const GeoPoint(59.3339, 18.06)),
      route: road,
      navigating: true,
      immediate: true,
    );
    check(preview.zoom > cruise.zoom, '$type tightens inside 180m');
    check(
      preview.tilt >= cruise.tilt,
      '$type never flatter approaching junction',
    );
    check(close.tilt >= preview.tilt, '$type never flattens near maneuver');
    check(
      close.zoom - cruise.zoom <= DriverCameraPolicy.maxTurnZoomIn + 1e-9,
      '$type zooms in only a little at the junction',
    );
    check(close.zoom > cruise.zoom, '$type closes in near maneuver');
    final after = policy.resolve(
      location: fix(const GeoPoint(59.334, 18.061)),
      route: road,
      navigating: true,
      immediate: true,
    );
    check((after.bearing - 90).abs() < 1, 'Follow route direction after turn');
    check(
      after.zoom == 14.5 && after.tilt == DriverCameraPolicy.tiltForZoom(14.5),
      'Recover speed zoom and driving tilt',
    );
  }
  final policy = DriverCameraPolicy();
  policy.resolve(location: fix(origin, heading: 359), immediate: true);
  final wrapped = policy.resolve(location: fix(origin, heading: 1));
  check(wrapped.bearing == 0, 'Explore is north-up independent of car course');
  check(policy.vehicleCourse == 1, 'Car holds real course in explore');
  policy.resolve(location: fix(origin, heading: 170, speed: .4));
  check(policy.vehicleCourse == 1, 'Stationary car holds last good GPS course');
  check(
    GeoPoint.shortestAngleLerp(359, 1, .5) < 2,
    'Shortest-angle interpolation crosses north without full circle',
  );
  // Guidance stays wide: the strong tilt already shows the road far ahead,
  // and one level under street zoom the near roads stay slim.
  check(DriverCameraPolicy.zoomForSpeed(3) == 15, 'Slow-speed zoom');
  check(DriverCameraPolicy.zoomForSpeed(10) == 14.5, 'Urban-speed zoom');
  check(DriverCameraPolicy.zoomForSpeed(20) == 14, 'Fast urban zoom');
  check(DriverCameraPolicy.zoomForSpeed(30) == 13.625, 'Highway zoom');
  check(
    DriverCameraPolicy.zoomForSpeed(double.nan) == 15,
    'Missing speed stays at slow-speed framing',
  );
  // Former 20/50/80 km/h hard thresholds jumped a full zoom level when
  // sensor speed oscillated by a fraction of a metre per second.
  for (final threshold in [20 / 3.6, 50 / 3.6, 80 / 3.6]) {
    final before = DriverCameraPolicy.zoomForSpeed(threshold - 0.03);
    final after = DriverCameraPolicy.zoomForSpeed(threshold + 0.03);
    check(
      (before - after).abs() < .03,
      'Speed fluctuation near $threshold m/s must not snap camera zoom',
    );
  }
  var previousZoom = DriverCameraPolicy.zoomForSpeed(0);
  for (var speed = .5; speed <= 36; speed += .5) {
    final zoom = DriverCameraPolicy.zoomForSpeed(speed);
    check(
      zoom.isFinite && zoom >= 13.625 && zoom <= 15,
      'Autozoom must stay within approved road framing',
    );
    check(
      zoom <= previousZoom,
      'Zoom decreases smoothly as driving speed rises',
    );
    previousZoom = zoom;
  }
  check(
    wrapped.zoom == DriverCameraPolicy.exploreZoom &&
        wrapped.tilt == DriverCameraPolicy.tiltForZoom(wrapped.zoom) &&
        wrapped.tilt < 6,
    'Outside trip the area view tilts with its zoom (nearly flat)',
  );
  final waiting = policy.resolve(
    location: fix(origin),
    waiting: true,
    navigating: true,
    immediate: true,
  );
  check(waiting.tilt == 0 && waiting.zoom == 17.2, 'Waiting is calm and close');
  final offRoute = policy.resolve(
    location: fix(const GeoPoint(59.32, 18.08), heading: 210),
    route: route(RouteManeuverType.turn),
    navigating: true,
    immediate: true,
  );
  check(
    offRoute.bearing == 210,
    'Off-route does not force wrong route bearing',
  );
  final smooth = policy.resolve(
    location: fix(origin),
    route: route(RouteManeuverType.turn),
    navigating: true,
  );
  check(
    smooth.duration.inMilliseconds == 450,
    'Time-based four-axis smoothing',
  );

  final thresholdRoad = route(RouteManeuverType.turn);
  DriverCameraPose nearTurn(double metersBeforeTurn) {
    final camera = DriverCameraPolicy();
    return camera.resolve(
      location: fix(
        GeoPoint(turn.latitude - metersBeforeTurn / 111320, turn.longitude),
      ),
      route: thresholdRoad,
      navigating: true,
      immediate: true,
    );
  }

  final outsidePreview = nearTurn(184);
  final insidePreview = nearTurn(176);
  check(
    (insidePreview.zoom - outsidePreview.zoom).abs() < .15,
    'Turn preview begins without a half-level camera zoom snap',
  );
  check(
    nearTurn(90).zoom > insidePreview.zoom,
    'Approaching a turn steadily tightens the map framing',
  );

  final curve = DriverCameraPolicy();
  final curvedRoute = route(RouteManeuverType.turn);
  curve.resolve(
    location: fix(origin),
    route: curvedRoute,
    navigating: true,
    immediate: true,
  );
  final anticipating = curve.resolve(
    location: fix(const GeoPoint(59.3338, 18.06), speed: 20),
    route: curvedRoute,
    navigating: true,
  );
  check(
    anticipating.bearing > 0 && anticipating.bearing <= 30,
    'Right bend rotates early with maximum 30 degree course lead',
  );
  check(
    anticipating.duration.inMilliseconds == 450,
    'Driving bearing smooths over 450 milliseconds',
  );
  final snapping = DriverCameraPolicy();
  final snapped = snapping.resolve(
    location: fix(const GeoPoint(59.332, 18.0601)),
    route: curvedRoute,
    navigating: true,
    immediate: true,
  );
  check(
    (snapped.target.longitude - 18.06).abs() < .000001,
    'On-route driver snaps to segment rather than next vertex',
  );
  final geometry = RouteCameraGeometry(curvedRoute.points);
  check(
    geometry.remaining(snapping.alongMeters).first == snapping.vehiclePoint,
    'Remaining stroke starts at snapped car, no thick line behind it',
  );
  final arrival = snapping.resolve(
    location: fix(end, heading: 90),
    route: curvedRoute,
    navigating: true,
    immediate: true,
  );
  check(
    arrival.tilt == DriverCameraPolicy.arrivalTilt,
    'Arrival stays tilted at 60 degrees, never flat',
  );
  DriverCameraPose approachDestination(double meters) {
    final arrivingCamera = DriverCameraPolicy();
    return arrivingCamera.resolve(
      location: fix(
        GeoPoint(end.latitude, end.longitude - meters / 56800),
        speed: 30,
      ),
      route: curvedRoute,
      navigating: true,
      immediate: true,
    );
  }

  check(
    (approachDestination(138).zoom - approachDestination(142).zoom).abs() < .05,
    'Arrival framing must not jump at the 140 metre ease-in threshold',
  );
  check(
    (approachDestination(33).zoom - approachDestination(37).zoom).abs() < .2,
    'The previous 35 metre threshold must not trigger a zoom snap',
  );
  check(
    approachDestination(45).zoom > approachDestination(120).zoom,
    'High-speed arrival smoothly tightens the view toward the endpoint',
  );
  check(
    approachDestination(0).tilt == DriverCameraPolicy.arrivalTilt &&
        approachDestination(0).zoom >= DriverCameraPolicy.arrivalZoom,
    'Final arrival remains close and tilted at 60 degrees',
  );

  final fast = DriverCameraPolicy();
  fast.resolve(
    location: fix(origin, speed: 30),
    route: curvedRoute,
    navigating: true,
    immediate: true,
  );
  final fastJunction = fast.resolve(
    location: fix(const GeoPoint(59.3335, 18.06), speed: 30),
    route: curvedRoute,
    navigating: true,
  );
  check(
    fastJunction.zoom > DriverCameraPolicy.zoomForSpeed(30) &&
        fastJunction.tilt >= DriverCameraPolicy.tiltForZoom(13.75),
    'Highway-speed junction framing does not wait for many GPS samples',
  );

  // Tilt follows zoom: flat up to zoom 12, then proportional to zoom
  // (linear) up to the SDK maximum (67.5 degrees) at zoom 15.5, never above
  // what the SDK allows, so every pinch step changes the tilt.
  check(
    DriverCameraPolicy.tiltForZoom(12) == 0 &&
        DriverCameraPolicy.tiltForZoom(DriverCameraPolicy.exploreZoom) == 0,
    'Region overview zoom is flat',
  );
  check(
    DriverCameraPolicy.tiltForZoom(15.5) == 67.5 &&
        DriverCameraPolicy.tiltForZoom(16) == 67.5 &&
        DriverCameraPolicy.tiltForZoom(20) == 67.5,
    'Street zoom tilts 67.5 degrees toward the horizon',
  );
  check(
    (DriverCameraPolicy.tiltForZoom(13.75) - 33.75).abs() < 1e-9,
    'Halfway up the zoom range is halfway up the tilt',
  );
  for (var zoom = 0.0; zoom <= 21; zoom += .1) {
    check(
      DriverCameraPolicy.tiltForZoom(zoom) <=
          DriverCameraPolicy.sdkMaxTilt(zoom),
      'Tilt never exceeds what the SDK allows at $zoom',
    );
  }
  var previousTilt = 0.0;
  for (var zoom = 12.02; zoom <= 15.5; zoom += .02) {
    final tilt = DriverCameraPolicy.tiltForZoom(zoom);
    check(
      tilt > previousTilt && tilt - previousTilt < 1,
      'Tilt rises with every zoom step (no plateau, no step at $zoom)',
    );
    previousTilt = tilt;
  }
  final arrivalFrames = [
    for (var meters = 160.0; meters >= 0; meters -= 10)
      approachDestination(meters),
  ];
  for (var i = 1; i < arrivalFrames.length; i++) {
    check(
      (arrivalFrames[i].tilt - arrivalFrames[i - 1].tilt).abs() < 6,
      'Arrival tilt eases to 60 degrees without a jump',
    );
    check(arrivalFrames[i].tilt >= 15, 'Arrival never goes flat');
  }

  final camera = DriverCameraController(now: () => now);
  final port = RecordingCamera();
  camera.attach(port);
  check(camera.state == DriverCameraState.explore, 'App opens in explore');
  camera.update(location: fix(origin));
  camera.update(location: fix(turn));
  check(port.commands.length == 1, 'Serialize and coalesce GPS updates');
  camera.userGesture();
  check(
    camera.state == DriverCameraState.free,
    'Touch immediately enters Free',
  );
  camera.update(location: fix(end));
  check(port.commands.length == 1, 'Browsing suppresses follow commands');
  camera.recenter();
  check(
    port.commands.last.target == end,
    'Recenter uses latest GPS, not browse pose',
  );
  port.complete();
  await Future<void>.delayed(Duration.zero);
  check(
    port.commands.length == 2,
    'Old completion cannot replay pending command',
  );
  camera.suspend();
  camera.update(location: fix(turn));
  check(port.commands.length == 2, 'Background suppresses commands');
  camera.resume();
  check(port.commands.last.target == turn, 'Resume follows latest position');
  camera.userGesture();
  camera.suspend();
  camera.resume();
  check(
    camera.mode == DriverCameraMode.browsing,
    'Background retains manual mode',
  );
  await camera.preview([origin, end]);
  check(
    port.previews == 0,
    'Late route overview cannot steal browsed viewport',
  );
  camera.update(
    location: DriverLocation(
      point: origin,
      accuracyMeters: 5,
      measuredAt: now.subtract(const Duration(minutes: 1)),
    ),
  );
  camera.recenter();
  check(port.commands.last.target == turn, 'Reject stale GPS');
  final next = RecordingCamera();
  camera.attach(next);
  check(port.disposed, 'Map replacement releases old port');
  camera.dispose();
  next.complete();
  port.complete();
  await Future<void>.delayed(Duration.zero);
  camera.update(location: fix(origin));
  camera.recenter();
  check(next.disposed, 'Dispose releases camera port');

  final previewCamera = DriverCameraController(now: () => now);
  final previewPort = RecordingCamera();
  previewCamera.attach(previewPort);
  await previewCamera.preview([origin, end]);
  previewCamera.update(location: fix(origin), route: curvedRoute);
  check(
    previewCamera.state == DriverCameraState.preview &&
        previewPort.commands.isEmpty,
    'Destination preview does not follow GPS',
  );
  previewCamera.update(
    location: fix(origin),
    route: curvedRoute,
    navigating: true,
  );
  check(
    previewCamera.state == DriverCameraState.following &&
        previewPort.commands.single.duration.inMilliseconds == 900,
    'Guidance starts with one 900ms camera animation',
  );
  previewCamera.userGesture();
  previewCamera.update(
    location: fix(turn),
    route: route(RouteManeuverType.turn),
    navigating: true,
  );
  check(
    previewCamera.state == DriverCameraState.free,
    'Rerouting preserves manual viewport',
  );
  previewCamera.recenter();
  check(
    previewPort.commands.last.duration.inMilliseconds == 900,
    'Recenter restores guidance in one animation',
  );
  previewCamera.dispose();
  previewPort.complete();

  // The driver's own pinch zoom during guidance: once let go, the tilt
  // follows their zoom with the guidance formula; recenter restores the
  // guidance zoom with its matching tilt.
  final pinchCamera = DriverCameraController(now: () => now);
  final pinchPort = TiltingCamera();
  pinchCamera.attach(pinchPort);
  pinchCamera.update(
    location: fix(origin),
    route: curvedRoute,
    navigating: true,
  );
  pinchCamera.userGesture();
  pinchCamera.touching = true;
  pinchPort
    ..currentZoom = 13.2
    ..currentTilt = 45;
  pinchCamera.browseSettled();
  check(pinchPort.tilts.isEmpty, 'No tilt while a finger is on the map');
  pinchCamera.touching = false;
  check(
    pinchPort.tilts.single == DriverCameraPolicy.tiltForZoom(13.2),
    'Zooming out by hand flattens the tilt once let go',
  );
  pinchPort.currentZoom = 18.4;
  pinchCamera.browseSettled();
  check(
    pinchPort.tilts.last == DriverCameraPolicy.maxTilt,
    'Zooming in by hand tilts toward the horizon',
  );
  pinchCamera.browseSettled();
  check(pinchPort.tilts.length == 2, 'A matching tilt is left alone');
  pinchCamera.recenter();
  final back = pinchPort.commands.last;
  check(
    back.tilt == DriverCameraPolicy.tiltForZoom(back.zoom),
    'Recenter returns to guidance zoom with its matching tilt',
  );
  pinchPort.currentZoom = 14;
  pinchCamera.browseSettled();
  check(pinchPort.tilts.length == 2, 'Following ignores settle requests');
  pinchCamera.update(location: fix(origin), navigating: true, waiting: true);
  pinchCamera.userGesture();
  pinchCamera.browseSettled();
  check(pinchPort.tilts.length == 2, 'Waiting at the pickup stays flat');
  pinchCamera.dispose();
  pinchPort.complete();
}

Future<void> main() async {
  await runCameraContractTests();
  stdout.writeln(
    'PASS: Driver camera policy, follow/browse, recenter, lifecycle and queue contracts',
  );
}
