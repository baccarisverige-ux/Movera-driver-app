// S6 I-1 (safety, 2026-11-07): a Ride Check the server asks while a menu
// page covers the trip stayed hidden under it, and a tap on the trip's
// push did not bring the trip back (main.dart returned without doing
// anything). Fail before: X1 (menu page still on top).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/open_trip_screens.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';

import 's6_harness.dart';

const _onTrip = [
  'accepted',
  'driver_to_pickup',
  'arrived',
  'rider_onboard',
  'in_trip',
];

Future<Harness> _openTripUnderMenuPage(WidgetTester tester) async {
  final h = Harness(tester);
  for (final s in _onTrip) {
    h.server.change(s, send: false);
  }
  await h.rides.save(savedTrip(ActiveRideStage.onTrip));
  await h.openHome();
  await h.frames(const Duration(seconds: 2));
  expect(find.byType(AcceptRide), findsOneWidget);
  final trip = tester.element(find.byType(AcceptRide));
  unawaited(
    Navigator.of(trip).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
          body: Text('History', key: ValueKey<String>('menu-page')),
        ),
      ),
    ),
  );
  await h.frames(const Duration(seconds: 1));
  expect(find.byKey(const ValueKey<String>('menu-page')), findsOneWidget);
  return h;
}

void main() {
  testWidgets('X1 Ride Check asked while a menu page covers the trip: the '
      'driver sees it', (tester) async {
    final h = await _openTripUnderMenuPage(tester);
    final now = DateTime.now().toUtc();
    h.server.change(
      'in_trip',
      extra: {
        'rideCheck': {
          'checkId': 'rc_1',
          'trigger': 'long_stop',
          'askedAt': now.toIso8601String(),
          'answerBy': now.add(const Duration(minutes: 2)).toIso8601String(),
        },
      },
    );
    await h.frames(const Duration(seconds: 4));
    expect(
      find.byKey(const ValueKey<String>('menu-page')),
      findsNothing,
      reason: 'the menu page still covers the Ride Check',
    );
    expect(
      find.byKey(const ValueKey<String>('ride-check-layer')),
      findsOneWidget,
    );
    await h.leave();
  });

  testWidgets('a tap on the trip push brings the trip back from under a '
      'menu page and reads the trip again', (tester) async {
    final h = await _openTripUnderMenuPage(tester);
    // The Ride Check event is lost (a half-open stream); its push comes.
    final now = DateTime.now().toUtc();
    h.server.change(
      'in_trip',
      send: false,
      extra: {
        'rideCheck': {
          'checkId': 'rc_2',
          'trigger': 'long_stop',
          'askedAt': now.toIso8601String(),
          'answerBy': now.add(const Duration(minutes: 2)).toIso8601String(),
        },
      },
    );
    await h.frames(const Duration(seconds: 1));
    expect(
      find.byKey(const ValueKey<String>('ride-check-layer')),
      findsNothing,
    );
    expect(OpenTripScreens.isOpen(tripId), isTrue);
    expect(openTripPush(tripId), isTrue);
    await h.frames(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey<String>('menu-page')), findsNothing);
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('ride-check-layer')),
      findsOneWidget,
    );
    // A notice about another trip (pay changed, « Course annulée »): not
    // this screen's, the bell list opens on it.
    expect(openTripPush('trp_done', activeTripId: tripId), isFalse);
    await h.leave();
    expect(OpenTripScreens.isOpen(tripId), isFalse);
  });
}
