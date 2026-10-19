import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart'
    show GoogleMapsFlutterPlatform;
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/routing/route_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// R11-7: a Radar offer on Home draws only its trip, pickup → drop-off,
// with labelled pins (pickup = minutes there, drop-off = trip length).

class _Dispatch implements DispatchRepository {
  final List<RideOffer> offers;
  _Dispatch(this.offers);

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) => sink.addSync(offers));

  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);

  @override
  void refreshOffers() {}

  @override
  void releaseReservation(String reservationId) {}

  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();

  @override
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
}

class _Routes implements RouteRepository {
  final origins = <GeoPoint>[];

  @override
  Future<RoadRoute> drivingRoute({
    required GeoPoint origin,
    required GeoPoint destination,
  }) async {
    origins.add(origin);
    return RoadRoute(
      points: [
        origin,
        GeoPoint(
          (origin.latitude + destination.latitude) / 2,
          origin.longitude,
        ),
        destination,
      ],
      distanceMeters: 4000,
      durationSeconds: 600,
    );
  }
}

const _pickup = GeoPoint(59.3335, 18.0610);
const _dropoff = GeoPoint(59.3428, 18.0475);

/// Home online with one Radar trip on its deck and its route drawn.
Future<_Routes> _homeWithRadarTrip(WidgetTester tester) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final routes = _Routes();
  final dispatch = _Dispatch([
    RideOffer(
      id: 'route-trip',
      category: 'Comfort',
      fare: '168 kr',
      rating: '4.92',
      pickupMinutes: 7,
      pickupKm: 2.1,
      tripMinutes: 30,
      tripKm: 14.2,
      pickup: 'Sveavägen 20, Stockholm',
      dropoff: 'Kista Galleria, Stockholm',
      pickupPosition: _pickup,
      dropoffPosition: _dropoff,
      isNearby: true,
      followsDestination: false,
    ),
  ]);
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: DriverSessionController(),
            dispatchRepository: dispatch,
            routeRepository: routes,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
  final total = const Duration(milliseconds: 1500) +
      DriverOfferRules.current.exclusiveAcceptTime +
      const Duration(milliseconds: 7500);
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    tester
        .widget<RadarOfferDeck>(
          find.byKey(const ValueKey<String>('radar-home-deck')),
        )
        .ids,
    ['route-trip'],
  );
  // The marker bitmaps are painted off the fake clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump(const Duration(milliseconds: 300));

  return routes;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  testWidgets('a Radar offer puts nothing on the map; its route button shows '
      'pickup → drop-off only, with minute chips, and the route leaves with '
      'the last card',
      (tester) async {
    final routes = await _homeWithRadarTrip(tester);
    bool offerLine(Polyline line) =>
        line.polylineId.value.startsWith('direct_offer') ||
        line.polylineId.value.startsWith('offer_route_light');
    bool offerPin(Marker m) => m.markerId.value.startsWith('radar_');
    // R15-10: no line and no pins while the Radar card is up.
    final before = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    expect(before.polylines!.where(offerLine), isEmpty);
    expect(before.markers!.where(offerPin), isEmpty);
    // The driver asks for the route with the card's route button.
    tester.widget<RadarOfferCard>(find.byType(RadarOfferCard).first).onRoute!();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The marker bitmaps are painted off the fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    final route = map.polylines!
        .where((line) => line.polylineId.value.startsWith('direct_offer'))
        .toList();
    expect(route, isNotEmpty);
    const pickup = LatLng(59.3335, 18.0610);
    const dropoff = LatLng(59.3428, 18.0475);
    for (final line in route) {
      expect(line.points.first, pickup);
      expect(line.points.last, dropoff);
      expect(line.points, hasLength(3));
    }
    // No drive from the driver to the pickup was asked for.
    expect(routes.origins, everyElement(_pickup));

    Marker marker(String id) =>
        map.markers!.firstWhere((m) => m.markerId.value == id);
    final pickupPin = marker('radar_pickup');
    final dropoffPin = marker('radar_dropoff');
    expect(pickupPin.position, pickup);
    expect(dropoffPin.position, dropoff);
    expect(pickupPin.infoWindow.title, '7 min');
    expect(dropoffPin.infoWindow.title, '30 min');
    // R14-1: the bubble stands above each mark, centred on it.
    expect(pickupPin.anchor.dx, 0.5);
    expect(dropoffPin.anchor.dx, 0.5);
    expect(pickupPin.anchor.dy, greaterThan(0.5));

    // R13-3: the last card leaving takes its route and pins along.
    // The driver closes the only card with its ×.
    tester.widget<RadarOfferCard>(find.byType(RadarOfferCard).first).onClose!();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey<String>('radar-home-deck')), findsNothing);
    final after = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    expect(after.polylines!.where(offerLine), isEmpty);
    expect(after.markers!.where(offerPin), isEmpty);
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });
}
