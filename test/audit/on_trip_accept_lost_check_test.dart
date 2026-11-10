// IN-DL.9 #524 (a), owner 2026-11-10 "Check real result" (global plan
// step 73; proof audits/proofs/step73/driver). On the trip screen an
// on-trip Exclusive Accept that gets no answer, and whose checks get no
// answer until after the offer's local expiry, is not called "Offer no
// longer available": the app keeps asking the server (same Accept, same
// Idempotency-Key, `GET /driver/offers/{offerId}`) and shows what it says.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
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
  late DateTime Function() now;
  final requests = <String>[];
  final keys = <String?>[];
  // What the server says once the connection is back (null: never back).
  String? serverSays;
  // When the connection comes back (set at the tap).
  DateTime? backAt;

  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  // Recorded shape of an on-trip Exclusive `Offer` (kind exclusive).
  Map<String, dynamic> nextOffer() => {
    'offerId': 'off-next',
    'tripId': 'trip-next',
    'kind': 'exclusive',
    'status': 'open',
    'version': 1,
    'expiresAt': now()
        .add(const Duration(seconds: 6))
        .toUtc()
        .toIso8601String(),
    'fare': money(8810),
    'driverEarnings': money(6400),
    'source': 'system',
    'pickup': {'address': 'Tegnérgatan', 'lat': 59.3335, 'lng': 18.0610},
    'dropoff': {'address': 'Odengatan', 'lat': 59.3428, 'lng': 18.0475},
    'categoryId': 'comfort',
    'paymentMethod': 'card',
    'pickupEtaSeconds': 180,
    'pickupMeters': 900,
    'tripSeconds': 720,
    'tripMeters': 5200,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    WaybillStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
    requests.clear();
    keys.clear();
    serverSays = null;
    backAt = null;
    realtime = MemoryDriverRealtime();
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      if (path.endsWith('/stream') || path.endsWith('/events')) {
        return http.Response('', 503);
      }
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'on_trip',
          'version': 12,
          'paymentMethod': 'card',
          'fare': money(20800),
          'driverEarnings': money(15136),
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/offers') {
        return json(200, {
          'items': [nextOffer()],
          'nextCursor': null,
        });
      }
      if (path.startsWith('/api/v1/offers/off-next') ||
          path.startsWith('/api/v1/driver/offers/off-next')) {
        if (request.method == 'POST') {
          keys.add(request.headers['Idempotency-Key']);
        }
        final back = backAt;
        if (serverSays == null || back == null || now().isBefore(back)) {
          // No answer (lost connection).
          throw const SocketException('connection lost');
        }
        final gone = {...nextOffer(), 'status': 'expired', 'version': 2};
        if (serverSays == 'expired') {
          return request.method == 'POST'
              ? json(409, {'code': 'invalid_transition', 'projection': gone})
              : json(200, {'offer': gone});
        }
        final trip = {
          'tripId': 'trip-next',
          'status': 'accepted',
          'version': 2,
          'kind': 'now',
          'nextAfterTripId': 'live-trip',
          'rider': {'firstName': 'Anna'},
          'pickup': {'address': 'Tegnérgatan', 'lat': 59.3335, 'lng': 18.061},
          'dropoff': {'address': 'Odengatan', 'lat': 59.3428, 'lng': 18.0475},
        };
        return request.method == 'POST'
            ? json(200, trip)
            : json(200, {
                'offer': {...nextOffer(), 'status': 'claimed', 'version': 2},
                'trip': trip,
              });
      }
      if (request.method == 'GET' && path == '/api/v1/trips/trip-next') {
        return json(200, {
          'tripId': 'trip-next',
          'status': 'accepted',
          'version': 2,
          'nextAfterTripId': 'live-trip',
        });
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
    WaybillStore.reset();
    DriverOfferRules.current = const DriverOfferRules();
  });

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Runs the trip screen, taps Accept on the server offer, and pumps
  /// [seconds]. True when "Offer no longer available" was ever shown.
  Future<bool> acceptLost(WidgetTester tester, {int seconds = 70}) async {
    now = () => tester.binding.clock.now();
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

    // The server's next-trip offer arrives on the offer feed.
    live.dispatch.refreshOffers();
    await frames(tester, 20);
    final accept = find.byKey(const ValueKey('on-trip-radar-match-next'));
    expect(accept, findsOneWidget, reason: 'the server offer is on screen');
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    // The connection comes back 24 s after the tap (offer's 6 s are over
    // and the first round of checks, 20 s, got no answer).
    backAt = now().add(const Duration(seconds: 24));

    // A SnackBar lasts 4 s, so look after every step.
    var saidGone = false;
    for (var i = 0; i < seconds * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Offer no longer available').evaluate().isNotEmpty) {
        saidGone = true;
      }
    }
    expect(
      requests.where((r) => r.startsWith('POST /api/v1/offers/off-next')),
      isNotEmpty,
      reason: 'the Accept was sent',
    );
    expect(keys.toSet(), hasLength(1), reason: 'the same Idempotency-Key');
    expect(
      requests.where((r) => r.startsWith('GET /api/v1/driver/offers/off-next')),
      isNotEmpty,
      reason: 'the server was asked (contract acceptCheck)',
    );
    final result = saidGone;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 30));
    return result;
  }

  testWidgets('an unanswered on-trip Accept that outlives the offer is not '
      'called "no longer available"', (tester) async {
    expect(
      await acceptLost(tester),
      isFalse,
      reason:
          'nothing proved the offer gone (no answer at all); the server '
          'may have queued this next trip for the driver',
    );
  });

  testWidgets('accepted after the timeout: the server\'s trip is his', (
    tester,
  ) async {
    serverSays = 'claimed';
    expect(await acceptLost(tester), isFalse);
    expect(live.trips.queuedAfter('live-trip')?['tripId'], 'trip-next');
  });

  testWidgets('gone after the timeout: "no longer available"', (tester) async {
    serverSays = 'expired';
    expect(await acceptLost(tester), isTrue);
    expect(live.trips.queuedAfter('live-trip'), isNull);
  });
}
