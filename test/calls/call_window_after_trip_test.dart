import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';

import '../../integration_test/headless_map_platform.dart';

/// v0.18.113 BQ-S13 (owner 2026-11-01 "Keep call open for 1 hour but not
/// chat", Rules decisions/driver-g9.md:38): the finished trip shows "Call
/// rider" until the server's `callOpenUntil` (drop-off + the country's
/// callWindowAfterTripMin), and hides it by itself after; no
/// `callOpenUntil` (calls off) → no button.
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() => Future.error(StateError('x'));
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

/// The live services answer GET /api/v1/trips/{id} with [callOpenUntil]
/// (left out when null); every other read is 404.
void _live(DateTime? callOpenUntil, List<String> reads) {
  final client = MockClient((r) async {
    reads.add('${r.method} ${r.url.path}');
    if (r.method == 'GET' && r.url.path == '/api/v1/trips/trp_1') {
      return http.Response(
        jsonEncode({
          'tripId': 'trp_1',
          'status': 'completed',
          'callOpenUntil': ?callOpenUntil?.toUtc().toIso8601String(),
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({'code': 'not_found', 'message': 'No.'}),
      404,
      headers: {'content-type': 'application/json'},
    );
  });
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  LiveDriverServices.instance = LiveDriverServices(
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
}

Widget _app(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, _) => MaterialApp(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

WaybillRepository _finished() => InMemoryWaybillRepository.instance
  ..reset()
  ..beginCurrent(
    WaybillRecord(
      tripId: 'trp_1',
      statusLabel: 'In progress',
      issuedAt: DateTime.now().subtract(const Duration(minutes: 20)),
      fare: '180,00 kr',
      service: 'Comfort',
      riderName: 'Ida',
      pickup: 'A',
      dropoff: 'B',
      source: 'Rider app',
      driverName: 'Sara',
      vehicle: 'Volvo',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
    ),
  )
  ..completeCurrent();

final _record = TripHistoryRecord(
  tripId: 'trp_1',
  riderName: 'Ida',
  whenLabel: 'today',
  pickup: 'A, Stockholm',
  dropoff: 'B, Stockholm',
  fare: '180,00 kr',
  paymentMethod: 'Cash',
  category: 'Comfort',
  status: TripStatus.completed,
  completedAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
}

final _call = find.byKey(const ValueKey<String>('ride-completed-call'));
final _historyCall = find.byKey(const ValueKey<String>('history-call-rider'));

void main() {
  setUp(() => DriverAppTexts.language = 'en');
  tearDown(() => LiveDriverServices.instance = null);

  Future<void> history(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    await tester.pumpWidget(
      _app(
        DriverRideHistoryDetail(
          record: _record,
          loadRideChecks: (_) async => const [],
          loadPath: (_) async => null,
          loadTip: (_) async => null,
        ),
      ),
    );
    await _settle(tester);
  }

  testWidgets('Trip finished: Call rider while callOpenUntil is ahead, '
      'gone by itself when it passes', (tester) async {
    final reads = <String>[];
    _live(DateTime.now().add(const Duration(minutes: 5)), reads);
    await tester.pumpWidget(
      _app(DriverRideCompleted(waybillRepository: _finished())),
    );
    await _settle(tester);
    expect(reads, contains('GET /api/v1/trips/trp_1'));
    expect(_call, findsOneWidget);
    expect(find.text('Call rider'), findsOneWidget);
    await tester.pump(const Duration(minutes: 6));
    expect(_call, findsNothing, reason: 'the window closed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Trip finished: no callOpenUntil (calls off) → no Call rider', (
    tester,
  ) async {
    _live(null, <String>[]);
    await tester.pumpWidget(
      _app(DriverRideCompleted(waybillRepository: _finished())),
    );
    await _settle(tester);
    expect(_call, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Trip finished: callOpenUntil already passed → no Call rider', (
    tester,
  ) async {
    _live(DateTime.now().subtract(const Duration(minutes: 1)), <String>[]);
    await tester.pumpWidget(
      _app(DriverRideCompleted(waybillRepository: _finished())),
    );
    await _settle(tester);
    expect(_call, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ride history: a trip that ended 5 min ago shows Call rider '
      'until callOpenUntil', (tester) async {
    _live(DateTime.now().add(const Duration(minutes: 55)), <String>[]);
    await history(tester);
    expect(_historyCall, findsOneWidget);
    expect(find.text('Call rider'), findsOneWidget);
    await tester.pump(const Duration(minutes: 56));
    expect(_historyCall, findsNothing, reason: 'the window closed');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ride history: no callOpenUntil → no Call rider', (tester) async {
    _live(null, <String>[]);
    await history(tester);
    expect(_historyCall, findsNothing);
    expect(find.text('Call rider'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
