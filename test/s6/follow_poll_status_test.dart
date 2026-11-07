// S6 I-3 (2026-11-07): while the trip stream is down (503) the 10 s follow
// poll read the trip but only applied the ETA / waiting / pickup: no
// arrived, on board, cancel, no-show or release reached the screen until
// the stream came back. Fail before on main 00762a7a: matrix E6.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';

import 's6_harness.dart';

const _history = <ActiveRideStage, List<String>>{
  ActiveRideStage.headingToPickup: ['accepted', 'driver_to_pickup'],
  ActiveRideStage.waitingForRider: ['accepted', 'driver_to_pickup', 'arrived'],
  ActiveRideStage.onTrip: [
    'accepted',
    'driver_to_pickup',
    'arrived',
    'rider_onboard',
    'in_trip',
  ],
};

enum _Want {
  heading,
  waiting,
  onTrip,
  riderCancelled,
  removed,
  outcome,
  finished,
}

typedef _Case = ({
  String name,
  String status,
  _Want want,
  String kind,
  Map<String, Object?> extra,
  ActiveRideStage from,
});

_Case _c(
  String name,
  String status,
  _Want want, {
  String kind = 'trip_projection',
  Map<String, Object?> extra = const {},
  ActiveRideStage from = ActiveRideStage.headingToPickup,
}) => (
  name: name,
  status: status,
  want: want,
  kind: kind,
  extra: extra,
  from: from,
);

final _cases = <_Case>[
  _c('driver_to_pickup', 'driver_to_pickup', _Want.heading),
  _c('arrived', 'arrived', _Want.waiting),
  _c('in_trip (server jump from heading)', 'in_trip', _Want.onTrip),
  _c(
    'approaching_dropoff',
    'approaching_dropoff',
    _Want.onTrip,
    from: ActiveRideStage.onTrip,
  ),
  _c('cancelled_by_rider', 'cancelled_by_rider', _Want.riderCancelled),
  _c(
    'rider_cancelled kind',
    'cancelled_by_rider',
    _Want.riderCancelled,
    kind: 'rider_cancelled',
  ),
  _c(
    'rider ended early (on board)',
    'cancelled_by_rider',
    _Want.finished,
    from: ActiveRideStage.onTrip,
    extra: {
      'finish': {
        'endedEarly': true,
        'endedBy': 'rider',
        'total': money(4000),
        'driverTotal': money(3000),
        'ratingAllowed': true,
      },
      'driverTotal': money(3000),
    },
  ),
  _c('cancelled_by_admin', 'cancelled_by_admin', _Want.outcome),
  _c(
    'no_show (admin)',
    'no_show',
    _Want.outcome,
    from: ActiveRideStage.waitingForRider,
  ),
  _c('failed (system)', 'failed', _Want.outcome, from: ActiveRideStage.onTrip),
  _c('reassigned (searching)', 'searching', _Want.removed),
  _c('booked released (requested)', 'requested', _Want.removed),
];

Future<Harness> _openTrip(
  WidgetTester tester,
  ActiveRideStage from, {
  String tripKind = 'now',
}) async {
  final h = Harness(tester);
  for (final s in _history[from]!) {
    h.server.change(s, send: false, tripKind: tripKind);
  }
  await h.rides.save(savedTrip(from));
  await h.openHome();
  await h.frames(const Duration(seconds: 2));
  expect(find.byType(AcceptRide), findsOneWidget);
  return h;
}

Future<void> _expectWant(Harness h, _Want want, String label) async {
  final saved = await h.rides.read();
  final titles = h.islandTitles;
  final state =
      'AcceptRide=${find.byType(AcceptRide).evaluate().length} '
      'saved=${saved?.stage} island=$titles';
  switch (want) {
    case _Want.heading:
    case _Want.waiting:
    case _Want.onTrip:
      final stage = switch (want) {
        _Want.heading => ActiveRideStage.headingToPickup,
        _Want.waiting => ActiveRideStage.waitingForRider,
        _ => ActiveRideStage.onTrip,
      };
      expect(find.byType(AcceptRide), findsOneWidget, reason: '$label: $state');
      expect(saved?.stage, stage, reason: '$label: $state');
    case _Want.riderCancelled:
      expect(find.byType(AcceptRide), findsNothing, reason: '$label: $state');
      expect(
        titles,
        contains(HomeIslandNotices.riderCancelled.title),
        reason: '$label: $state',
      );
    case _Want.removed:
      expect(find.byType(AcceptRide), findsNothing, reason: '$label: $state');
      expect(
        titles,
        contains(HomeIslandNotices.tripRemoved.title),
        reason: '$label: $state',
      );
    case _Want.outcome:
      expect(
        find.byKey(const ValueKey<String>('trip-outcome-sheet')),
        findsOneWidget,
        reason: '$label: $state',
      );
    case _Want.finished:
      expect(
        find.byType(DriverRideCompleted),
        findsOneWidget,
        reason: '$label: $state',
      );
  }
}

void main() {
  for (final tripKind in ['now', 'scheduled']) {
    for (final c in _cases) {
      testWidgets('E6 [$tripKind] stream down (503), 10 s follow poll: '
          '${c.name}', (tester) async {
        final h = await _openTrip(tester, c.from, tripKind: tripKind);
        h.server.eventsMode = 'down';
        unawaited(h.server.live?.close());
        await h.frames(const Duration(seconds: 2));
        h.server.change(
          c.status,
          kind: c.kind,
          extra: c.extra,
          send: false,
          tripKind: tripKind,
        );
        await h.frames(const Duration(seconds: 30));
        await _expectWant(h, c.want, '[$tripKind] E6 ${c.name}');
        await h.leave();
      });
    }
  }

  testWidgets('E6 stream down and the trip read answers 404: the trip is '
      'given back (Trip removed), as on the stream', (tester) async {
    final h = await _openTrip(tester, ActiveRideStage.headingToPickup);
    h.server.eventsMode = 'down';
    unawaited(h.server.live?.close());
    await h.frames(const Duration(seconds: 2));
    h.server.trip = null;
    await h.frames(const Duration(seconds: 30));
    await _expectWant(h, _Want.removed, 'E6 404');
    await h.leave();
  });
}
