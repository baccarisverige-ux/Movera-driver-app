import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/contracts/driver_config_parts.dart';
import 'package:movera/core/ratings/dont_match_again.dart';
import 'package:movera/core/ratings/rider_rating.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride completed/ride_completed.dart';

/// Fix job 10 (contract v0.18.40 §64, owner G16 Q16-4; G15 "Never told",
/// "No, only Support"): at 1 star the driver can tick "Don't match me with
/// this rider again"; it goes with the rating as dontMatchAgain. Nothing
/// else changes on screen and there is no undo in the app.
/// Rule 36: fails on main (no DontMatchAgain, no tick, no field).
ApiClient _api(List<http.Request> seen) {
  final tokens = MemoryTokenStore()..save(access: 'a', refresh: 'r');
  return ApiClient(
    client: MockClient((request) async {
      seen.add(request);
      return http.Response(
        jsonEncode({'ok': true}),
        201,
        headers: {'content-type': 'application/json'},
      );
    }),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: tokens,
  );
}

Future<void> _open(WidgetTester tester, List<http.Request> seen) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final session = DriverSessionController(initialOnline: true);
  addTearDown(session.dispose);
  session.beginTrip('trp_10');
  final repository = InMemoryWaybillRepository.instance;
  repository.beginCurrent(
    WaybillRecord(
      tripId: 'trp_10',
      statusLabel: WaybillRecord.nextTripSecured,
      issuedAt: DateTime(2026, 11, 6),
      fare: '128,40 kr',
      service: 'Comfort',
      riderName: 'Ida',
      pickup: 'Stockholm',
      dropoff: 'Solna',
      source: WaybillRecord.demoRadarSource,
      driverName: 'Ali',
      vehicle: 'Car',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
    ),
  );
  repository.completeCurrent();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('Home owner')),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => DriverRideCompleted(
        sessionController: session,
        waybillRepository: repository,
        ratingSender: RiderRatingSender(api: _api(seen)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _star(WidgetTester tester, int n) async {
  await tester.tap(find.byKey(ValueKey<String>('rider-rating-star-$n')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    InMemoryWaybillRepository.instance.reset();
    DontMatchAgain.current = DontMatchAgain.defaults;
  });
  tearDown(InMemoryWaybillRepository.instance.reset);

  test('DriverAppConfig.dontMatchAgain: defaults on at 1 star; served values '
      'are used; a bad value reads as the default', () {
    expect(DontMatchAgain.defaults.on, isTrue);
    expect(DontMatchAgain.defaults.atStars, 1);
    expect(DontMatchAgain.defaults.offeredAt(1), isTrue);
    expect(DontMatchAgain.defaults.offeredAt(2), isFalse);
    expect(DontMatchAgain.defaults.offeredAt(0), isFalse);
    DriverConfigParts.fromJson({
      'dontMatchAgain': {'on': true, 'atStars': 2},
    }, 'SEK').apply();
    expect(DontMatchAgain.current.offeredAt(2), isTrue);
    expect(DontMatchAgain.fromJson({'atStars': 9}).atStars, 1);
    expect(DontMatchAgain.fromJson({'on': false}).offeredAt(1), isFalse);
  });

  test('the rating body carries dontMatchAgain only when ticked', () {
    expect(RiderRatingSender.body(stars: 1, dontMatchAgain: true), {
      'stars': 1,
      'dontMatchAgain': true,
    });
    expect(RiderRatingSender.body(stars: 1), {'stars': 1});
  });

  testWidgets('the tick shows only at 1 star, is cleared above it, and is '
      'sent with the rating', (tester) async {
    final seen = <http.Request>[];
    await _open(tester, seen);
    final tick = find.byKey(const ValueKey<String>('dont-match-again'));
    expect(tick, findsNothing);
    await _star(tester, 1);
    expect(tick, findsOneWidget);
    expect(find.text("Don't match me with this rider again"), findsOneWidget);
    await tester.ensureVisible(tick);
    await tester.tap(tick);
    await tester.pumpAndSettle();
    await _star(tester, 3);
    expect(tick, findsNothing);
    await _star(tester, 1);
    expect(tick, findsOneWidget);
    expect(
      tester.widget<CheckboxListTile>(tick).value,
      isFalse,
      reason: 'more stars cleared the tick',
    );
    await tester.ensureVisible(tick);
    await tester.tap(tick);
    await tester.pumpAndSettle();
    final done = find.byType(FilledButton).last;
    await tester.ensureVisible(done);
    await tester.tap(done);
    await tester.pumpAndSettle();
    final body = jsonDecode(seen.single.body) as Map;
    expect(body['stars'], 1);
    expect(body['dontMatchAgain'], isTrue);
    // Never told, no undo: the app goes on as after any rating.
    expect(find.text('Home owner'), findsOneWidget);
  });

  testWidgets('switched off by the admin: no tick at 1 star', (tester) async {
    DontMatchAgain.current = const DontMatchAgain(on: false, atStars: 1);
    await _open(tester, <http.Request>[]);
    await _star(tester, 1);
    expect(
      find.byKey(const ValueKey<String>('dont-match-again')),
      findsNothing,
    );
  });
}
