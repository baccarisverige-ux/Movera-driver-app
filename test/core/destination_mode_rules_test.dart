import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/dispatch/demo_destination_trips.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/destination_filter.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/dispatch/next_trip_gate.dart';
import 'package:movera/core/geo/geo_point.dart';

void main() {
  group('R13-9: on-the-way filter', () {
    const stockholm = GeoPoint(59.3326, 18.0649);
    const arlanda = GeoPoint(59.6498, 17.9238);
    // Road route north on the E4.
    const e4 = <GeoPoint>[
      stockholm,
      GeoPoint(59.3490, 18.0400),
      GeoPoint(59.3950, 17.9900),
      GeoPoint(59.4300, 17.9500),
      GeoPoint(59.5200, 17.9200),
      GeoPoint(59.6000, 17.9100),
      arlanda,
    ];
    const places = <String, GeoPoint>{
      'Arlanda': GeoPoint(59.6510, 17.9300),
      'Upplands Väsby': GeoPoint(59.5184, 17.9113),
      'Sollentuna': GeoPoint(59.4280, 17.9507),
      'Södertälje': GeoPoint(59.1955, 17.6253),
      'Nacka': GeoPoint(59.3105, 18.1637),
    };
    bool follows(
      String place, {
      DestinationModeRules rules = const DestinationModeRules(),
    }) => DestinationFilter.follows(
      driver: stockholm,
      destination: arlanda,
      dropoff: places[place]!,
      route: e4,
      rules: rules,
    );

    test(
      'Stockholm → Arlanda: Arlanda, Väsby, Sollentuna yes; Södertälje, Nacka no',
      () {
        expect(follows('Arlanda'), isTrue);
        expect(follows('Upplands Väsby'), isTrue);
        expect(follows('Sollentuna'), isTrue);
        expect(follows('Södertälje'), isFalse);
        expect(follows('Nacka'), isFalse);
      },
    );

    test('focus: final only near Arlanda, on the way only along the route', () {
      const finalOnly = DestinationModeRules(focusOnTheWayOn: false);
      const wayOnly = DestinationModeRules(focusFinalDestinationOn: false);
      expect(follows('Arlanda', rules: finalOnly), isTrue);
      expect(follows('Sollentuna', rules: finalOnly), isFalse);
      expect(follows('Sollentuna', rules: wayOnly), isTrue);
      expect(follows('Arlanda', rules: wayOnly), isFalse);
    });

    test(
      'demo: trips along the route pass the filter, the outside ones do not',
      () async {
        final trips = DemoDestinationTrips.along(
          driver: stockholm,
          destination: arlanda,
          route: e4,
          destinationLabel: 'Arlanda',
        );
        for (final trip in trips) {
          expect(
            DestinationFilter.follows(
              driver: stockholm,
              destination: arlanda,
              dropoff: trip.dropoffPosition,
              route: e4,
            ),
            trip.followsDestination,
            reason: trip.id,
          );
        }
        expect(trips.where((t) => t.followsDestination), hasLength(3));
        final repo = DemoDispatchRepository();
        addTearDown(repo.dispose);
        final seen = <List<String>>[];
        final sub = repo.watchNearbyOffers().listen(
          (o) => seen.add([for (final t in o) t.id]),
        );
        repo.showDestinationTrips(trips);
        repo.clearDestinationTrips();
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        expect(
          seen.any((ids) => ids.first == 'demo-destination-final'),
          isTrue,
        );
        expect(
          seen.last.any((id) => id.startsWith(DemoDestinationTrips.idPrefix)),
          isFalse,
        );
      },
    );

    test('daily limit and time limit', () {
      var now = DateTime(2026, 10, 18, 8);
      final session = DestinationModeSession(now: () => now);
      expect(session.refusal(), isNull);
      session.started();
      session.started();
      expect(session.refusal(), DestinationRefusal.usedToday);
      expect(session.timeLeft(), const Duration(hours: 2));
      now = now.add(const Duration(hours: 2, minutes: 1));
      expect(session.expired(), isTrue);
      now = DateTime(2026, 10, 19, 8);
      expect(session.refusal(), isNull);
    });
  });

  test('admin export: zone values read, missing ones are the defaults', () {
    final export = <String, dynamic>{
      'driverApp': {
        'destinationMode': {
          'svc-stockholm': {
            'enabled': true,
            'timeLimitHours': 3,
            'corridorKm': 8,
            'focusFinalDestinationOn': false,
            'focus': 'onTheWay',
          },
        },
        'nextTrips': {
          'svc-stockholm': {
            'withinKmOfDropoffOn': false,
            'withinMinutesOfDropoff': 15,
          },
        },
      },
    };
    final config = DriverHomeAdminContentService(rulesExport: export).load();
    final destination = config.destinationMode!;
    expect(destination.timeLimitHours, 3);
    expect(destination.corridorKm, 8);
    expect(destination.focus, DestinationFocus.onTheWay);
    expect(destination.destinationsPerDay, 2);
    expect(destination.dailyLimitOn, isTrue);
    final next = config.nextTrips!;
    expect(next.withinKmOfDropoffOn, isFalse);
    expect(next.withinKmOfDropoff, 5);
    expect(next.withinMinutesOfDropoff, 15);
    expect(next.radarOffers, isFalse);

    final (other, otherNext) = DriverTripRulesExport.forZone(
      export,
      'svc-goteborg',
    );
    expect(other.timeLimitHours, 2);
    expect(other.corridorKm, 5);
    expect(other.focus, DestinationFocus.both);
    expect(otherNext.withinKmOfDropoff, 5);
    expect(otherNext.withinMinutesOfDropoff, 10);
    expect(
      const DriverHomeAdminContentService().load().destinationMode,
      isNull,
    );
  });

  test(
    'R13-18: next trips only on the final leg, within km or min; demo unchanged',
    () {
      bool allows({
        bool demo = false,
        bool onTrip = true,
        bool toFinal = true,
        double? meters,
        double? seconds,
        NextTripRules rules = const NextTripRules(),
      }) => NextTripGate.allows(
        demo: demo,
        onTrip: onTrip,
        toFinalDropoff: toFinal,
        metersToDropoff: meters,
        secondsToDropoff: seconds,
        rules: rules,
      );

      expect(allows(onTrip: false, meters: 100), isFalse);
      expect(allows(toFinal: false, meters: 100), isFalse);
      expect(allows(meters: 4000, seconds: 1200), isTrue);
      expect(allows(meters: 9000, seconds: 500), isTrue);
      expect(allows(meters: 9000, seconds: 1200), isFalse);
      const kmOnly = NextTripRules(withinMinutesOfDropoffOn: false);
      expect(allows(meters: 9000, seconds: 500, rules: kmOnly), isFalse);
      const wholeLeg = NextTripRules(
        withinKmOfDropoffOn: false,
        withinMinutesOfDropoffOn: false,
      );
      expect(allows(meters: 40000, seconds: 3600, rules: wholeLeg), isTrue);
      // Demo: as before, no limits (also on the way to a stop).
      expect(allows(demo: true, toFinal: false, meters: 25000), isTrue);
      expect(allows(demo: true, onTrip: false), isFalse);
    },
  );
}
