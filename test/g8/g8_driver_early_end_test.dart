import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_outcome_sheet.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Live G8 2026-11-02 (3a): the DRIVER ends early; the server's
/// realtime echo must not replace the finished screen.
/// Based on: Owner, live test 2026-10-26, on a live cash trip finished 1.2 km in
/// and 5.8 km from the drop-off (the local server's own numbers):
/// - N9: the finish screen, the waybill, history and the cash balance
///   take the server's final money (40,00 kr earnings, 54,00 kr cash),
///   not the 151,36 kr / 208,00 kr booked at accept.
/// - Live bug A (owner 2026-10-29, contract v0.18.1 §26): Collect cash
///   shows the server's final price from `complete-preview` (54 kr, with
///   "Ending before the destination – price recalculated"), not the
///   booked 208 kr, and complete sends that amount as `cashCollected`.
/// - N11: the waybill names the signed-in driver and their car, the
///   pickup's address is looked up when the offer carried only its
///   coordinates, and the rider's fare is on it.
void main() {
  late List<http.Request> requests;
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  late DriverAccountSession account;
  late http.Response Function() preview;
  late List<http.Response Function()> completeAnswers;
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  final completed = <String, dynamic>{
    'tripId': 'live-trip',
    'status': 'completed',
    'version': 10,
    'fare': money(5400),
    'quote': {'quoteId': 'q', 'total': money(20800)},
    'fareLines': [
      {'code': 'base', 'amount': money(2900)},
      {'code': 'distance', 'amount': money(1735)},
      {'code': 'time', 'amount': money(32)},
      {'code': 'minimum_adjust', 'amount': money(233)},
      {'code': 'app_fee', 'amount': money(490)},
      {'code': 'rounding', 'amount': money(10)},
    ],
    'driverEarnings': money(3920),
    'commission': money(1400),
    'pickupPay': money(80),
    'paymentMethod': 'cash',
    'driverTotal': money(4000),
    'earningsBreakdown': [
      {'code': 'trip', 'amount': money(3920)},
      {'code': 'pickup', 'amount': money(80)},
    ],
    'finish': {
      'endedEarly': true,
      'endedBy': 'driver',
      'reasonCode': 'ended_before_dropoff',
      'repriced': true,
      'total': money(5400),
      'cashToCollect': money(5400),
      'driverTotal': money(4000),
      'earningsBreakdown': [
        {'code': 'trip', 'amount': money(3920)},
        {'code': 'pickup', 'amount': money(80)},
      ],
      'ratingAllowed': true,
    },
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InMemoryWaybillRepository.instance.reset();
    requests = [];
    realtime = MemoryDriverRealtime();
    completeAnswers = [];
    preview = () => json(200, {
      'previewId': 'cpv_first',
      'tripId': 'live-trip',
      'total': money(5400),
      'cashDue': money(5400),
      'driverEarnings': money(3920),
      'earlyEnd': true,
      'fareLines': completed['fareLines'],
    });
    final tokens = MemoryTokenStore()..save(access: 'a1', refresh: 'r1');
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add(request);
      if (path.endsWith('/events')) return http.Response('', 503);
      if (request.method == 'GET' && path == '/api/v1/trips/live-trip') {
        return json(200, {
          'tripId': 'live-trip',
          'status': 'in_trip',
          'version': 8,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/driver/trips/live-trip/complete-preview') {
        return preview();
      }
      if (request.method == 'POST' &&
          path == '/api/v1/trips/live-trip/complete') {
        if (completeAnswers.isNotEmpty) return completeAnswers.removeAt(0)();
        // Live G8 3a: the server's realtime `completed` echo of this
        // driver's own finish arrives while the finish is saved.
        realtime.emit(
          tripId: 'live-trip',
          kind: DriverRealtimeKind.tripProjection,
          status: TripStatus.completed,
          projection: {...completed, 'version': 11},
        );

        return json(200, completed);
      }
      if (request.method == 'GET' && path == '/api/v1/driver/profile') {
        return json(200, {
          'driverId': 'drv_1',
          'accountStatus': 'active',
          'version': 4,
          'firstName': 'Test',
          'lastName': 'Åkare',
          'vehicleId': 'veh_1',
        });
      }
      if (request.method == 'GET' && path == '/api/v1/driver/vehicles') {
        return json(200, {
          'items': [
            {
              'vehicleId': 'veh_0',
              'make': 'Toyota',
              'model': 'Corolla',
              'year': 2022,
              'color': 'White',
              'plate': 'TST 002',
              'seats': 4,
              'status': 'approved',
            },
            {
              'vehicleId': 'veh_1',
              'make': 'Volvo',
              'model': 'V60',
              'year': 2021,
              'color': 'Black',
              'plate': 'TST 001',
              'seats': 4,
              'status': 'approved',
            },
          ],
        });
      }
      if (request.method == 'POST' &&
          path == '/api/v1/locations/reverse-geocode') {
        final body = jsonDecode(request.body) as Map;
        expect(body['latitude'], 59.195885);
        expect(body['longitude'], 17.597423);
        return json(200, {
          'address': 'Klockarvägen 37, 151 62 Södertälje',
          'latitude': 59.195885,
          'longitude': 17.597423,
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
    account = DriverAccountSession(repository: DriverAccountRepository(api));
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

  Future<List<http.Request>> openCashSheet(
    WidgetTester tester, {
    bool openSheet = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = DriverSessionController(initialOnline: true);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      DriverRuntimeScope(
        session: session,
        homeBuilder: () => const SizedBox(),
        account: account,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, __) => MaterialApp(
            home: AcceptRide(
              tripId: 'live-trip',
              initialStage: ActiveRideStage.onTrip,
              riderName: 'Passenger',
              fare: '151,36 kr',
              riderFare: '208,00 kr',
              paidByCash: true,
              cashToCollect: '208,00 kr',
              category: 'Economy',
              // A live trip restored without its source.
              matchedVia: WaybillRecord.demoRadarSource,
              pickupAddress: 'Sergels torg',
              pickupArea: '',
              pickupPosition: const LatLng(59.3326, 18.0649),
              dropoffAddress: 'Klockarvägen 37, Södertälje',
              dropoffPosition: const LatLng(59.2411, 17.6031),
              locationRepository: _NoGps(),
              activeRideRepository: MemoryActiveRideRepository(),
              sessionController: session,
              waybillRepository: InMemoryWaybillRepository.instance,
              realtime: realtime,
            ),
          ),
        ),
      ),
    );
    await frames(tester, 20);
    if (!openSheet) return requests;
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
        .controller!
        .animatePanelToSnapPoint();
    await frames(tester, 16);
    final collect = find.byKey(
      const ValueKey<String>('active-ride-collect-cash'),
    );
    await tester.ensureVisible(collect);
    await tester.tap(collect);
    await frames(tester, 10);
    return requests;
  }

  Future<void> close(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final language in ['sv', 'fr']) {
    testWidgets('live G8 3a: driver ends early, the realtime completed echo '
        'still leads to the finished screen with Din andel, ended early and '
        'the rating ($language)', (tester) async {
      DriverAppTexts.language = language;
      addTearDown(() => DriverAppTexts.reset());
      final semantics = tester.ensureSemantics();
      await openCashSheet(tester);
      // Live G8 a11y: the cash sheet lines are read as "label value".
      expect(
        find.bySemanticsLabel(RegExp('^${RegExp.escape(tr.g8YourShare)} ')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('cash-collect-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('cash-complete-ride')),
      );
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(
        find.byType(TripOutcomeSheet),
        findsNothing,
        reason: 'not the old "Trip completed / OK" sheet',
      );
      expect(find.byType(DriverRideCompleted), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      final early = tester.widget<Text>(
        find.byKey(const ValueKey<String>('ride-completed-early')),
      );
      expect(early.data, contains(tr.g8EndedEarly));
      expect(early.data, contains(tr.g8DriverEnded));
      final summary = tester.widget<Text>(
        find.byKey(const ValueKey<String>('ride-completed-fare')),
      );
      expect(summary.textSpan!.toPlainText(), contains('40'));
      expect(find.byType(RatingBar), findsOneWidget);
      // Live G8 a11y: every star is named.
      for (var star = 1; star <= 5; star++) {
        expect(find.bySemanticsLabel(tr.g8StarLabel(star)), findsOneWidget);
      }
      // Live G8: never the demo radar name on a live trip.
      expect(find.textContaining(tr.waybillDemoRadar), findsNothing);
      semantics.dispose();
      await close(tester);
    });
  }

  testWidgets('live G8 fix 1: the finish save fails while the server has '
      'already completed: the driver is not stuck on the trip', (tester) async {
    DriverAppTexts.language = 'sv';
    addTearDown(() => DriverAppTexts.reset());
    await openCashSheet(tester);
    ActiveRideController.debugRefuseNextComplete = true;
    addTearDown(() => ActiveRideController.debugRefuseNextComplete = false);
    await tester.tap(find.byKey(const ValueKey<String>('cash-complete-ride')));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(
      find.byType(TripOutcomeSheet).evaluate().isNotEmpty ||
          find.byType(DriverRideCompleted).evaluate().isNotEmpty,
      isTrue,
      reason: 'the server already completed: an outcome, never the trip',
    );
    await close(tester);
  });

  testWidgets('live G8 fix 1: a completion from outside (admin) during a '
      'normal trip still shows the outcome', (tester) async {
    DriverAppTexts.language = 'sv';
    addTearDown(() => DriverAppTexts.reset());
    await openCashSheet(tester, openSheet: false);
    realtime.emit(
      tripId: 'live-trip',
      kind: DriverRealtimeKind.tripProjection,
      status: TripStatus.completed,
      projection: {
        ...completed,
        'version': 11,
        'finish': {
          ...(completed['finish'] as Map),
          'endedBy': 'admin',
          'endedEarly': false,
        },
      },
    );
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(find.byType(TripOutcomeSheet), findsOneWidget);
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
