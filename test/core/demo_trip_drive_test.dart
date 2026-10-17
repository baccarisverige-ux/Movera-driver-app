import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/location/demo_trip_drive.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_detector.dart';

/// The RideCheck demo trips drive scripted GPS; the real detector, fed one
/// fix per second as the trip screen does, decides when the card opens.
void main() {
  final t0 = DateTime(2026, 10, 17, 9);

  DemoTripDrive drive(DemoDriveScript script) {
    final offer = script == DemoDriveScript.farDropoff
        ? DemoRideCheckTrips.farDropoff
        : DemoRideCheckTrips.longStop;
    return DemoTripDrive(
      script: script,
      pickup: offer.pickupPosition,
      dropoff: offer.dropoffPosition,
    );
  }

  /// Plays [ticks] seconds of the trip into a detector with admin's
  /// rules; returns the first event and its tick.
  (RideCheckEvent, int)? play(DemoTripDrive car, int ticks) {
    final detector = RideCheckDetector(
      rules: RideCheckRules.fromAdmin(RideCheckAdminConfig.current),
    )
      ..startTrip(t0)
      ..planLeg('0', [car.pickup, car.dropoff], 1200, wholeTrip: true);
    for (var i = 0; i <= ticks; i++) {
      final at = car.positionAt(i);
      final event = detector.observe(
        at,
        t0.add(Duration(seconds: i)),
        atPlannedStop: at.distanceMetersTo(car.dropoff) <=
            RideCheckRules.plannedStopRadiusMeters,
      );
      if (event != null) return (event, i);
    }
    return null;
  }

  test('only the two demo trips get a scripted drive', () {
    const pickup = DemoTripDrive.farDropoffOfferId;
    final a = DemoRideCheckTrips.farDropoff;
    expect(
      DemoTripDrive.forTrip('$pickup-1700000000000000',
              pickup: a.pickupPosition, dropoff: a.dropoffPosition)
          ?.script,
      DemoDriveScript.farDropoff,
    );
    expect(
      DemoTripDrive.forTrip(DemoTripDrive.longStopOfferId,
              pickup: a.pickupPosition, dropoff: a.dropoffPosition)
          ?.script,
      DemoDriveScript.longStop,
    );
    expect(
      DemoTripDrive.forTrip('nearby-1-1700000000000000',
          pickup: a.pickupPosition, dropoff: a.dropoffPosition),
      isNull,
    );
  });

  test('far drop-off: the car ends past admin\'s 3 km and Finish asks', () {
    final car = drive(DemoDriveScript.farDropoff);
    // Driving there opens nothing.
    expect(play(car, DemoTripDrive.driveTicks + 10), isNull);
    final end = car.positionAt(DemoTripDrive.driveTicks + 10);
    expect(end.distanceMetersTo(car.dropoff), greaterThan(3000));
    final event = RideCheckDetector().finish(
      driver: end,
      dropoff: car.dropoff,
      dropoffAddress: DemoRideCheckTrips.farDropoff.dropoff,
      at: t0,
    )!;
    expect(event.trigger, RideCheckTrigger.droppedFar);
    expect(event.demo, isFalse);
    expect(event.reason.text, endsWith('from Kista Galleria'));
  });

  test('long stop: the car stands still and the check opens just after '
      '2 min, then drives on to the drop-off', () {
    expect(RideCheckAdminConfig.current.longStopMinutes, 2);
    final car = drive(DemoDriveScript.longStop);
    final stopAt = car.positionAt(DemoTripDrive.driveTicks);
    expect(
      stopAt.distanceMetersTo(car.dropoff),
      greaterThan(RideCheckRules.plannedStopRadiusMeters),
    );
    final (event, tick) = play(car, DemoTripDrive.driveTicks + car.stopTicks)!;
    expect(event.trigger, RideCheckTrigger.longStop);
    expect(event.reason.bold, '2 min');
    // Opens once the car has stood still for more than 2 min, not before.
    expect(tick - DemoTripDrive.driveTicks, inInclusiveRange(121, 125));
    final end = car.positionAt(2 * DemoTripDrive.driveTicks + car.stopTicks);
    expect(end.distanceMetersTo(car.dropoff), lessThan(1));
  });
}
