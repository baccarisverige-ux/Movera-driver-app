// Wave 5 D5.6: small local fixes, one test per bug.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/routing/route_instruction.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/safety/ride_check_recorder_native.dart';
import 'package:movera/l10n/app_localizations.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc_phone.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/settings/settings.dart';
import 'package:movera/core/settings/map_traffic_setting.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movera/widgets/checkbox.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/navigation/driver_camera_controller.dart';
import 'package:movera/core/routing/route_repository.dart';

/// Records every pose the camera resolves.
class _SpyPolicy extends DriverCameraPolicy {
  final poses = <DriverCameraPose>[];
  @override
  DriverCameraPose resolve({
    required DriverLocation location,
    RoadRoute? route,
    bool navigating = false,
    bool waiting = false,
    bool immediate = false,
    bool sameFix = false,
  }) {
    final pose = super.resolve(
      location: location,
      route: route,
      navigating: navigating,
      waiting: waiting,
      immediate: immediate,
      sameFix: sameFix,
    );
    poses.add(pose);
    return pose;
  }
}

/// The record plugin's recorder without the platform: it writes [bytes]
/// to the file it is asked to record to.
class _FakeAudio implements AudioRecorder {
  _FakeAudio({this.bytes = 3});
  final int bytes;
  String? path;
  var disposed = false;
  @override
  Future<bool> hasPermission({bool request = true}) async => true;
  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    this.path = path;
    File(path).writeAsBytesSync(List<int>.filled(bytes, 1));
  }
  @override
  Future<String?> stop() async => path;
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async => disposed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [screen] in the app at phone size.
Future<void> _pumpScreen(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(home: screen),
  ));
  await _frames(tester, 6);
}

/// GPS the test sends by hand.
class _Gps implements DriverLocationRepository {
  final updates = StreamController<DriverLocation>.broadcast();
  @override
  Future<DriverLocation> getCurrentPosition() async => _at(0);
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      updates.stream;
}

/// [meters] north of Stockholm Central, driving north.
DriverLocation _at(double meters) => DriverLocation(
      point: GeoPoint(59.3300 + meters / 111000, 18.0600),
      speedMetersPerSecond: 10,
      measuredAt: DateTime.now(),
      accuracyMeters: 5,
    );

Future<void> _frames(WidgetTester tester, int count, [int ms = 50]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(Duration(milliseconds: ms));
  }
}

/// A road route that arrives when the test says so.
class _SlowRoutes implements RouteRepository {
  final pending = <Completer<RoadRoute>>[];
  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) {
    final route = Completer<RoadRoute>();
    pending.add(route);
    return route.future;
  }

  void arrive() {
    for (final route in pending) {
      if (!route.isCompleted) {
        route.complete(_road(const GeoPoint(59.33, 18.06), const GeoPoint(59.36, 18.0)));
      }
    }
  }
}

/// Settings storage that refuses every write (a full localStorage).
class _FullStorage extends SettingsRepository {
  @override
  Future<void> save(String section, Map<String, dynamic> values) async =>
      throw StateError('Settings save failed');
}

/// Rebuilds when the Ride check gate changes, as Home does.
class _GateListener extends StatefulWidget {
  const _GateListener();
  @override
  State<_GateListener> createState() => _GateListenerState();
}

class _GateListenerState extends State<_GateListener> {
  var builds = 0;
  void _changed() => setState(() {});
  @override
  void initState() {
    super.initState();
    RideCheckGate.listenable.addListener(_changed);
  }

