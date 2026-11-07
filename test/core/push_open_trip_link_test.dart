// Finder A1 (2026-11-07): the driver's Ride Check push ("Is everything OK?",
// contract onTrip.rideCheck.push, bell false) and the "You are not driving
// towards the rider" notice (pickupWaiting.headingCheck.notHeadingNotice) carry the
// deep link movera-driver://trip/{tripId} (singular). PushOpen only knew
// movera-driver://offers/{id} and movera-driver://trips/{id}, so main.dart
// _openPush fell through and pushed the bell list over the trip screen.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/push/push_platform.dart';

Map<String, dynamic> _contract() =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

PushOpen _open(String link) => PushOpen(
  notificationId: 'ntf_1',
  deepLink: link.replaceFirst('{tripId}', 'trp_1'),
);

void main() {
  test('Ride Check push link is understood as a trip link', () {
    final contract = _contract();
    final link =
        (((contract['onTrip'] as Map)['rideCheck'] as Map)['push']
                as Map)['deepLink']['driver']
            as String;
    expect(link, 'movera-driver://trip/{tripId}');
    final open = _open(link);
    expect(open.offerId, isNull);
    expect(open.routeChangeTripId, 'trp_1');
  });

  test('"Not driving towards the rider" notice link is a trip link', () {
    final contract = _contract();
    final link =
        (((contract['pickupWaiting'] as Map)['headingCheck']
                    as Map)['notHeadingNotice']
                as Map)['deepLink']
            as String;
    expect(link, 'movera-driver://trip/{tripId}');
    expect(_open(link).routeChangeTripId, 'trp_1');
  });

  test('route-change trips/{id} and offers/{id} links keep working', () {
    expect(_open('movera-driver://trips/{tripId}').routeChangeTripId, 'trp_1');
    final offer = _open('movera-driver://offers/off_1');
    expect(offer.offerId, 'off_1');
    expect(offer.routeChangeTripId, isNull);
    expect(_open('movera-driver://trip/').routeChangeTripId, isNull);
    expect(_open('movera-driver://tripx/trp_1').routeChangeTripId, isNull);
    expect(_open('movera-driver://notifications').routeChangeTripId, isNull);
  });
}
