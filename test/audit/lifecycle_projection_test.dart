import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driver_session_repository.dart';

class _DelayedSession implements DriverSessionRepository {
  final read = Completer<bool?>();
  @override
  Future<bool?> readOnline() => read.future;
  @override
  Future<void> saveOnline(bool value) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  test(
    'authoritative projection can skip live stages and end with every terminal outcome',
    () async {
      for (final status in TripStatus.values.where((s) => s.isTerminal)) {
        final ride = ActiveRideController(tripId: 'projection-${status.name}');
        expect(await ride.applyProjection(TripStatus.inTrip), isTrue);
        expect(ride.stage, ActiveRideStage.onTrip);
        expect(await ride.applyProjection(status), isTrue);
        expect(ride.terminalStatus, status);
        expect(
          await ride.transitionTo(ActiveRideStage.headingToPickup),
          isFalse,
        );
        ride.dispose();
      }
    },
  );
  test(
    'duplicate terminal projection is ignored, authoritative correction is kept',
    () async {
      final ride = ActiveRideController(tripId: 'terminal-correction');
      addTearDown(ride.dispose);
      expect(await ride.applyProjection(TripStatus.inTrip), isTrue);
      expect(await ride.applyProjection(TripStatus.completed), isTrue);
      expect(ride.terminalStatus, TripStatus.completed);
      expect(await ride.applyProjection(TripStatus.completed), isFalse);
      // A server-authoritative rider cancellation may correct tentative local
      // completion without resurrecting the active ride.
      expect(await ride.applyProjection(TripStatus.cancelledByRider), isTrue);
      expect(ride.terminalStatus, TripStatus.cancelledByRider);
      expect(await ride.applyProjection(TripStatus.cancelledByRider), isFalse);
      expect(await ride.applyProjection(TripStatus.inTrip), isFalse);
      expect(ride.terminalStatus, TripStatus.cancelledByRider);
      expect(ride.tripStatus, TripStatus.cancelledByRider);
    },
  );

  test(
    'delayed restore cannot overwrite an explicit availability change',
    () async {
      final repo = _DelayedSession();
      final session = DriverSessionController(repository: repo);
      final restore = session.restore();
      session.setOnline(true);
      repo.read.complete(true);
      await restore;
      expect(session.availableForOffers, isTrue);
      session.beginTrip('trip-a');
      expect(session.status, DriverOnlineStatus.onTrip);
      expect(session.availableForOffers, isFalse);
      session.setOnline(true);
      expect(session.activeTripId, 'trip-a');
      session.reset();
      expect(session.activeTripId, isNull);
      expect(session.isOnline, isFalse);
      session.dispose();
    },
  );
}
