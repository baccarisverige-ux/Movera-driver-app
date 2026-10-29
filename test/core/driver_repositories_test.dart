import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/driver/driver_profile.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/vehicle/vehicle.dart';

void main() {
  test('driver profile repository seeds a Stockholm driver', () async {
    final repo = InMemoryDriverProfileRepository();
    final profile = await repo.load();
    expect(profile.driverId, 'D-418');
    expect(profile.city, 'Stockholm');
    expect(profile.status, DriverOnlineStatus.offline);

    await repo.save(profile.copyWith(status: DriverOnlineStatus.online));
    expect(repo.current?.status, DriverOnlineStatus.online);
  });

  test('vehicle repository keeps one active partner car', () async {
    final repo = InMemoryVehicleRepository();
    final vehicles = await repo.load();
    expect(vehicles, hasLength(1));
    expect(repo.active?.licensePlate, 'MVR 418');
    expect(repo.active?.seats, 4);
  });
}
