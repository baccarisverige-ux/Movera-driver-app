import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';
import 'package:movera/core/scheduled/smart_gap.dart';

const _rules = ScheduledRideRules();

/// 07:00 on a day, the start of the demo day.
final _seven = DateTime(2026, 10, 15, 7);

ReservationRequestPreview _ride({
  required String time,
  String day = 'Today',
  String category = 'Movera',
  int tripMinutes = 20,
  double tripKm = 9,
  GeoPoint pickup = const GeoPoint(59.3362, 18.0714),
  GeoPoint dropoff = const GeoPoint(59.3603, 18.0009),
  String pickupAddress = 'Gamla vägen, Stockholm',
  String dropoffAddress = 'Solna centrum, Solna',
}) => ReservationRequestPreview(
  category: category,
  fare: '100 kr',
  pickupLabel: '',
  pickupAddress: pickupAddress,
  dropoffAddress: dropoffAddress,
  pickupTime: time,
  pickupDay: day,
  tripMinutes: tripMinutes,
  tripKm: tripKm,
  pickup: pickup,
  dropoff: dropoff,
);

void main() {
  group('reservation steps follow the admin minutes', () {
    test('defaults mirror Dispatch › Reservations', () {
      expect(_rules.homePopupAfterMinutes, 10);
      expect(_rules.exclusiveBeforeMinutes, 20);
      expect(_rules.radarBeforeMinutes, 15);
      expect(_rules.onDriverCancel, ReservationCancelReturn.byTime);
      expect(_rules.longTripKm, 50);
      expect(_rules.driverLateCancelHours, 1);
      expect(_rules.lateCancelLimit, 2);
      expect(_rules.lateCancelPeriodDays, 7);
      for (final kind in ScheduledRideKind.values) {
        expect(_rules.ruleFor(kind).spareMinutes, 15, reason: '$kind');
      }
      expect(_rules.ruleFor(ScheduledRideKind.normal).onlineBeforeMinutes, 30);
      expect(_rules.ruleFor(ScheduledRideKind.airport).onlineBeforeMinutes, 60);
      expect(
        _rules.ruleFor(ScheduledRideKind.longTrip).onlineBeforeMinutes,
        60,
      );
    });

    test('minutes before pickup decide Exclusive and Radar', () {
      ReservationStep at(int before, {int since = 0}) =>
          _rules.stepAt(sinceBookedMinutes: since, beforePickupMinutes: before);
      expect(at(120), ReservationStep.list);
      expect(at(120, since: 10), ReservationStep.home);
      expect(at(20), ReservationStep.exclusive);
      expect(at(16, since: 30), ReservationStep.exclusive);
      expect(at(15), ReservationStep.radar);
      expect(at(2), ReservationStep.radar);
    });

    test('after a driver cancel: by time, and a closer step always wins', () {
      ReservationStep after(ReservationCancelReturn to, int before) =>
          ScheduledRideRules(onDriverCancel: to).stepAfterDriverCancel(
            sinceBookedMinutes: 60,
            beforePickupMinutes: before,
          );
      expect(after(ReservationCancelReturn.byTime, 90), ReservationStep.home);
      expect(after(ReservationCancelReturn.byTime, 10), ReservationStep.radar);
      // Back to the list: the popup waits again from the cancel.
      expect(after(ReservationCancelReturn.list, 90), ReservationStep.list);
      expect(after(ReservationCancelReturn.list, 10), ReservationStep.radar);
      expect(
        after(ReservationCancelReturn.exclusive, 90),
        ReservationStep.exclusive,
      );
      expect(after(ReservationCancelReturn.home, 10), ReservationStep.radar);
    });
  });

  group('smart gap (Q9/Q10)', () {
    test('kind of ride: airport, long trip, Comfort/Premium, normal', () {
      expect(
        SmartGap.kindOf(
          _ride(time: '09:00', dropoffAddress: 'Arlanda Terminal 5, Arlanda'),
          _rules,
        ),
        ScheduledRideKind.airport,
      );
      expect(
        SmartGap.kindOf(_ride(time: '09:00', tripKm: 61), _rules),
        ScheduledRideKind.longTrip,
      );
      expect(
        SmartGap.kindOf(_ride(time: '09:00', category: 'Premium'), _rules),
        ScheduledRideKind.comfortPremium,
      );
      expect(
        SmartGap.kindOf(_ride(time: '09:00'), _rules),
        ScheduledRideKind.normal,
      );
    });

    test(
      'a ride clashes when the trip, the drive and the spare do not fit',
      () {
        final first = _ride(time: '07:40', tripMinutes: 19);
        // Solna centrum → Lidingö is about 23 min: 07:40 + 19 + 23 + 15.
        final lidingo = _ride(
          time: '08:05',
          pickup: const GeoPoint(59.3584, 18.1567),
        );
        expect(
          SmartGap.clash(first, lidingo, now: _seven, rules: _rules),
          isTrue,
        );
        expect(
          SmartGap.clash(lidingo, first, now: _seven, rules: _rules),
          isTrue,
        );
        final later = _ride(
          time: '08:40',
          pickup: const GeoPoint(59.3584, 18.1567),
        );
        expect(
          SmartGap.clash(first, later, now: _seven, rules: _rules),
          isFalse,
        );
        // Same time is always a clash; another day never is.
        expect(
          SmartGap.clash(
            first,
            _ride(time: '07:40'),
            now: _seven,
            rules: _rules,
          ),
          isTrue,
        );
        expect(
          SmartGap.clash(
            first,
            _ride(time: '07:40', day: 'Tomorrow'),
            now: _seven,
            rules: _rules,
          ),
          isFalse,
        );
      },
    );

    test('the spare minutes are the second ride\'s, set by admin', () {
      final first = _ride(time: '07:40', tripMinutes: 19);
      final next = _ride(
        time: '08:30',
        pickup: const GeoPoint(59.3584, 18.1567),
      );
      expect(
        SmartGap.fitsBefore(first, next, now: _seven, rules: _rules),
        isFalse,
      );
      const relaxed = ScheduledRideRules(
        kinds: {
          ScheduledRideKind.normal: ScheduledRideKindRule(
            onlineBeforeMinutes: 30,
            spareMinutes: 5,
          ),
        },
      );
      expect(
        SmartGap.fitsBefore(first, next, now: _seven, rules: relaxed),
        isTrue,
      );
    });

    test('leave now = pickup − drive − spare, from where the driver is', () {
      final ride = _ride(time: '07:40');
      const far = GeoPoint(59.2705, 18.0515);
      final drive = SmartGap.driveMinutes(far, ride.pickup);
      expect(drive, greaterThan(10));
      expect(
        SmartGap.leaveAt(ride, driver: far, now: _seven, rules: _rules),
        DateTime(2026, 10, 15, 7, 40).subtract(Duration(minutes: drive + 15)),
      );
      expect(
        SmartGap.leaveAt(
          _ride(time: 'soon'),
          driver: far,
          now: _seven,
          rules: _rules,
        ),
        isNull,
      );
    });

    test('a trip before the ride must fit and, near it, head toward it', () {
      final ride = _ride(time: '07:40');
      bool fits(int pickup, int trip, GeoPoint dropoff, DateTime now) =>
          SmartGap.offerFits(
            offerPickupMinutes: pickup,
            offerTripMinutes: trip,
            offerDropoff: dropoff,
            ride: ride,
            now: now,
            rules: _rules,
          );
      const nearPickup = GeoPoint(59.3380, 18.0700);
      expect(fits(3, 8, nearPickup, _seven), isTrue);
      expect(fits(3, 30, nearPickup, _seven), isFalse);
      expect(fits(3, 8, nearPickup, DateTime(2026, 10, 15, 7, 20)), isFalse);

      const driver = GeoPoint(59.3293, 18.0686);
      expect(
        SmartGap.headsToward(
          from: driver,
          dropoff: const GeoPoint(59.3400, 18.0750),
          target: ride.pickup,
        ),
        isTrue,
      );
      expect(
        SmartGap.headsToward(
          from: driver,
          dropoff: const GeoPoint(59.2705, 18.0515),
          target: ride.pickup,
        ),
        isFalse,
      );
    });
  });

  group('demo clock', () {
    test('runs from its start time, faster, and converts back', () {
      var real = DateTime.utc(2015);
      final previous = ScheduledClock.realNow;
      ScheduledClock.realNow = () => real;
      addTearDown(() => ScheduledClock.realNow = previous);
      final clock = ScheduledClock(
        startTime: const Duration(hours: 7),
        speed: 30,
      );
      expect(clockLabel(clock.now()), '07:00');
      real = real.add(const Duration(seconds: 40));
      expect(clockLabel(clock.now()), '07:20');
      expect(
        clock.realUntil(clock.now().add(const Duration(minutes: 5))),
        const Duration(seconds: 10),
      );
      expect(
        clock.realUntil(clock.now().subtract(const Duration(minutes: 1))),
        Duration.zero,
      );
      clock.reset();
      expect(clockLabel(clock.now()), '07:00');
    });

    test('the demo 07:40 reservation reaches Exclusive at nearPickupAfter', () {
      final clock = ScheduledClock.instance;
      // The demo books its rides for a date (driver-u141): its first day.
      final booked = demoReservationRequest.scheduledAt!;
      final start = DateTime(
        booked.year,
        booked.month,
        booked.day,
      ).add(clock.startTime!);
      final exclusiveAt = demoReservationRequest
          .pickupAt(start)!
          .subtract(Duration(minutes: _rules.exclusiveBeforeMinutes));
      expect(
        exclusiveAt.difference(start),
        ReservationDemoTimings.nearPickupAfter * clock.speed,
      );
      expect(clock.realUntil(clock.now()), Duration.zero);
    });
  });
}