  @override
  void dispose() {
    RideCheckGate.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('builds ${++builds}');
}

/// Closes the gate when it leaves, as the trip screen's Ride check does.
class _GateHolder extends StatefulWidget {
  const _GateHolder();
  @override
  State<_GateHolder> createState() => _GateHolderState();
}

class _GateHolderState extends State<_GateHolder> {
  @override
  void dispose() {
    RideCheckGate.set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// A fresh phone folder for the recorder.
Directory _phoneFolder() {
  final root = Directory.systemTemp.createTempSync('movera-d56-');
  addTearDown(() => root.deleteSync(recursive: true));
  final support = Directory('${root.path}/support')..createSync();
  final documents = Directory('${root.path}/documents')..createSync();
  final (storage, legacy, phone) =
      (rideCheckStorageRoot, rideCheckLegacyRoot, rideCheckOnPhone);
  rideCheckStorageRoot = () async => support;
  rideCheckLegacyRoot = () async => documents;
  rideCheckOnPhone = () => true;
  addTearDown(() {
    rideCheckStorageRoot = storage;
    rideCheckLegacyRoot = legacy;
    rideCheckOnPhone = phone;
  });
  return support;
}

final _en = lookupAppLocalizations(const Locale('en'));
final _sv = lookupAppLocalizations(const Locale('sv'));

RoadRoute _road(GeoPoint from, GeoPoint to) => RoadRoute(
      points: [from, to],
      distanceMeters: from.distanceMetersTo(to),
      durationSeconds: 600,
    );

void main() {
  test('driver-u5: a keyless iOS release with the key required fails', () {
    ProcessResult gate(Map<String, String> env) => Process.runSync(
          '/bin/sh',
          ['ios/scripts/require_maps_key.sh'],
          environment: {'PATH': '/usr/bin:/bin', ...env},
          includeParentEnvironment: false,
        );
    final keyless = gate({
      'CONFIGURATION': 'Release',
      'MOVERA_REQUIRE_MAPS_KEY': 'true',
      'GOOGLE_MAPS_API_KEY': ' ',
    });
    expect(keyless.exitCode, 1);
    expect('${keyless.stdout}',
        contains('Native release requires GOOGLE_MAPS_API_KEY'));
    expect(
      gate({
        'CONFIGURATION': 'Release',
        'MOVERA_REQUIRE_MAPS_KEY': 'true',
        'GOOGLE_MAPS_API_KEY': 'key',
      }).exitCode,
      0,
    );
    expect(gate({'CONFIGURATION': 'Release'}).exitCode, 0);
    // The Runner target runs it before it builds anything.
    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains(r'\"$SRCROOT/scripts/require_maps_key.sh\"'));
    expect(
      RegExp(r'buildPhases = \(\s*(\w+) /\* Require Maps Key \*/,\s*\w+ /\* Run Script \*/')
          .hasMatch(project),
      isTrue,
    );
  });

  test('driver-21: a route refresh does not smooth the same fix twice', () {
    final now = DateTime(2026, 10, 22, 8);
    final policy = _SpyPolicy();
    final camera = DriverCameraController(policy: policy, now: () => now);
    const a = GeoPoint(59.33, 18.06), b = GeoPoint(59.36, 18.06);
    DriverLocation fix(double speed) => DriverLocation(
          point: a,
          speedMetersPerSecond: speed,
          measuredAt: now,
          accuracyMeters: 5,
        );
    camera.update(location: fix(0), route: _road(a, b), navigating: true);
    final fast = fix(30);
    camera.update(location: fast, route: _road(a, b), navigating: true);
    // The trip's route refresh reports the same fix with a new route.
    camera.update(location: fast, route: _road(a, b), navigating: true);
    final once = policy.poses[1], again = policy.poses[2];
    // Before: 14.75 then 14.5, the speed zoom stepped twice for one fix.
    expect(again.zoom, once.zoom);
    expect(again.bearing, once.bearing);
    camera.dispose();
  });

  test('driver-27: a distance is rounded before its unit is picked', () {
    String say(double m) => RouteInstructionCopy.formatDistance(m, _en);
    expect(say(999.4), '999 m');
    expect(say(999.6), '1.0 km'); // before: 1000 m
    expect(say(9949), '9.9 km');
    expect(say(9960), '10 km'); // before: 10.0 km
    expect(RouteInstructionCopy.formatDistance(9960, _sv), '10 km');
  });

  testWidgets('driver-u89: the island rounds its distance before the unit',
      (tester) async {
    Future<void> island(double meters) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: AdaptiveTripIsland(
              banner: NavigationBanner(
                primary: 'Sveavägen',
                distanceLabel: RouteInstructionCopy.formatDistance(meters),
                distanceMeters: meters,
              ),
              status: 'To pickup', address: 'Sveavägen 20',
              detail: 'Picking up Angelica', eta: '2 min', progress: .4,
              waitingMessage: 'Waiting', lastTripLabel: '120 kr',
              onRadar: () {}, onMenu: () {}, onSearch: () {},
              onHistory: () {}, onRoute: () {}, onSafety: () {}, onWait: () {},
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    String shown() => tester
        .widget<Text>(find.byKey(const ValueKey('island-distance')))
        .textSpan!
        .toPlainText();
    await island(999.6);
    expect(shown(), '1.0km'); // before: 1000m
    await island(9960);
    expect(shown(), '10km'); // before: 10.0km
    await tester.pumpWidget(const SizedBox());
  });

  test('driver-29: recordings are saved in the support folder', () async {
    final support = _phoneFolder();
    final audio = _FakeAudio();
    final recorder = NativeRideCheckRecorder(createAudio: () => audio);
    await recorder.start('trip-1');
    // Before: <documents>/ride_check_audio, backed up to iCloud.
    expect(audio.path, '${support.path}/ride_check_audio/trip-1.m4a');
    await recorder.stop();
  });

  test('driver-30: a stopped recorder is released; an empty file is deleted',
      () async {
    _phoneFolder();
    final audio = _FakeAudio(bytes: 0);
    final recorder = NativeRideCheckRecorder(createAudio: () => audio);
    await recorder.start('trip-1');
    expect(await recorder.stop(), isNull);
    expect(File(audio.path!).existsSync(), isFalse); // before: left on disk
    expect(audio.disposed, isTrue); // before: never disposed
  });

  test('driver-u31: logout deletes the Ride check recordings', () async {
    SharedPreferences.setMockInitialValues({});
    final support = _phoneFolder();
    final recorder = NativeRideCheckRecorder(createAudio: _FakeAudio.new);
    await recorder.start('trip-1');
    final saved = await recorder.stop();
    expect(File(saved!).existsSync(), isTrue);
    final older = File('${support.parent.path}/documents/ride_check_audio/a.m4a')
      ..createSync(recursive: true);
    await clearLocalUserData();
    expect(File(saved).existsSync(), isFalse); // before: kept after logout
    expect(older.existsSync(), isFalse);
  });

  testWidgets('driver-36: a Ride check closed by the leaving trip screen '
      'does not rebuild Home inside the locked tree', (tester) async {
    RideCheckGate.set(true);
    addTearDown(() => RideCheckGate.set(false));
    Widget app({required bool trip}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [
            const _GateListener(),
            if (trip) const _GateHolder(),
          ]),
        );
    await tester.pumpWidget(app(trip: true));
    await tester.pumpWidget(app(trip: false));
    // Before: 'setState() or markNeedsBuild() called when widget tree was
    // locked' from the trip screen's dispose.
    expect(tester.takeException(), isNull);
    expect(RideCheckGate.open, isFalse);
    await tester.pump();
    expect(find.text('builds 2'), findsOneWidget, reason: 'Home heard it');
  });

  testWidgets('driver-u59: the hidden trip map gets no car updates',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final config = DriverRuntimeConfig.current;
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: true,
      externalRouting: false,
      skipAccountActivation: true,
      reservationPopup: false,
      islandHint: false,
      radarSound: false,
    ); // with the 33 ms car ticker
    addTearDown(() => DriverRuntimeConfig.current = config);
    final gps = _Gps();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [driverRouteObserver],
      // Reduced motion: each fix puts the car straight on its new spot.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: AcceptRide(
        locationRepository: gps,
        initialStage: ActiveRideStage.onTrip,
      ),
    ));
    await _frames(tester, 10);
    final map = tester.widget<CustomGoogleMap>(find.descendant(
      of: find.byKey(const ValueKey<String>('active-ride-throttled-map')),
      matching: find.byType(CustomGoogleMap),
    ));
    var pushes = 0;
    void count() => pushes++;
    map.liveMarker!.addListener(count);
    Future<void> drive(double from) async {
      for (var i = 1; i <= 4; i++) {
        gps.updates.add(_at(from + i * 15));
        await _frames(tester, 10);
      }
    }

    await drive(0);
    expect(pushes, greaterThan(0), reason: 'the visible car moves');
    // Ride history (or Chat, Safety…) opens over the trip.
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('covering')),
    )));
    await tester.pumpAndSettle(); // the trip is hidden once it is covered
    pushes = 0;
    await drive(60);
    expect(pushes, 0); // before: the 33 ms ticker kept pushing the car
    map.liveMarker!.removeListener(count);
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10);
    await gps.updates.close();
  });

  testWidgets('driver-u103: Create account continues only with the terms '
      'accepted and the name and email filled in', (tester) async {
    await _pumpScreen(tester, const DriverCreateAccount());
    bool enabled() =>
        tester.widget<CustomButton>(find.byType(CustomButton)).onPressed != null;
    // Before: Continue opened the phone step with nothing filled in.
    expect(enabled(), isFalse);
    await tester.enterText(find.byType(TextFormField).at(0), 'Nils Berg');
    await tester.enterText(find.byType(TextFormField).at(1), 'nils@example.se');
    await tester.pump();
    expect(enabled(), isFalse, reason: 'the terms are not accepted yet');
    await tester.tap(find.byType(CustomCheckBox));
    await tester.pump();
    expect(enabled(), isTrue);
    await tester.tap(find.byType(CustomButton));
    await _frames(tester, 12);
    expect(find.byType(DriverCreateAccountPhone), findsOneWidget);
  });

  test('driver-63: the island keeps only its newest posted messages', () {
    IslandMessages.reset();
    addTearDown(IslandMessages.reset);
    for (var i = 0; i < 1000; i++) {
      IslandMessages.show(IslandMessage(title: 'm$i'));
      IslandMessages.take();
    }
    // Before: all 1000, for the life of the app.
    expect(IslandMessages.posted.length, IslandMessages.maxPosted);
    expect(IslandMessages.posted.last.title, 'm999');
  });

  testWidgets('driver-66: a destination turned off during its route fetch '
      'does not put the driver online', (tester) async {
    SharedPreferences.setMockInitialValues({});
    DriverStartPosition.clearMemory();
    IslandMessages.reset();
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = DriverSessionController();
    final routes = _SlowRoutes();
    final gps = _Gps();
    await _pumpScreen(
      tester,
      DriverHome(
        locationRepository: gps,
        routeRepository: routes,
        sessionController: session,
      ),
    );
    await _frames(tester, 14);
    Future<void> tap(String key) async {
      await tester.tap(find.byKey(ValueKey<String>(key)));
      await _frames(tester, 10);
    }

    tester
        .widget<InkWell>(find.byKey(const ValueKey('destination-mode-open')))
        .onTap!
        .call();
    await _frames(tester, 12);
    await tap('destination-result-solna');
    await tap('destination-confirm');
    // The road route is still on its way: the driver turns it off.
    await _frames(tester, 40);
    await tap('island-destination');
    await tap('destination-mode-end');
    routes.arrive();
    await _frames(tester, 20);
    expect(session.isOnline || session.isGoingOnline, isFalse); // before: online
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, 10);
    await gps.updates.close();
  });

  testWidgets('driver-u147: Recent payouts has no See all to My bank',
      (tester) async {
    await _pumpScreen(tester, const WalletScreen());
    expect(find.text('Recent payouts'), findsOneWidget);
    expect(find.text('See all'), findsNothing); // before: opened My bank
  });

  testWidgets('driver-u153: dragging across the stars queues one notice',
      (tester) async {
    await _pumpScreen(tester, const DriverRideCompleted());
    final stars = find.byType(RatingBar);
    await tester.ensureVisible(stars);
    final box = tester.getRect(stars);
    final drag = await tester.startGesture(box.centerLeft + const Offset(8, 0));
    for (var i = 1; i <= 20; i++) {
      await drag.moveTo(box.centerLeft + Offset(8 + i * (box.width - 16) / 20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.pump();
    expect(find.text('Rating not sent (demo)'), findsOneWidget);
    // Past the first notice's 4 s, none queued behind it.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rating not sent (demo)'), findsNothing); // before: next one
  });

  testWidgets('driver-u168: a traffic switch that could not be saved goes '
      'back and says so', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(MapTrafficSetting.reset);
    await _pumpScreen(tester, Settings(repository: _FullStorage()));
    final traffic = find.byKey(const ValueKey<String>('settings-show-traffic'));
    await tester.ensureVisible(traffic);
    expect(tester.widget<Switch>(traffic).value, isTrue);
    await tester.tap(traffic);
    await _frames(tester, 4);
    // Before: Off on screen, no message, an uncaught error; On again at
    // the next start.
    expect(tester.widget<Switch>(traffic).value, isTrue);
    expect(find.text('Traffic setting not saved. Try again.'), findsOneWidget);
  });

  testWidgets('driver-99: a map whose script never loads says so',
      (tester) async {
    final probe = CustomGoogleMap.mapsReadyProbe;
    CustomGoogleMap.mapsReadyProbe = () => false; // Maps JavaScript blocked
    addTearDown(() => CustomGoogleMap.mapsReadyProbe = probe);
    await _pumpScreen(tester, const Scaffold(body: CustomGoogleMap()));
    const unavailable = ValueKey<String>('map-unavailable');
    expect(find.byKey(unavailable), findsNothing, reason: 'still loading');
    await tester.pump(CustomGoogleMap.mapsUnavailableAfter);
    await tester.pump();
    // Before: a plain land-colour box, for as long as the screen stayed.
    expect(find.text('Map unavailable. Check your connection, then reopen '
        'Movera.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
