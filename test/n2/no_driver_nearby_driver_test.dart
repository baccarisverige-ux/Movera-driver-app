import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';

/// Fix job N2 + P17 + far rider (contract v0.18.39 §63), RULE 0 check for the
/// driver app: "No driver nearby", the live search with no end, the far reach
/// step and the booked-ride stop are server, admin and rider features. The
/// driver app has no screen change (contract.json#noDriverNearby.driver): a far
/// offer already shows its pickup distance (Offer.pickupMeters) and pickup pay.
/// The one code change: BookLaterRules (ScheduledRideRules) mirrors every DriverAppConfig
/// .reservations key, so it reads noDriverStopAfterMin (P17, default 15).
void main() {
  final contract =
      jsonDecode(File('contracts/contract.json').readAsStringSync())
          as Map<String, dynamic>;

  test('contract v0.18.39 says the driver app has no change', () {
    final nd = contract['noDriverNearby'] as Map<String, dynamic>;
    expect(nd['driver'], startsWith('Driver app: no change.'));
    expect(nd['driver'], contains('pickupMeters'));
  });

  test('the driver document with reservations.noDriverStopAfterMin reads', () {
    final json =
        jsonDecode(
              File(
                'contracts/fixtures/config/driver_app_config.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      (json['reservations'] as Map<String, dynamic>)['noDriverStopAfterMin'],
      15,
    );
    final config = DriverAppConfig.fromJson(json);
    expect(config.zoneId, json['zoneId']);
    expect(const BookLaterRules().noDriverStopAfterMin, 15);
    expect(
      BookLaterRules.fromJson({
        'noDriverStopAfterMin': 20,
      }).noDriverStopAfterMin,
      20,
    );
    expect(
      BookLaterRules.fromJson({'noDriverStopAfterMin': 0}).noDriverStopAfterMin,
      15,
    );
  });
}
