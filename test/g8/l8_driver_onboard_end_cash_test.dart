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
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Finder L8 (owner 2026-11-07, LIFECYCLE.md): the DRIVER ends the trip
/// with the rider on board ("End trip early" + a reason). The server books
/// the cash as collected (`cancelled_by_driver`, `payment_status: captured`,
/// `cash_collected_minor: 7700`) and its answer carries
/// `finish.cashToCollect` 77 kr and `driverTotal` 57,18 kr.
/// Before: a snackbar and Home, no amount. Now: the same cash sheet as the
/// rider's early end, with the server's amount and the owner's subtitle
/// ("You ended the trip early"), then the finished screen; the journal
/// keeps the server's money.
void main() {
  late List<http.Request> requests;
  late MemoryDriverRealtime realtime;
  late LiveDriverServices live;
  late DriverAccountSession account;
  Map<String, dynamic> money(int minor) => {
    'amountMinor': minor,
    'currency': 'SEK',
  };
  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  final cancelled = <String, dynamic>{
    'tripId': 'live-trip',
    'status': 'cancelled_by_driver',
    'version': 9,
    'fare': money(7700),
    'quote': {'quoteId': 'q', 'total': money(21700)},
    'driverEarnings': money(5718),
    'commission': money(1982),
    'paymentMethod': 'cash',
    'cashToCollect': money(7700),
    'driverTotal': money(5718),
    'earningsBreakdown': [
      {'code': 'trip', 'amount': money(5718)},
    ],
    'finish': {
      'endedEarly': true,
      'endedBy': 'driver',
      'reasonCode': 'rider_requested_early_end',
      'repriced': true,
      'total': money(7700),
      'cashToCollect': money(7700),
      'driverTotal': money(5718),
      'earningsBreakdown': [
        {'code': 'trip', 'amount': money(5718)},
      ],
      'ratingAllowed': true,
    },
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    InMemoryWaybillRepository.instance.reset();
    requests = [];
    realtime = MemoryDriverRealtime();
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
      if (request.method == 'POST' &&
          path == '/api/v1/trips/live-trip/cancel') {
        return json(200, cancelled);
      }
      if (request.method == 'GET' && path == '/api/v1/driver/profile') {
        return json(200, {
          'driverId': 'drv_1',
          'accountStatus': 'active',
          'version': 4,
          'firstName': 'Test',
          'lastName': 'Åkare',
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

  Future<void> endTripEarly(WidgetTester tester) async {
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
              fare: '158,41 kr',
              riderFare: '217,00 kr',
              paidByCash: true,
              cashToCollect: '217,00 kr',
              category: 'Economy',
              matchedVia: WaybillRecord.exclusiveOfferSource,
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
    await tester.tap(find.byTooltip(tr.tripRouteAndOptions).hitTestable());
    await frames(tester, 6);
    final cancel = find.byKey(
      const ValueKey<String>('active-ride-cancel-option'),
    );
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await frames(tester, 6);
    await tester.tap(
      find.byKey(
        const ValueKey<String>('trip-cancel-reason-rider_requested_early_end'),
      ),
    );
    await frames(tester, 6);
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-trip-cancellation')),
    );
    await frames(tester, 20);
  }

  for (final language in ['sv', 'fr']) {
    testWidgets('L8: driver ends the trip on board: the cash sheet shows the '
        'server\'s 77 kr and "you ended early", then the finished screen '
        '($language)', (tester) async {
      DriverAppTexts.language = language;
      addTearDown(() => DriverAppTexts.reset());
      await endTripEarly(tester);
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/cancel'),
        ),
        hasLength(1),
      );
      // Before the fix: a snackbar and Home, no amount (L8).
      expect(
        find.byKey(const ValueKey<String>('cash-collect-sheet')),
        findsOneWidget,
        reason: 'the driver must see what to collect',
      );
      final subtitle = tester.widget<Text>(
        find.byKey(const ValueKey<String>('cash-collect-subtitle')),
      );
      expect(subtitle.data, tr.driverEndedEarlyCollect);
      expect(
        subtitle.data,
        language == 'fr'
            ? 'Vous avez terminé la course plus tôt'
            : 'Du avslutade resan tidigare',
      );
      // The server's amount (finish.cashToCollect), never the booked 217.
      expect(find.textContaining('77'), findsWidgets);
      expect(find.textContaining('217'), findsNothing);
      // The trip is already over on the server: no "Not yet".
      expect(find.byKey(const ValueKey<String>('cash-not-yet')), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('cash-complete-ride')),
      );
      await frames(tester, 40);
      expect(find.byType(DriverRideCompleted), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      final fare = tester.widget<Text>(
        find.byKey(const ValueKey<String>('ride-completed-fare')),
      );
      expect(fare.textSpan!.toPlainText(), contains('57'));
      final early = tester.widget<Text>(
        find.byKey(const ValueKey<String>('ride-completed-early')),
      );
      expect(early.data, contains(tr.g8DriverEnded));

      // The journal keeps the server's money.
      final last = InMemoryWaybillRepository.instance.last!;
      expect(last.tripId, 'live-trip');
      expect(last.fare, contains('57,18'));
      expect(last.riderFare, contains('77'));
      expect(last.endedEarlyBy, 'driver');
      final rows = await tester.runAsync(
        () => PrefsTripHistoryRepository().list(),
      );
      final row = rows!.singleWhere((r) => r.tripId == 'live-trip');
      expect(row.status, TripStatus.cancelledByDriver);
      expect(row.cancellationActor, 'driver');
      expect(row.cashCollected, contains('77'));
      expect(row.fare, contains('57,18'));

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}

class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() =>
      Completer<DriverLocation>().future;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream<DriverLocation>.empty();
}
