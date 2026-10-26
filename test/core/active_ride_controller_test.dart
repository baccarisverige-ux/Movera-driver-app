import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/contracts/trip_status.dart';

void main() async {
  test('active ride only allows valid forward lifecycle transitions', () async {
    final ride = ActiveRideController();

    expect(ride.stage, ActiveRideStage.headingToPickup);
    expect(await ride.transitionTo(ActiveRideStage.onTrip), isFalse);
    expect(ride.stage, ActiveRideStage.headingToPickup);

    expect(await ride.transitionTo(ActiveRideStage.waitingForRider), isTrue);
    expect(ride.stage, ActiveRideStage.waitingForRider);

    expect(await ride.transitionTo(ActiveRideStage.onTrip), isTrue);
    expect(ride.stage, ActiveRideStage.onTrip);

    expect(await ride.complete(), isTrue);
    expect(ride.completed, isTrue);
    expect(await ride.transitionTo(ActiveRideStage.waitingForRider), isFalse);
  });

  test('cancelled ride becomes terminal', () async {
    final ride = ActiveRideController();

    expect(await ride.cancel(), isTrue);
    expect(ride.cancelled, isTrue);
    expect(await ride.transitionTo(ActiveRideStage.waitingForRider), isFalse);
  });

  test('rider cancellation preserves the canonical actor', () async {
    final ride = ActiveRideController();

    expect(await ride.cancel(status: TripStatus.cancelledByRider), isTrue);
    expect(ride.cancelled, isTrue);
    expect(ride.terminal, isTrue);
    expect(ride.terminalStatus, TripStatus.cancelledByRider);
    expect(ride.tripStatus, TripStatus.cancelledByRider);
    expect(await ride.cancel(), isFalse);
  });

  test('cancel rejects non-terminal lifecycle statuses', () async {
    final ride = ActiveRideController();

    expect(await ride.cancel(status: TripStatus.inTrip), isFalse);
    expect(ride.terminal, isFalse);
    expect(ride.tripStatus, TripStatus.driverToPickup);
  });

  test('complete is idempotent and rejects double completion', () async {
    final ride = ActiveRideController();
    expect(await ride.complete(), isFalse);

    expect(await ride.transitionTo(ActiveRideStage.waitingForRider), isTrue);
    expect(await ride.transitionTo(ActiveRideStage.onTrip), isTrue);
    expect(await ride.complete(), isTrue);
    expect(await ride.complete(), isFalse);
    expect(ride.cancelled, isFalse);
  });

  test('completion preserves a pre-saved queued trip snapshot', () async {
    final store = MemoryActiveRideRepository();
    final ride = ActiveRideController(
      tripId: 'A',
      repository: store,
      initialStage: ActiveRideStage.onTrip,
    );
    await store.save(
      const PersistedActiveRide(
        tripId: 'B',
        stage: ActiveRideStage.headingToPickup,
      ),
    );
    expect(await ride.complete(clearSnapshot: false), isTrue);
    expect((await store.read())?.tripId, 'B');
  });

  test('active ride persists stage through the repository', () async {
    final store = MemoryActiveRideRepository();
    final ride = ActiveRideController(tripId: 'nearby-1', repository: store);

    expect(await ride.transitionTo(ActiveRideStage.waitingForRider), isTrue);
    await Future<void>.delayed(Duration.zero);

    final restored = ActiveRideController(
      tripId: 'nearby-1',
      repository: store,
    );
    await restored.restore();
    expect(restored.stage, ActiveRideStage.waitingForRider);

    expect(await restored.cancel(), isTrue);
    await Future<void>.delayed(Duration.zero);
    final afterCancel = ActiveRideController(
      tripId: 'nearby-1',
      repository: store,
    );
    await afterCancel.restore();
    expect(afterCancel.stage, ActiveRideStage.headingToPickup);
  });

  test('persistNow writes a snapshot builder payload', () async {
    final store = MemoryActiveRideRepository();
    final ride = ActiveRideController(
      tripId: 'nearby-1',
      repository: store,
      snapshotBuilder: (stage) => PersistedActiveRide(
        tripId: 'nearby-1',
        stage: stage,
        riderName: 'Angelica',
        pickupAddress: 'Kungsgatan 42, Stockholm',
      ),
    );

    ride.persistNow();
    await Future<void>.delayed(Duration.zero);
    final stored = await store.read();
    expect(stored, isNotNull);
    expect(stored!.riderName, 'Angelica');
    expect(stored.pickupAddress, 'Kungsgatan 42, Stockholm');
  });
}
