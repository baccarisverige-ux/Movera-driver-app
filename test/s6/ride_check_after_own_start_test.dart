// PR #636 (safety): the whole way from the trip stream to the open card.
// After this phone's own Start the server's ride check comes as a
// trip_projection with the SAME version as the Start; the stream must hand
// it to the trip screen and the screen must open the Ride Check card.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';

import 's6_harness.dart';

void main() {
  testWidgets('own Start, then the server ride check at the same version: '
      'the Ride Check card opens', (tester) async {
    final h = Harness(tester);
    for (final s in ['accepted', 'driver_to_pickup', 'arrived']) {
      h.server.change(s, send: false);
    }
    h.server.change('rider_onboard', send: false);
    await h.rides.save(savedTrip(ActiveRideStage.onTrip));
    await h.openHome();
    await h.frames(const Duration(seconds: 2));
    expect(find.byType(AcceptRide), findsOneWidget);

    // This phone's own Start: the server moves to in_trip (one version
    // up) and its stream sends the echo.
    unawaited(h.live.trips.start(tripId));
    await h.frames(const Duration(seconds: 2));
    expect(h.server.trip!['status'], 'in_trip');
    expect(
      find.byKey(const ValueKey<String>('ride-check-layer')),
      findsNothing,
    );

    // 2 minutes standing: the server asks, the trip's version unchanged.
    final version = h.server.trip!['version']! as int;
    final now = DateTime.now().toUtc();
    final trip = projection(
      'in_trip',
      version: version,
      extra: {
        'rideCheck': {
          'checkId': 'rc_own_start',
          'trigger': 'long_stop',
          'askedAt': now.toIso8601String(),
          'answerBy': now.add(const Duration(minutes: 2)).toIso8601String(),
        },
      },
    );
    h.server.trip = trip;
    final sequence = h.server.log.length + 1;
    final envelope = <String, Object?>{
      'eventId': 'evt_$sequence',
      'tripId': tripId,
      'sequence': sequence,
      'version': version,
      'kind': 'trip_projection',
      'occurredAt': now.toIso8601String(),
      'serverTime': now.toIso8601String(),
      'projection': trip,
    };
    h.server.log.add(envelope);
    h.server.live!.line('id: $sequence\ndata: ${jsonEncode(envelope)}\n\n');
    await h.frames(const Duration(seconds: 3));

    expect(
      find.byKey(const ValueKey<String>('ride-check-layer')),
      findsOneWidget,
      reason: 'the ride check was dropped as the echo of own Start',
    );
    await h.leave();
  });
}
