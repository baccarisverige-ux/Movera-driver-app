import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/cancel_reasons.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Round 3 (D2): offer, waiting and cancel rules, with the admin defaults.

void main() {
  group('offer rules (Q14–Q18)', () {
    const rules = DriverOfferRules();

    test('defaults mirror the admin', () {
      expect(rules.autoOffline, isTrue);
      // Q46: three in a row, until admin sends its own number.
      expect(rules.autoOfflineAfter, 3);
      expect(DriverOfferRules.defaultAutoOfflineAfter, 3);
      expect(rules.hiddenComesBackAfter, const Duration(minutes: 2));
      expect(rules.exclusiveWhileDriving, isTrue);
      expect(rules.exclusiveWhileDrivingCount, 1);
      expect(rules.commissionRate, WaybillPayment.serviceFeeRate);
      expect([for (final reason in rules.exclusiveReasons) reason.text], [
        'Best match',
        "Rider's favourite",
        'Finishing nearby',
        'Airport queue',
        'Pickup soon',
        'Only for you · nearby',
      ]);
      const card = OfferCardDetails();
      expect(card.netFare, isFalse);
      expect(card.pickupAddress && card.stops && card.riderRating, isTrue);
      expect(card.tripMinutesKm && card.pickupDistance && card.badges, isTrue);
      expect(card.dropoffAreaOnly, isFalse);
    });

    test('Exclusive reasons come from the list; switched off, no text', () {
      expect(ExclusiveReasons.text(ExclusiveReasons.finishingNearby), 'Finishing nearby');
      expect(ExclusiveReasons.defaultFor(reservation: true), 'Pickup soon');
      expect(ExclusiveReasons.text(ExclusiveReasons.assigned), 'Assigned by Movera');
      const edited = DriverOfferRules(
        exclusiveReasons: [
          ExclusiveReasonRule(id: 'best-match', text: 'Top pick'),
          ExclusiveReasonRule(id: 'nearby', text: 'Close by', on: false),
        ],
      );
      expect(ExclusiveReasons.text('best-match', edited), 'Top pick');
      expect(ExclusiveReasons.text('nearby', edited), '');
      expect(ExclusiveReasons.text('unknown', edited), '');
    });

    test('net fare: the driver\'s share after the commission', () {
      const card = OfferCardDetails(netFare: true);
      expect(card.fare('100,00 kr'), '75,00 kr');
      expect(card.fare('126,75 kr', commissionRate: 0.2), '101,40 kr');
      expect(const OfferCardDetails().fare('126,75 kr'), '126,75 kr');
      expect(card.fare('—'), '—');
    });

    test('Q46: 3 Exclusive offers in a row without Accept go offline', () {
      final answers = ExclusiveAnswers.instance..reset();
      expect(answers.missed(rules), isFalse);
      expect(answers.lastBeforeOffline(rules), isFalse);
      expect(answers.missed(rules), isFalse);
      expect(answers.lastBeforeOffline(rules), isTrue);
      // Accept starts the row again.
      answers.accepted();
      expect(answers.missedInRow, 0);
      for (var i = 0; i < 2; i++) {
        answers.missed(rules);
      }
      expect(answers.missed(rules), isTrue);
      expect(answers.missedInRow, 0);
      // Off in admin: never offline.
      for (var i = 0; i < 10; i++) {
        expect(
          answers.missed(const DriverOfferRules(autoOffline: false)),
          isFalse,
        );
      }
    });
  });

  group('waiting at pickup (Q19/Q20)', () {
    const rules = WaitingRules();

    test('the zone\'s terms and the driver\'s share', () {
      final terms = rules.termsFor(category: 'Comfort');
      // contract.json#configDefaults (owner Q41): 5 free minutes.
      expect(terms.freeMinutes, 5);
      expect(terms.perMinute.formatted, '12,26 kr');
      expect(terms.noShowAfterMinutes, 5);
      expect(terms.noShowFee.formatted, '65,00 kr');
      expect(terms.driverShareWaitPercent, 100);
      expect(terms.driverShareNoShowPercent, 80);
      expect(terms.driverNoShowFee.formatted, '52,00 kr');
      expect(terms.rule, '');
    });

    test('by ride type, category and pickup distance', () {
      final scheduled = rules.termsFor(type: WaitingRideType.scheduled);
      expect(scheduled.freeMinutes, 5);
      expect(scheduled.rule, 'Scheduled ride');
      final airport = rules.termsFor(type: WaitingRideType.airport);
      expect(airport.freeMinutes, 15);
      expect(airport.noShowAfterMinutes, 20);
      final premium = rules.termsFor(
        category: 'Premium',
        type: WaitingRideType.scheduled,
      );
      expect(premium.perMinute.formatted, '16,90 kr');
      expect(premium.rule, 'Premium · Scheduled ride');
      final far = rules.termsFor(pickupKm: 7.5);
      expect(far.freeMinutes, 1);
      expect(far.noShowFee.formatted, '85,00 kr');
      expect(far.rule, 'Pickup over 5 km');
      expect(rules.termsFor(pickupKm: 4).rule, '');
    });

    test('a scheduled ride waits the reservation policy\'s included time', () {
      addTearDown(() => ScheduledRideRules.current = const ScheduledRideRules());
      expect(const ScheduledRideRules().includedWaitingMinutes, 5);
      ScheduledRideRules.current = const ScheduledRideRules(
        includedWaitingMinutes: 7,
      );
      expect(rules.termsFor(type: WaitingRideType.scheduled).freeMinutes, 7);
      expect(rules.termsFor().freeMinutes, 5);
    });

    test('Dispatch\'s offer times: 15 s to accept, 15 s on the radar', () {
      const offers = DriverOfferRules();
      expect(offers.exclusiveAcceptTime, const Duration(seconds: 15));
      expect(offers.radarTime, const Duration(seconds: 15));
    });

    test('the kind of trip from how it was matched and where it starts', () {
      expect(
        WaitingRules.typeOf(
          matchedVia: 'Scheduled ride',
          pickupAddress: 'Gamla vägen, Stockholm',
        ),
        WaitingRideType.scheduled,
      );
      expect(
        WaitingRules.typeOf(
          matchedVia: 'Exclusive reservation',
          pickupAddress: 'Gamla vägen',
        ),
        WaitingRideType.scheduled,
      );
      expect(
        WaitingRules.typeOf(
          matchedVia: 'Movera Radar',
          pickupAddress: 'Arlanda Terminal 5',
        ),
        WaitingRideType.airport,
      );
      expect(
        WaitingRules.typeOf(matchedVia: 'Movera Radar', pickupAddress: 'Kungsgatan'),
        WaitingRideType.normal,
      );
    });
  });

  group('cancel reasons (Q21)', () {
    const reasons = CancelReasons();

    test('the app\'s reasons, with the ones that don\'t count', () {
      expect(reasons.of(CancelReasonGroup.driverBeforeTrip), hasLength(6));
      expect(reasons.of(CancelReasonGroup.driverDuringTrip), hasLength(7));
      expect(reasons.of(CancelReasonGroup.scheduled), hasLength(6));
      // The rider app's codes, from pickup_incorrect to something_else.
      expect(reasons.of(CancelReasonGroup.rider).map((r) => r.code), [
        'pickup_incorrect',
        'wrong_ride_option',
        'requested_by_mistake',
        'wait_too_long',
        'destination_change',
        'driver_not_suitable',
        'plans_changed',
        'something_else',
      ]);
      expect(reasons.counts('rider_no_show'), isFalse);
      expect(reasons.counts('unsafe_pickup'), isFalse);
      expect(reasons.counts('safety_concern_on_trip'), isFalse);
      expect(reasons.counts('vehicle_issue_on_trip'), isFalse);
      expect(reasons.counts('scheduled_vehicle_issue'), isFalse);
      expect(reasons.counts('rider_requested_cancel'), isTrue);
      expect(reasons.counts('driver_emergency_before_start'), isTrue);
      expect(reasons.counts('anything-else'), isTrue);
      expect(reasons.country, 'SE');
      expect(reasons.language, 'en');
    });
  });

  group('cash (Q23)', () {
    test('a cash trip without a recorded cash amount balances to zero', () {
      const cash = TripHistoryRecord(
        tripId: 't1',
        riderName: 'Karin',
        whenLabel: '',
        pickup: '',
        dropoff: '',
        fare: '126,75 kr',
        category: 'Comfort',
        paymentMethod: 'Cash',
      );
      expect(cash.paidByCash, isTrue);
      expect(cash.cashBalance?.balance.minorUnits, 0);
      const card = TripHistoryRecord(
        tripId: 't2',
        riderName: 'Karin',
        whenLabel: '',
        pickup: '',
        dropoff: '',
        fare: '126,75 kr',
        category: 'Comfort',
      );
      expect(card.cashBalance, isNull);
      const cancelled = TripHistoryRecord(
        tripId: 't3',
        riderName: 'Karin',
        whenLabel: '',
        pickup: '',
        dropoff: '',
        fare: '126,75 kr',
        category: 'Comfort',
        paymentMethod: 'Cash',
        status: TripStatus.cancelledByDriver,
      );
      expect(cancelled.cashBalance, isNull);
    });

    test('the completed cash trip is saved as paid by cash', () async {
      SharedPreferences.setMockInitialValues({});
      final history = PrefsTripHistoryRepository();
      await CompletionJournal(
        active: MemoryActiveRideRepository(),
        history: history,
      ).finish(
        WaybillRecord(
          tripId: 'cash-trip-1',
          statusLabel: 'Current trip',
          issuedAt: DateTime(2026, 10, 15, 7),
          fare: '126,75 kr',
          service: 'Comfort',
          riderName: 'Karin',
          pickup: 'Gamla vägen',
          dropoff: 'Solna centrum',
          source: 'Movera Radar',
          driverName: 'Driver',
          vehicle: 'Car',
          licensePlate: 'ABC 123',
          passengerCapacity: 4,
        ),
        paymentMethod: 'Cash',
        cashCollected: '150 kr',
      );
      final row = (await history.list()).single;
      expect(row.paymentMethod, 'Cash');
      expect(row.cashCollected, '150 kr');
      expect(row.cashBalance?.signedLabel, '−23,25 kr');
    });
  });
}
