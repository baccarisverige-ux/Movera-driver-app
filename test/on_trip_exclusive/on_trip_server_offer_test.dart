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
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/next_trip.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Owner-approved fix 2026-11-08 (proof: Rules/audits/screens-2026-11-08/
/// on-trip-exclusive/): the server offers a driver ON A TRIP an Exclusive
/// next trip (a live ride queued behind this one, or a booked ride held for
/// later). It comes on the driver's offer feed, but on main the trip screen
/// never showed it (accept_ride_trip_next.dart returned early in live
/// builds and nothing read the server's offers), and so it could not be
/// accepted, nor its Next card shown.
void main() {
  final t0 = DateTime.utc(2026, 11, 8, 12);
  late DateTime clock;
  late List<http.Request> requests;
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  late Map<String, dynamic> queuedTrip;
  var sequence = 0;

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };

  Map<String, dynamic> offer({
    String id = 'off-2',
    String trip = 'trip-2',
    int expiresIn = 20,
    bool booked = false,
  }) => {
    'offerId': id,
    'tripId': trip,
    'kind': 'exclusive',
    'status': 'open',
    'version': 1,
    'expiresAt': t0.add(Duration(seconds: expiresIn)).toIso8601String(),
    'fare': money(14000),
    'driverEarnings': money(11200),
    'pickupPay': money(1500),
    'pickup': {'address': 'Odenplan 1, Stockholm', 'lat': 59.343, 'lng': 18.05},
    'dropoff': {'address': 'Slussen, Stockholm', 'lat': 59.319, 'lng': 18.072},
    'stops': <Object>[],
    'categoryId': 'economy',
    'paymentMethod': 'card',
    'pickupEtaSeconds': 300,
    'pickupMeters': 1800,
    'tripSeconds': 840,
    'tripMeters': 5200,
    'riderRating': 4.8,
    'riderTrips': 3,
    if (booked) ...{
      'reservation': true,
      'scheduledAt': t0.add(const Duration(minutes: 50)).toIso8601String(),
    },
  };

  void feed(Map<String, dynamic> offer, {String kind = 'offer_created'}) =>
      live.dispatch.ingest({
        'eventId': 'e${++sequence}',
        'sequence': sequence,
        'kind': kind,
        'occurredAt': t0.toIso8601String(),
        'serverTime': t0.toIso8601String(),
        'offer': offer,
      });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    clock = t0;
    sequence = 0;
    requests = [];
    realtime = MemoryDriverRealtime();
    queuedTrip = {
      'tripId': 'trip-2',
      'status': 'accepted',
      'version': 2,
      'kind': 'now',
      'nextAfterTripId': 'live-trip',
      'rider': {'firstName': 'Anna'},
      'pickup': {
        'address': 'Odenplan 1, Stockholm',
        'lat': 59.343,
        'lng': 18.05,
      },
      'dropoff': {
        'address': 'Slussen, Stockholm',
        'lat': 59.319,
        'lng': 18.072,
      },
    };
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add(request);
      if (path.endsWith('/events') || path.endsWith('/stream')) {
        return http.Response('', 503);
      }
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'in_trip',
          'version': 8,
        });
      }
      if (request.method == 'POST' && path == '/api/v1/offers/off-2/accept') {
        return json(200, queuedTrip);
      }
      if (request.method == 'GET' && path == '/api/v1/trips/trip-2') {
        return json(200, queuedTrip);
      }
      if (request.method == 'POST' && path == '/api/v1/offers/off-2/decline') {
        return json(200, {...offer(), 'status': 'declined', 'version': 2});
      }
      return json(404, {'code': 'not_found', 'message': 'No.'});
    });
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    live = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: _NoGps(),
    );
    LiveDriverServices.instance = live;
  });
  tearDown(() async {
    realtime.dispose();
    LiveDriverServices.instance = null;
    await live.dispose();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openTrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          home: AcceptRide(
            tripId: 'live-trip',
            initialStage: ActiveRideStage.onTrip,
            riderName: 'Passenger',
            fare: '151,36 kr',
            category: 'Economy',
            matchedVia: WaybillRecord.demoRadarSource,
            pickupAddress: 'Sergels torg',
            pickupArea: '',
            pickupPosition: const LatLng(59.3326, 18.0649),
            dropoffAddress: 'Vasagatan 1, Stockholm',
            dropoffPosition: const LatLng(59.3313, 18.0580),
            locationRepository: _NoGps(),
            activeRideRepository: MemoryActiveRideRepository(),
            sessionController: session,
            waybillRepository: InMemoryWaybillRepository.instance,
            realtime: realtime,
            waitNow: () => clock,
          ),
        ),
      ),
    );
    await frames(tester, 20);
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  final card = find.byKey(const ValueKey<String>('on-trip-radar-offer-button'));
  final accept = find.byKey(const ValueKey<String>('on-trip-radar-match-next'));
  final deny = find.byKey(const ValueKey<String>('on-trip-radar-deny'));
  List<String> posts() => [
    for (final r in requests)
      if (r.method == 'POST') r.url.path,
  ];

  testWidgets('a server Exclusive offer while on the trip shows on the '
      'next-trip card with its own time; Accept is sent to the server and the '
      'Next card shows the queued trip', (tester) async {
    DriverAppTexts.language = 'en';
    addTearDown(() => DriverAppTexts.reset());
    await openTrip(tester);
    expect(card, findsNothing);

    feed(offer());
    await frames(tester);
    expect(card, findsOneWidget, reason: 'the offer is shown on the trip');
    expect(find.text('Odenplan 1, Stockholm'), findsOneWidget);
    // The server's own time (20 s), the Exclusive mark, its pickup pay in
    // the driver's total (112 + 15 kr).
    expect(find.text(tr.exclusiveSecondsS(20)), findsOneWidget);
    expect(find.textContaining('127'), findsWidgets);

    await tester.tap(accept);
    await frames(tester, 20);
    expect(posts(), contains('/api/v1/offers/off-2/accept'));
    expect(card, findsNothing);
    // The accepted trip, as the server answered it (nextAfterTripId).
    expect(live.trips.queuedAfter('live-trip')?['tripId'], 'trip-2');

    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .open();
    await frames(tester, 16);
    expect(
      find.byKey(const ValueKey<String>('next-trip-card')),
      findsOneWidget,
      reason: 'the trip sheet shows the Next card from the server data',
    );
    expect(find.text(tr.nextTripAfterThis('Anna')), findsOneWidget);
    // After this trip the "Your next trip" popup reads this queued trip.
    final popup = nextTripOfProjection({
      ...queuedTrip,
      'status': 'driver_to_pickup',
    }, queued: NextTrip.fromQueued(live.trips.queuedAfter('live-trip')));
    expect(popup?.riderName, 'Anna');
    expect(popup?.booked, isFalse);
    await close(tester);
  });

  testWidgets('No declines the server offer; a run-out one only goes away', (
    tester,
  ) async {
    DriverAppTexts.language = 'en';
    addTearDown(() => DriverAppTexts.reset());
    await openTrip(tester);
    feed(offer());
    await frames(tester);
    expect(card, findsOneWidget);
    await tester.tap(deny);
    await frames(tester);
    expect(card, findsNothing);
    expect(posts(), contains('/api/v1/offers/off-2/decline'));

    // A second offer is shown (one No is for that offer only) and runs out.
    feed(offer(id: 'off-3', trip: 'trip-3', expiresIn: 8));
    await frames(tester);
    expect(card, findsOneWidget);
    clock = t0.add(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 9));
    await frames(tester);
    expect(card, findsNothing);
    expect(posts().where((p) => p.contains('off-3')), isEmpty);
    await close(tester);
  });

  testWidgets('a booked ride offered while on the trip shows and is '
      'accepted the same way', (tester) async {
    DriverAppTexts.language = 'en';
    addTearDown(() => DriverAppTexts.reset());
    queuedTrip = {
      ...queuedTrip,
      'kind': 'scheduled',
      'reservation': {'held': true},
    }..remove('nextAfterTripId');
    await openTrip(tester);
    feed(offer(booked: true));
    await frames(tester);
    expect(card, findsOneWidget);
    await tester.tap(accept);
    await frames(tester, 20);
    expect(posts(), contains('/api/v1/offers/off-2/accept'));
    expect(card, findsNothing);
    await close(tester);
  });

  testWidgets('an offer withdrawn by the server leaves the trip screen', (
    tester,
  ) async {
    DriverAppTexts.language = 'en';
    addTearDown(() => DriverAppTexts.reset());
    await openTrip(tester);
    feed(offer());
    await frames(tester);
    expect(card, findsOneWidget);
    feed({...offer(), 'status': 'claimed_elsewhere'}, kind: 'offer_withdrawn');
    await frames(tester);
    expect(card, findsNothing);
    expect(posts().where((p) => p.contains('off-2')), isEmpty);
    await close(tester);
  });
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
