import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_active_trip.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/trip_live_details.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Driver group 5 (contract v0.18.7 `pickupWaiting`, Rules
/// decisions/driver-g5.md): what the driver app reads from the server for
/// "going to pickup and waiting" — the rider summary (Q1), the trip's
/// terms (nothing hard-coded, owner rule 16), the server's ETA with the
/// owner's distance steps (Q4, status item 2), the fee amounts (Q6), the
/// moved pickup (status item 4) and the Google Maps / Waze choice (status
/// item 3).

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> get _pickupWaiting =>
    _json('contracts/contract.json')['pickupWaiting'] as Map<String, dynamic>;

Map<String, dynamic> _arb(String language) =>
    _json('lib/l10n/app_$language.arb');

Map<String, dynamic> _projection({String status = 'driver_to_pickup'}) => {
  'tripId': 'trp_g5',
  'version': 4,
  'status': status,
  'acceptedAt': '2026-10-31T09:00:00Z',
  'pickup': {'lat': 48.8566, 'lng': 2.3522, 'address': '1 Rue de Rivoli'},
  'dropoff': {'lat': 48.8606, 'lng': 2.3376, 'address': 'Louvre'},
  'fare': {'amountMinor': 1850, 'currency': 'EUR'},
  'driverEarnings': {'amountMinor': 1480, 'currency': 'EUR'},
  'paymentMethod': 'card',
  'categoryId': 'economy',
  'rider': {'firstName': 'Camille', 'rating': 4.87},
  'terms': {
    'currency': 'EUR',
    'freeWaitMin': 5,
    'waitPerMin': {'amountMinor': 110, 'currency': 'EUR'},
    'noShowAfterMin': 5,
    'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
    'noShowDriverSharePct': 80,
    'cancelRule': {
      'freeMin': 2,
      'type': 'fixed',
      'value': 350,
      'min': null,
      'max': null,
    },
    'cancelDriverSharePct': 80,
    'cancelAfterArrivedIsNoShow': true,
    'maxPickupMoveMeters': 200,
  },
  'eta': {
    'etaSeconds': 215,
    'distanceMeters': 1249,
    'target': 'pickup',
    'at': '2026-10-31T09:01:00Z',
    'source': 'osrm',
  },
  'waiting': {
    'arrivedAt': '2026-10-31T09:05:00Z',
    'freeUntil': '2026-10-31T09:10:00Z',
    'noShowAt': '2026-10-31T09:10:00Z',
    'chargedSeconds': 0,
    'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
    'noShowDriverShare': {'amountMinor': 492, 'currency': 'EUR'},
    'chargedSecondsNow': 90,
    'chargedSoFar': {'amountMinor': 165, 'currency': 'EUR'},
  },
};

void main() {
  setUp(() => DriverAppTexts.language = 'en');
  tearDown(() => DriverAppTexts.language = 'en');

  group('Q4: the ETA and the owner\'s distance steps', () {
    test('distanceDisplay replays fixtures/pickup_waiting.json', () {
      final cases =
          _json('contracts/fixtures/pickup_waiting.json')['distanceDisplay']
              as List;
      expect(cases, isNotEmpty);
      for (final raw in cases.cast<Map>()) {
        final shown = TripEta.distanceDisplay((raw['meters'] as num).toInt());
        expect(shown.unit, raw['unit'], reason: '${raw['meters']} m');
        expect(shown.value, raw['value'], reason: '${raw['meters']} m');
      }
    });

    test('whole minutes rounded up, at least 1; formatted per language', () {
      const eta = TripEta(
        etaSeconds: 215,
        distanceMeters: 3449,
        target: 'pickup',
      );
      expect(eta.minutes, 4);
      expect(eta.minutesLabel, '4 min');
      expect(
        const TripEta(
          etaSeconds: 1,
          distanceMeters: 3,
          target: 'dropoff',
        ).minutes,
        1,
      );
      final texts = _pickupWaiting['eta']['texts'] as Map<String, dynamic>;
      for (final (code, distance) in [
        ('sv', '3,4 km'),
        ('fr', '3,4 km'),
        ('en', '3.4 km'),
      ]) {
        DriverAppTexts.language = code;
        expect(eta.distanceLabel, distance, reason: code);
        expect(
          eta.line,
          (texts['arrivesIn'][code] as String)
              .replaceAll('{min}', '4')
              .replaceAll('{distance}', distance),
          reason: code,
        );
        expect(
          const TripEta(
            etaSeconds: 600,
            distanceMeters: 850,
            target: 'dropoff',
          ).line,
          (texts['toDropoff'][code] as String)
              .replaceAll('{min}', '10')
              .replaceAll('{distance}', '800 m'),
          reason: code,
        );
      }
    });

    test('a location event carries the ETA tick', () {
      final event = DriverRealtimeEvent.fromJson({
        'eventId': 'e9',
        'tripId': 'trp_g5',
        'sequence': 9,
        'version': 4,
        'kind': 'location',
        'occurredAt': '2026-10-31T09:01:30Z',
        'serverTime': '2026-10-31T09:01:30Z',
        'location': {'lat': 48.85, 'lng': 2.35},
        'etaSeconds': 180,
        'eta': {
          'etaSeconds': 180,
          'distanceMeters': 990,
          'target': 'pickup',
          'at': '2026-10-31T09:01:30Z',
          'source': 'estimate',
        },
      });
      expect(event.etaSeconds, 180);
      expect(event.eta?.minutes, 3);
      expect(event.eta?.distanceMeters, 990);
      expect(event.eta?.source, 'estimate');
      expect(event.live, isNull);
      // Round trip for the in-memory bus.
      final back = DriverRealtimeEvent.fromJson(event.toJson());
      expect(back.eta?.etaSeconds, 180);
      expect(back.eta?.target, 'pickup');
    });
  });

  group('the projection of v0.18.7', () {
    test('rider, terms in the zone currency, ETA, waiting, pickup', () {
      final live = TripLiveDetails.fromProjection(_projection());
      expect(live.rider?.firstName, 'Camille');
      expect(live.rider?.rating, 4.87);
      expect(live.rider?.shownRating, '4.9');
      final terms = live.terms!;
      expect(terms.currency, 'EUR');
      expect(terms.waiting.freeMinutes, 5);
      expect(terms.waiting.perMinute.formatted, '1,10 €');
      expect(terms.waiting.noShowFee.formatted, '6,15 €');
      expect(terms.waiting.driverShareNoShowPercent, 80);
      expect(terms.waiting.driverNoShowFee.formatted, '4,92 €');
      expect(terms.cancelFreeMinutes, 2);
      expect(terms.cancelAfterArrivedIsNoShow, isTrue);
      expect(terms.maxPickupMoveMeters, 200);
      expect(live.eta?.minutes, 4);
      expect(live.eta?.toPickup, isTrue);
      expect(live.waiting?.noShowDriverShare?.formatted, '4,92 €');
      expect(live.waiting?.chargedSecondsNow, 90);
      expect(live.waiting?.chargedSoFar?.formatted, '1,65 €');
      expect(live.pickup?.address, '1 Rue de Rivoli');
      expect(live.cancellation, isNull);
    });

    test('a rider with no name is "Rider"; no rating → no chip', () {
      final live = TripLiveDetails.fromProjection({
        ..._projection(),
        'rider': {'firstName': 'Rider'},
      });
      expect(live.rider?.firstName, 'Rider');
      expect(live.rider?.rating, isNull);
      expect(live.rider?.shownRating, isNull);
      expect(
        TripLiveDetails.fromProjection({
          ..._projection(),
          'rider': {'firstName': ''},
        }).rider,
        isNull,
      );
    });

    test('a cancel after arrival says no_show and the driver share', () {
      final live = TripLiveDetails.fromProjection({
        ..._projection(status: 'cancelled_by_rider'),
        'cancellation': {
          'actor': 'rider',
          'reasonCode': 'plans_changed',
          'at': '2026-10-31T09:12:00Z',
          'fee': {'amountMinor': 615, 'currency': 'EUR'},
          'feeStatus': 'paid',
          'feeKind': 'no_show',
          'driverShare': {'amountMinor': 492, 'currency': 'EUR'},
        },
      });
      final cancellation = live.cancellation!;
      expect(cancellation.isNoShowFee, isTrue);
      expect(cancellation.fee?.formatted, '6,15 €');
      expect(cancellation.driverEarns?.formatted, '4,92 €');
      // No fee (inside the free minutes): nothing owed, decided.
      final free = TripCancellationInfo.tryParse({
        'actor': 'rider',
        'fee': null,
      })!;
      expect(free.fee, isNull);
      expect(free.feeKind, isNull);
      expect(free.driverEarns, isNull);
    });

    test('a newer projection keeps what it leaves out', () {
      final first = TripLiveDetails.fromProjection(_projection());
      final tick = TripLiveDetails(
        eta: const TripEta(
          etaSeconds: 60,
          distanceMeters: 80,
          target: 'pickup',
        ),
      ).merge(first);
      expect(tick.eta?.distanceMeters, 80);
      expect(tick.rider?.firstName, 'Camille');
      expect(tick.terms?.currency, 'EUR');
    });

    test('the restored trip takes the rider summary from the server', () {
      final snapshot = LiveActiveTrip.snapshotOf(_projection())!;
      expect(snapshot.riderName, 'Camille');
      expect(snapshot.riderRating, 4.87);
      expect(snapshot.pickupAddress, '1 Rue de Rivoli');
    });
  });

  group('status item 4: pickup_moved', () {
    test('is a realtime kind, before terminal only', () {
      expect(DriverRealtimeKind.tryParse('pickup_moved'), isNotNull);
      final gate = DriverRealtimeSequenceGate();
      DriverRealtimeEvent moved(int sequence, String status) =>
          DriverRealtimeEvent.fromJson({
            'eventId': 'm$sequence',
            'tripId': 'trp_g5',
            'sequence': sequence,
            'version': sequence,
            'kind': 'pickup_moved',
            'occurredAt': '2026-10-31T09:02:00Z',
            'serverTime': '2026-10-31T09:02:00Z',
            'projection': {
              ..._projection(status: status),
              'pickup': {'lat': 48.857, 'lng': 2.353, 'address': 'Rue 2'},
            },
          });
      final first = moved(1, 'driver_to_pickup');
      expect(gate.evaluate(first), DriverRealtimeDisposition.accepted);
      expect(first.status, TripStatus.driverToPickup);
      expect(first.live?.pickup?.address, 'Rue 2');
      expect(first.live?.pickup?.point.latitude, 48.857);
      gate.evaluate(
        DriverRealtimeEvent.fromJson({
          'eventId': 'c2',
          'tripId': 'trp_g5',
          'sequence': 2,
          'version': 2,
          'kind': 'rider_cancelled',
          'occurredAt': '2026-10-31T09:03:00Z',
          'serverTime': '2026-10-31T09:03:00Z',
          'projection': {'status': 'cancelled_by_rider'},
        }),
      );
      expect(
        gate.evaluate(moved(3, 'cancelled_by_rider')),
        DriverRealtimeDisposition.blockedAfterTerminal,
      );
    });

    test('the pickup move default is 200 m, as the contract says', () {
      expect(ZoneDefaults.maxPickupMoveMeters, 200);
      expect(_pickupWaiting['pickupMove']['default'], 200);
      expect(
        DriverAppConfig.fromJson({'currency': 'SEK'}).maxPickupMoveMeters,
        200,
      );
    });
  });

  group('prices from the server only (owner rule 16)', () {
    test('no server terms: no prices at all (time only)', () {
      const base = WaitingRules();
      expect(base.base.pricesKnown, isFalse);
      expect(base.base.perMinute.isZero, isTrue);
      expect(base.base.noShowFee.isZero, isTrue);
      expect(
        DriverAppConfig.fromJson({'currency': 'SEK'}).waiting.base.pricesKnown,
        isFalse,
      );
      expect(
        TripLiveDetails.fromProjection(
          _projection(),
        ).terms!.waiting.pricesKnown,
        isTrue,
      );
    });

    test('the app has no far-pickup, airport or event rule of its own', () {
      const rules = WaitingRules();
      final base = rules.termsFor();
      for (final terms in [
        rules.termsFor(pickupKm: 40),
        rules.termsFor(type: WaitingRideType.airport),
        rules.termsFor(type: WaitingRideType.event),
        rules.termsFor(category: 'Premium'),
      ]) {
        expect(terms.freeMinutes, base.freeMinutes);
        expect(terms.noShowAfterMinutes, base.noShowAfterMinutes);
        expect(terms.perMinute, base.perMinute);
        expect(terms.noShowFee, base.noShowFee);
        expect(terms.rule, '');
      }
    });

    test('a served French document gives EUR terms, byCategory kept', () {
      final config = DriverAppConfig.fromJson({
        'zoneId': 'FR-PC',
        'currency': 'EUR',
        'waiting': {
          'freeWaitMin': 5,
          'perMin': {'amountMinor': 110, 'currency': 'EUR'},
          'noShowAfterMin': 5,
          'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
          'driverSharePct': 80,
          'driverShareWaitPct': 100,
          'cancelAfterArrivedIsNoShow': true,
          'byCategory': {
            'xl': {
              'freeWaitMin': 3,
              'perMin': {'amountMinor': 150, 'currency': 'EUR'},
              'noShowAfterMin': 3,
              'noShowFee': {'amountMinor': 615, 'currency': 'EUR'},
            },
          },
          // Never read: the server does not know these (G6 item 1).
          'farPickup': {
            'km': 5,
            'freeWaitMin': 1,
            'noShowFee': {'amountMinor': 8500, 'currency': 'EUR'},
          },
          'rideTypes': {
            'airport': {'freeWaitMin': 15, 'noShowAfterMin': 20},
          },
        },
      });
      final waiting = config.waiting;
      expect(waiting.base.perMinute.formatted, '1,10 €');
      expect(waiting.base.noShowFee.formatted, '6,15 €');
      expect(waiting.base.driverNoShowFee.formatted, '4,92 €');
      expect(waiting.termsFor(category: 'xl').freeMinutes, 3);
      expect(waiting.termsFor(category: 'xl').perMinute.formatted, '1,50 €');
      expect(waiting.termsFor(pickupKm: 9).noShowFee.formatted, '6,15 €');
      expect(
        waiting.termsFor(type: WaitingRideType.airport).noShowAfterMinutes,
        5,
      );
    });
  });

  group('status item 3: Google Maps or Waze', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      NavigationAppSetting.reset();
    });
    tearDown(NavigationAppSetting.reset);

    test('directions links per app', () {
      expect(
        NavigationApp.googleMaps.directionsTo(59.33, 18.07).toString(),
        'https://www.google.com/maps/dir/?api=1'
        '&destination=59.33,18.07&travelmode=driving',
      );
      final waze = NavigationApp.waze.directionsTo(59.33, 18.07);
      expect(waze.host, 'waze.com');
      expect(waze.queryParameters['ll'], '59.33,18.07');
      expect(waze.queryParameters['navigate'], 'yes');
    });

    test('Google Maps by default; the choice is saved and read back', () async {
      final repository = SettingsRepository();
      expect(
        await NavigationAppSetting.load(repository),
        NavigationApp.googleMaps,
      );
      expect(
        await NavigationAppSetting.save(NavigationApp.waze, repository),
        isTrue,
      );
      expect(NavigationAppSetting.current.value, NavigationApp.waze);
      NavigationAppSetting.reset();
      expect(await NavigationAppSetting.load(repository), NavigationApp.waze);
      expect(NavigationApp.parse('nonsense'), NavigationApp.googleMaps);
    });
  });

  test('the app texts are the contract texts in sv, fr and en', () {
    final texts = {
      'noShowConfirmYouGet':
          _pickupWaiting['feeAmountsShown']['texts']['noShowConfirm'],
      'noShowConfirmNoFee':
          _pickupWaiting['feeAmountsShown']['texts']['noShowConfirmNoFee'],
      'feeKindNoShow':
          _pickupWaiting['feeAmountsShown']['texts']['riderNoShowFee'],
      'feeKindCancel': _pickupWaiting['feeAmountsShown']['texts']['riderFee'],
      'etaArrivesIn': _pickupWaiting['eta']['texts']['arrivesIn'],
      'etaToDropoff': _pickupWaiting['eta']['texts']['toDropoff'],
      'pickupMovedIsland': _pickupWaiting['pickupMove']['texts']['island'],
      'cancelAfterArrivedNote':
          _pickupWaiting['terms']['texts']['cancelAfterArrived'],
    };
    for (final language in ['sv', 'fr', 'en']) {
      final arb = _arb(language);
      for (final entry in texts.entries) {
        expect(
          arb[entry.key],
          (entry.value as Map)[language],
          reason: '$language ${entry.key}',
        );
      }
    }
    // The follow rule the trip screen keeps: 10 s, never under 5.
    expect(_pickupWaiting['follow']['pollSeconds'], 10);
    expect(_pickupWaiting['follow']['minPollSeconds'], 5);
    DriverAppTexts.language = 'sv';
    expect(tr.pickupMovedIsland, 'Upphämtningen flyttades');
  });
}
