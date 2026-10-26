import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';

class FaultStore implements ActiveRideRepository {
  bool fail = true;
  PersistedActiveRide? ride;
  @override
  Future<PersistedActiveRide?> read() async => ride;
  @override
  Future<void> save(PersistedActiveRide value) async {
    if (fail) throw StateError('disk full');
    ride = value;
  }

  @override
  Future<void> clear() async {
    if (fail) throw StateError('remove failed');
    ride = null;
  }
}

void main() {
  test(
    'failed stage saves remain recoverable and do not commit stage',
    () async {
      final store = FaultStore();
      final ride = ActiveRideController(tripId: 'A', repository: store);
      expect(await ride.transitionTo(ActiveRideStage.waitingForRider), false);
      expect(ride.persistenceError, isNotNull);
      expect(ride.stage, ActiveRideStage.headingToPickup);
      store.fail = false;
      expect(await ride.transitionTo(ActiveRideStage.waitingForRider), true);
      store.fail = true;
      expect(await ride.transitionTo(ActiveRideStage.onTrip), false);
      expect(ride.stage, ActiveRideStage.waitingForRider);
      store.fail = false;
      expect(await ride.transitionTo(ActiveRideStage.onTrip), true);
      store.fail = true;
      expect(await ride.persistNow(), false);
      expect(await ride.complete(), false);
      expect(ride.terminal, false);
      expect(await ride.cancel(), false);
      store.fail = false;
      expect(await ride.cancel(), true);
    },
  );
}
