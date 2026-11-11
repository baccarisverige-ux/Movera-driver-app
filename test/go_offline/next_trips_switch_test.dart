// Contract v0.18.65 §86 (owner phone test 2026-11-11: "double check if he
// turn radar off while on trip do offers stop or not"). Before, turning the
// trip radar off only hid the on-trip Exclusives on the phone; the server
// kept sending them (each held the rider's search until it ran out). Now the
// radar's stop / start goes to the server: POST /driver/next-trips { on }.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/next_trips_switch.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}

void main() {
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  final switches = <Object?>[];
  // The server's answer to POST /driver/next-trips (null: no connection).
  int? answer;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
    NextTripsSwitch.off.value = false;
    switches.clear();
    answer = 200;
    realtime = MemoryDriverRealtime();
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/stream') || path.endsWith('/events')) {
        return http.Response('', 503);
      }
      if (request.method == 'POST' && path == '/api/v1/driver/next-trips') {
        final on = (jsonDecode(request.body) as Map)['on'];
        switches.add(on);
        final status = answer;
        if (status == null) throw http.ClientException('connection lost');
        if (status != 200) {
          return json(status, {'code': 'internal', 'message': 'No.'});
        }
        return json(200, {
          'driverId': 'd1',
          'onlineStatus': 'on_trip',
          'nextTripsOff': on != true,
          'version': 7,
        });
      }
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'in_trip',
          'version': 12,
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/offers') {
        return json(200, {'items': [], 'nextCursor': null});
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: ApiClient(
        client: client,
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: tokens,
      ),
      location: _NoGps(),
    );
    LiveDriverServices.instance = live;
  });
  tearDown(() async {
    realtime.dispose();
    LiveDriverServices.instance = null;
    await live.dispose();
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
    NextTripsSwitch.off.value = false;
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  AdaptiveTripIsland island(WidgetTester tester) =>
      tester.widget<AdaptiveTripIsland>(find.byType(AdaptiveTripIsland));

  Future<void> toggle(WidgetTester tester) async {
    island(tester).onRadar();
    await frames(tester);
  }

  Future<void> pumpTrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      DriverRuntimeScope(
        session: session,
        homeBuilder: () => const SizedBox(),
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: AcceptRide(
              tripId: 'live-trip',
              initialStage: ActiveRideStage.onTrip,
              riderName: 'Passenger',
              fare: '151,36 kr',
              riderFare: '208,00 kr',
              category: 'Economy',
              matchedVia: WaybillRecord.demoRadarSource,
              pickupAddress: 'Sergels torg',
              pickupArea: '',
              pickupPosition: const LatLng(59.3326, 18.0649),
              dropoffAddress: 'Odenplan',
              dropoffPosition: const LatLng(59.3429, 18.0498),
              locationRepository: _NoGps(),
              activeRideRepository: MemoryActiveRideRepository(),
              sessionController: session,
              waybillRepository: InMemoryWaybillRepository.instance,
              realtime: realtime,
              waitNow: () => tester.binding.clock.now(),
            ),
          ),
        ),
      ),
    );
    await frames(tester, 20);
  }

  Future<void> closeUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
  }

  testWidgets('radar off on a trip tells the server (no more next-trip '
      'offers); radar on tells it again', (tester) async {
    await pumpTrip(tester);
    expect(island(tester).radarOn, isTrue, reason: 'the trip radar starts on');
    await toggle(tester);
    expect(island(tester).radarOn, isFalse);
    expect(switches, [false], reason: 'POST /driver/next-trips {on: false}');
    expect(NextTripsSwitch.off.value, isTrue);
    await toggle(tester);
    expect(island(tester).radarOn, isTrue);
    expect(switches, [false, true]);
    expect(NextTripsSwitch.off.value, isFalse);
    await closeUp(tester);
  });

  testWidgets('the server did not hear it: the radar goes back and the '
      'driver is told', (tester) async {
    await pumpTrip(tester);
    answer = 500;
    await toggle(tester);
    expect(switches, [false]);
    expect(island(tester).radarOn, isTrue, reason: 'offers still come');
    expect(find.text(tr.authErrServer), findsNothing);
    expect(find.text(tr.nextTripsSwitchFailed), findsOneWidget);
    await closeUp(tester);
  });

  test('a profile read (after a restart) carries nextTripsOff; off a trip '
      'it is false', () {
    NextTripsSwitch.observe({'onlineStatus': 'on_trip', 'nextTripsOff': true});
    expect(NextTripsSwitch.off.value, isTrue);
    NextTripsSwitch.observe({'onlineStatus': 'online', 'nextTripsOff': true});
    expect(NextTripsSwitch.off.value, isFalse);
  });

  test('English text (sv and fr are in the area files)', () {
    expect(
      tr.nextTripsSwitchFailed,
      'Next trips could not be changed. Try again.',
    );
  });
}
