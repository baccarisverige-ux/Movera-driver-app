import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_config_parts.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/accept%20ride/route_change_sheet.dart';

/// Driver group 7 (contract v0.18.9 `onTrip`): the server's ride check, the
/// rider's route change with the driver's Accept / Refuse, the stop waiting
/// price and the max stops, Sweden (SEK) and France (EUR).
void main() {
  tearDown(() {
    DriverAppTexts.language = 'en';
    RideCheckAdminConfig.current = const RideCheckAdminConfig();
    OnTripConfig.current = const OnTripConfig();
  });

  Map<String, dynamic> money(int minor, String currency) => {
    'amountMinor': minor,
    'currency': currency,
  };

  Map<String, dynamic> change(String status, String currency) => {
    'changeId': 'rc_1',
    'routeQuoteId': 'rq_1',
    'status': status,
    'dropoff': {'lat': 59.3383, 'lng': 17.9393, 'address': 'Brommaplan'},
    'stops': [
      {'lat': 59.3326, 'lng': 18.0296, 'address': 'Fridhemsplan'},
    ],
    'total': money(25000, currency),
    'difference': money(6000, currency),
    'askedAt': '2026-11-02T10:00:00Z',
    'answerBy': '2026-11-02T10:01:00Z',
    'driverEarnings': money(20000, currency),
    'earningsDifference': money(4800, currency),
  };

  group('1. ride check from the server', () {
    test('the projection carries the check and each side\'s answer', () {
      final live = TripLiveDetails.fromProjection({
        'tripId': 't1',
        'version': 9,
        'rideCheck': {
          'checkId': 'srv_1',
          'trigger': 'off_route',
          'askedAt': '2026-11-02T10:00:00Z',
          'answerBy': '2026-11-02T10:02:00Z',
          'answers': {'rider': 'ok'},
        },
      });
      final check = live.rideCheck!;
      expect(check.checkId, 'srv_1');
      expect(check.trigger, 'off_route');
      expect(check.riderAnswer, 'ok');
      expect(check.driverAnswer, isNull);
      expect(check.openForDriver(DateTime.utc(2026, 11, 2, 10, 1)), isTrue);
      // After answerBy the safety team is told; the card no longer opens.
      expect(check.openForDriver(DateTime.utc(2026, 11, 2, 10, 3)), isFalse);
    });

    test('an answered or unknown check does not ask the driver', () {
      final answered = TripRideCheck.tryParse({
        'checkId': 'srv_2',
        'trigger': 'long_stop',
        'answers': {'driver': 'ok'},
      });
      expect(answered!.openForDriver(DateTime.utc(2026)), isFalse);
      expect(
        TripRideCheck.tryParse({'checkId': 'x', 'trigger': 'possible_crash'}),
        isNull,
      );
    });

    test('the zone settings: on, off route 2 km, end far 500 m', () {
      DriverConfigParts.fromJson({
        'rideCheck': {
          'on': false,
          'stopMinutes': 4,
          'offRouteKm': 2,
          'endFarMeters': 500,
        },
      }, 'SEK').apply();
      final config = RideCheckAdminConfig.current;
      expect(config.on, isFalse);
      expect(config.longStopMinutes, 4);
      expect(config.offRouteKm, 2);
      expect(config.finishFarFromDropoffMeters, 500);
      final rules = RideCheckRules.fromAdmin(config);
      // Off: the app's own checks are quiet too; a crash still asks.
      expect(rules.longStop || rules.offRoute || rules.droppedFar, isFalse);
      expect(rules.possibleCrash, isTrue);
    });
  });

  group('2. route change: Accept / Refuse with the new earnings', () {
    for (final currency in ['SEK', 'EUR']) {
      test('parsed with signed earnings ($currency)', () {
        final live = TripLiveDetails.fromProjection({
          'tripId': 't1',
          'version': 9,
          'routeChange': {
            ...change('pending', currency),
            'earningsDifference': money(-1500, currency),
          },
        });
        final rc = live.routeChange!;
        expect(rc.pending, isTrue);
        expect(rc.dropoff!.address, 'Brommaplan');
        expect(rc.stops.single.address, 'Fridhemsplan');
        expect(rc.driverEarnings!.minorUnits, 20000);
        expect(signedMoneyLabel(rc.earningsDifference!), startsWith('−'));
        expect(rc.secondsLeft(DateTime.utc(2026, 11, 2, 10, 0, 20)), 40);
      });
    }

    test('zone settings: max stops and the route change switches', () {
      DriverConfigParts.fromJson({
        'booking': {'maxStops': 2},
        'routeChange': {
          'on': true,
          'driverCanRefuse': false,
          'answerSeconds': 45,
        },
      }, 'EUR').apply();
      expect(OnTripConfig.current.maxStops, 2);
      expect(OnTripConfig.current.driverCanRefuse, isFalse);
      expect(OnTripConfig.current.answerSeconds, 45);
    });

    test('accept posts the change id with the trip version', () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'tripId': 't1',
              'status': 'in_trip',
              'version': 10,
              'routeChange': change('accepted', 'SEK'),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
        baseUri: Uri.parse('https://api.example.test'),
        tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
      );
      final trips = LiveTripCommands(api: api)
        ..observe({'tripId': 't1', 'status': 'in_trip', 'version': 9});
      final outcome = await trips.answerRouteChange(
        't1',
        changeId: 'rc_1',
        accept: true,
      );
      expect(outcome.ok, isTrue);
      expect(requests.single.url.path, '/api/v1/trips/t1/route-change/accept');
      expect(jsonDecode(requests.single.body), {
        'expectedVersion': 9,
        'changeId': 'rc_1',
      });
      expect(requests.single.headers['X-Contract-Version'], '0.18.9');
      expect(trips.versionOf('t1'), 10);
    });

    for (final language in ['en', 'sv', 'fr']) {
      testWidgets('the sheet: earnings, stops, timer, buttons ($language)', (
        tester,
      ) async {
        DriverAppTexts.language = language;
        final answers = <bool>[];
        final rc = TripRouteChange.tryParse(change('pending', 'SEK'))!;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RouteChangeSheet(
                change: rc,
                maxStops: 3,
                now: () => DateTime.utc(2026, 11, 2, 10, 0, 15),
                onAnswer: (accept) async => answers.add(accept),
              ),
            ),
          ),
        );
        final earnings = tester
            .widget<Text>(find.byKey(const ValueKey('route-change-earnings')))
            .data!;
        expect(earnings, contains('200,00 kr'));
        expect(earnings, contains('+48,00 kr'));
        final stops = tester
            .widget<Text>(find.byKey(const ValueKey('route-change-stops')))
            .data!;
        expect(stops, contains('3'));
        final timer = tester
            .widget<Text>(find.byKey(const ValueKey('route-change-timer')))
            .data!;
        expect(timer, contains('45'));
        await tester.tap(find.byKey(const ValueKey('route-change-refuse')));
        await tester.pump();
        expect(answers, [false]);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('driver cannot refuse: only Accept', (tester) async {
      final rc = TripRouteChange.tryParse(change('pending', 'EUR'))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RouteChangeSheet(
              change: rc,
              maxStops: 3,
              canRefuse: false,
              now: () => DateTime.utc(2026, 11, 2, 10, 0, 15),
              onAnswer: (_) async {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('route-change-refuse')), findsNothing);
      expect(find.byKey(const ValueKey('route-change-accept')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('3. stop waiting price', () {
    test('terms.stopWaitPerMin is read in the trip currency', () {
      final live = TripLiveDetails.fromProjection({
        'tripId': 't1',
        'version': 3,
        'terms': {
          'currency': 'EUR',
          'freeWaitMin': 3,
          'waitPerMin': money(50, 'EUR'),
          'noShowFee': money(500, 'EUR'),
          'stopFreeWaitMin': 0,
          'stopWaitPerMin': money(45, 'EUR'),
        },
      });
      expect(live.terms!.stopFreeWaitMinutes, 0);
      expect(live.terms!.stopWaitPerMin!.minorUnits, 45);
    });
  });
}
