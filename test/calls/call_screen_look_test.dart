import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/calls/trip_call_session.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/common/chat/call_screen.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';

import 'in_app_call_test.dart' show FakeApi, FakeEngine;

/// Job 8 screenshot check (2026-11-05): the Call rider button was Material
/// purple, the "Call failed" bar covered Done, and on the failed call screen
/// Mute / End / Speaker still looked active.
class _NoGps implements DriverLocationRepository {
  @override
  Future<DriverLocation> getCurrentPosition() => Future.error(StateError('x'));
  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      const Stream.empty();
}

Widget _app(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, __) => MaterialApp(home: child),
);

void main() {
  testWidgets('failed call: Mute / End / Speaker look disabled', (
    tester,
  ) async {
    final bad = TripCallSession.outgoing(
      api: FakeApi()..startError = StateError('x'),
      engine: FakeEngine(),
      tripId: 't1',
      side: 'driver',
    );
    await tester.runAsync(bad.start);
    await tester.pumpWidget(_app(TripCallScreen(session: bad)));
    await tester.pump();
    for (final key in ['call-mute', 'call-end', 'call-speaker']) {
      final button = find.byKey(ValueKey<String>(key));
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      final material = tester.widget<Material>(
        find.ancestor(of: button, matching: find.byType(Material)).first,
      );
      expect(material.color, TripCallScreen.disabledColor, reason: key);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Ride completed: Call rider uses the app style and "Call '
      'failed" never covers Done', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient(
      (r) async => http.Response(
        jsonEncode({
          'code': 'invalid_transition',
          'message': 'No.',
          'reason': 'call_window_closed',
        }),
        409,
        headers: {'content-type': 'application/json'},
      ),
    );
    final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
    final api = ApiClient(
      client: client,
      baseUri: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
    );
    LiveDriverServices.instance = LiveDriverServices(
      client: client,
      origin: Uri.parse('https://api.test.movera.se'),
      tokens: tokens,
      api: api,
      location: _NoGps(),
    );
    addTearDown(() => LiveDriverServices.instance = null);
    final repo = InMemoryWaybillRepository.instance
      ..reset()
      ..beginCurrent(
        WaybillRecord(
          tripId: 'trp_1',
          statusLabel: 'In progress',
          issuedAt: DateTime(2026, 11, 5, 8, 30),
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
    await tester.pumpWidget(_app(DriverRideCompleted(waybillRepository: repo)));
    await tester.pump(const Duration(seconds: 1));
    final call = find.byKey(const ValueKey<String>('ride-completed-call'));
    final style = tester.widget<OutlinedButton>(call).style!;
    expect(
      style.foregroundColor!.resolve(<WidgetState>{}),
      const Color(0xFF111111),
      reason: 'app ink, not Material purple',
    );
    await tester.tap(call);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SnackBar), findsOneWidget);
    final bar = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    final done = find.byKey(const ValueKey<String>('ride-completed-done'));
    expect(
      tester.getRect(bar).bottom,
      lessThanOrEqualTo(tester.getRect(call).top),
      reason: 'the bar sits above the buttons',
    );
    expect(tester.getRect(bar).overlaps(tester.getRect(done)), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });
}
