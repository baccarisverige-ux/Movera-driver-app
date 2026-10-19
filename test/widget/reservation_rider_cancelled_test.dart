import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

void main() {
  setUp(() {
    ScheduledRideStore.reset();
    IslandMessages.reset();
  });

  test('R15-7: a rider cancels an accepted reservation: it leaves Accepted '
      'and the island says so with the fee', () {
    final ride = DemoReservations.main;
    ScheduledRideStore.take(ride.id, upcoming: true);
    expect(ScheduledRideStore.upcoming.any((r) => r.id == ride.id), isTrue);

    expect(ScheduledRideStore.riderCancelled(ride.id, fee: Money.sek(105)),
        isTrue);
    expect(ScheduledRideStore.upcoming.any((r) => r.id == ride.id), isFalse);
    final message = IslandMessages.take();
    expect(message?.title, '${ride.pickupTime} cancelled · +105 kr');
    expect(message?.priority, IslandPriority.high);

    // Not an accepted ride (or already gone): nothing happens.
    expect(ScheduledRideStore.riderCancelled(ride.id), isFalse);
    expect(IslandMessages.take(), isNull);
  });
}
