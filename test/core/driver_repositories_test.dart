import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/driver/driver_profile.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/vehicle/vehicle.dart';

import '../onboarding/g2_fixtures.dart';

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

  // Replaces "document repository lists the four driver requirements" (the
  // removed mock repository): the driver's required documents now come from
  // GET /driver/onboarding/settings (contract v0.18.0, owner group 2 item 10).
  for (final (country, required) in [
    (
      'SE',
      [
        'terms',
        'info_session',
        'driving_license',
        'profile_photo',
        'taxi_driver_license',
      ],
    ),
    (
      'FR',
      [
        'terms',
        'info_session',
        'vtc_card',
        'driving_license',
        'national_id',
        'profile_photo',
      ],
    ),
  ]) {
    test(
      '$country: the driver documents come from the onboarding settings',
      () async {
        final server = FakeServer({
          'GET ${DriverAccountRepository.onboardingSettingsPath}':
              (request) async {
                expect(request.url.queryParameters['country'], country);
                return jsonResponse(200, settingsJson(country));
              },
        });
        final settings = await server.session().repository.onboardingSettings(
          country: country,
        );
        expect(settings.country, country);
        expect(settings.driverDocuments, required);
      },
    );
  }
}
