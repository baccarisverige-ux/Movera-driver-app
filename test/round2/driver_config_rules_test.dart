import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/contracts/driver_trip_gateway.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';

/// Round 2 driver features read from `DriverAppConfig` (contract 0.4.0,
/// owner Q12, Q16–Q18, Q41–Q46).
void main() {
  tearDown(() {
    WaitingRules.current = const WaitingRules();
    DriverOfferRules.current = const DriverOfferRules();
    ExclusiveAnswers.instance.reset();
  });

  group('Q41: no-show wait = free wait', () {
    const rules = WaitingRules();

    test('defaults: 5 min, XL 3 min (contract configDefaults)', () {
      final normal = rules.termsFor(category: 'economy');
      expect(normal.freeMinutes, 5);
      expect(normal.noShowAfterMinutes, 5);
      for (final xl in ['xl', 'Movera XL', 'XL']) {
        final terms = rules.termsFor(category: xl);
        expect(terms.freeMinutes, 3, reason: xl);
        expect(terms.noShowAfterMinutes, 3, reason: xl);
      }
    });

    test('a category that sets only its free wait brings its no-show', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'SEK',
        'waiting': {
          'freeWaitMin': 5,
          'noShowAfterMin': 5,
          'byCategory': {
            'pet': {'freeWaitMin': 4},
          },
        },
      });
      final pet = config.waiting.termsFor(category: 'pet');
      expect(pet.freeMinutes, 4);
      expect(pet.noShowAfterMinutes, 4);
    });

    test('never a no-show before the free wait ends', () {
      addTearDown(
        () => ScheduledRideRules.current = const ScheduledRideRules(),
      );
      ScheduledRideRules.current = const ScheduledRideRules(
        includedWaitingMinutes: 7,
      );
      final terms = rules.termsFor(
        category: 'xl',
        type: WaitingRideType.scheduled,
      );
      expect(terms.freeMinutes, 7);
      expect(terms.noShowAfterMinutes, 7);
      expect(terms.rule, 'XL · Scheduled ride');
    });
  });

  group('Q42/Q43: waiting fee', () {
    test('per minute from the config, counted by the second', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'SEK',
        'waiting': {
          'freeWaitMin': 5,
          'perMin': {'amountMinor': 500, 'currency': 'SEK'},
          'noShowAfterMin': 5,
          'driverShareWaitPct': 100,
        },
      });
      final terms = config.waiting.termsFor(category: 'economy');
      expect(terms.waitingFee(0).isZero, isTrue);
      expect(terms.waitingFee(60).formatted, '5,00 kr');
      expect(terms.waitingFee(90).formatted, '7,50 kr');
      // 100% to the driver.
      expect(terms.driverWaitingFee(90), terms.waitingFee(90));
    });

    test('the seed rate: 12,26 kr / min, 90 s = 18,39 kr', () {
      final terms = const WaitingRules().termsFor();
      expect(terms.waitingFee(90).formatted, '18,39 kr');
      expect(terms.driverShareWaitPercent, 100);
    });

    test('a TND fee keeps millimes', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'TND',
        'waiting': {
          'freeWaitMin': 5,
          'perMin': {'amountMinor': 300, 'currency': 'TND'},
        },
      });
      final fee = config.waiting.base.waitingFee(30);
      expect(fee, const Money(minorUnits: 150, currency: 'TND'));
    });

    test('added to a fare label in the same form', () {
      const fee = Money(minorUnits: 1839);
      expect(WaitingTerms.addFee('100,00 kr', fee), '118,39 kr');
      expect(
        WaitingTerms.addFee('104,80 kr', const Money(minorUnits: 0)),
        '104,80 kr',
      );
      // Not readable as SEK: left as it is, never a wrong total.
      expect(WaitingTerms.addFee('—', fee), '—');
      expect(
        WaitingTerms.addFee(
          '100,00 kr',
          const Money(minorUnits: 500, currency: 'EUR'),
        ),
        '100,00 kr',
      );
    });
  });

  group('Q44: no-show fee share per country', () {
    test('default 80%', () {
      final terms = DriverAppConfig.fromJson({'currency': 'SEK'}).waiting.base;
      expect(terms.driverShareNoShowPercent, 80);
    });

    test('from the config', () {
      final config = DriverAppConfig.fromJson({
        'currency': 'EUR',
        'waiting': {
          'noShowFee': {'amountMinor': 1000, 'currency': 'EUR'},
          'driverSharePct': 70,
        },
      });
      config.apply();
      final terms = WaitingRules.current.termsFor();
      expect(terms.driverShareNoShowPercent, 70);
      expect(terms.driverNoShowFee.formatted, '7,00 €');
    });
  });

  group('Q46: missed Exclusive offers before offline', () {
    test('N from offers.autoOffline.missedExclusive', () {
      DriverAppConfig.fromJson({
        'offers': {
          'autoOffline': {'on': true, 'missedExclusive': 5},
        },
      }).apply();
      expect(DriverOfferRules.current.autoOfflineAfter, 5);
      final answers = ExclusiveAnswers.instance;
      for (var i = 0; i < 4; i++) {
        expect(answers.missed(), isFalse);
      }
      expect(answers.missed(), isTrue);
    });

    test('the local default (10, contract v0.5.6) stays the fallback', () {
      DriverAppConfig.fromJson({
        'offers': {
          'autoOffline': {'missedExclusive': 0},
        },
      }).apply();
      expect(
        DriverOfferRules.current.autoOfflineAfter,
        DriverOfferRules.defaultAutoOfflineAfter,
      );
      expect(DriverOfferRules.defaultAutoOfflineAfter, 10);
    });

    test('admin can switch it off', () {
      DriverAppConfig.fromJson({
        'offers': {
          'autoOffline': {'on': false, 'missedExclusive': 2},
        },
      }).apply();
      for (var i = 0; i < 5; i++) {
        expect(ExclusiveAnswers.instance.missed(), isFalse);
      }
    });
  });

  group('Q16/Q18: admin offers', () {
    test('a bonus or priority shows the Priority badge', () {
      expect(DemoAdminOffers.radarGroup.isPriority, isTrue);
      expect(DemoAdminOffers.radarGroup.isAdminDirectAssign, isFalse);
      expect(DemoAdminOffers.directAssign.isAdminDirectAssign, isTrue);
      final bonusOnly = RideOffer(
        id: 'b',
        category: 'Movera',
        fare: const Money(minorUnits: 10000),
        driverBonus: const Money(minorUnits: 2000),
        rating: '4.9',
        pickupMinutes: 2,
        pickupKm: 1,
        tripMinutes: 10,
        tripKm: 5,
        pickup: 'A',
        dropoff: 'B',
        pickupPosition: DemoRideCheckTrips.farDropoff.pickupPosition,
        dropoffPosition: DemoRideCheckTrips.farDropoff.dropoffPosition,
        isNearby: true,
        followsDestination: false,
      );
      expect(bonusOnly.isPriority, isTrue);
      expect(DemoRideCheckTrips.farDropoff.isPriority, isFalse);
      expect(OfferSource.fromWire('admin'), OfferSource.admin);
      expect(OfferSource.fromWire('system'), OfferSource.system);
      expect(OfferSource.fromWire(null), OfferSource.system);
    });

    test('the fare already includes the bonus (one total)', () {
      // 112,40 kr trip + 40 kr bonus.
      expect(DemoAdminOffers.radarGroup.fareLabel, '152,40 kr');
      expect(DemoAdminOffers.radarGroup.driverBonus!.formatted, '40,00 kr');
    });

    test('the demo sends them only when its switch is on', () async {
      final on = DemoDispatchRepository(adminOffers: true);
      final off = DemoDispatchRepository(adminOffers: false);
      addTearDown(on.dispose);
      addTearDown(off.dispose);
      final withAdmin = await on.watchNearbyOffers().first;
      expect(withAdmin.first.id, DemoAdminOffers.radarGroup.id);
      expect(withAdmin.last.id, DemoAdminOffers.directAssign.id);
      final plain = await off.watchNearbyOffers().first;
      expect(plain.map((o) => o.id), ['nearby-1', 'nearby-2', 'nearby-3']);
      // Tests run with it off by default.
      final byDefault = DemoDispatchRepository();
      addTearDown(byDefault.dispose);
      expect((await byDefault.watchNearbyOffers().first).map((o) => o.id), [
        'nearby-1',
        'nearby-2',
        'nearby-3',
      ]);
      on.reset();
      expect(
        (await on.watchNearbyOffers().first).first.id,
        DemoAdminOffers.radarGroup.id,
      );
    });
  });

  group('Q12: acceptedAt in the trip model', () {
    test('a trip projection carries acceptedAt and driverBonus', () {
      final projection = DriverTripProjection.fromJson({
        'tripId': 't1',
        'status': 'accepted',
        'version': 3,
        'acceptedAt': '2026-10-20T08:00:00+02:00',
        'driverBonus': {'amountMinor': 4000, 'currency': 'SEK'},
      });
      expect(projection.status, TripStatus.accepted);
      expect(projection.acceptedAt, DateTime.utc(2026, 10, 20, 6));
      expect(projection.driverBonus!.formatted, '40,00 kr');
      expect(
        DriverTripProjection.fromJson({
          'tripId': 't1',
          'status': 'requested',
          'version': 1,
          'acceptedAt': null,
        }).acceptedAt,
        isNull,
      );
    });

    test('a realtime projection carries acceptedAt', () {
      final event = DriverRealtimeEvent.fromJson({
        'tripId': 't1',
        'kind': 'trip_projection',
        'sequence': 2,
        'occurredAt': '2026-10-20T06:00:05Z',
        'projection': {
          'status': 'accepted',
          'acceptedAt': '2026-10-20T06:00:00Z',
        },
      });
      expect(event.acceptedAt, DateTime.utc(2026, 10, 20, 6));
      final again = DriverRealtimeEvent.fromJson(event.toJson());
      expect(again.acceptedAt, event.acceptedAt);
      expect(again.status, TripStatus.accepted);
    });

    test('the saved trip keeps acceptedAt and the paid waiting', () {
      final saved = PersistedActiveRide(
        tripId: 't1',
        stage: ActiveRideStage.onTrip,
        acceptedAt: DateTime.utc(2026, 10, 20, 6),
        paidWaitSeconds: 95,
      );
      final back = PersistedActiveRide.fromJson(saved.toJson())!;
      expect(back.acceptedAt!.toUtc(), DateTime.utc(2026, 10, 20, 6));
      expect(back.paidWaitSeconds, 95);
      expect(back.stamped().paidWaitSeconds, 95);
      expect(back.stamped().acceptedAt, back.acceptedAt);
      expect(
        PersistedActiveRide.fromJson({
          ...saved.toJson(),
          'paidWaitSeconds': -1,
        }),
        isNull,
      );
      expect(
        PersistedActiveRide.fromJson({...saved.toJson(), 'acceptedAt': 5}),
        isNull,
      );
    });
  });
}
