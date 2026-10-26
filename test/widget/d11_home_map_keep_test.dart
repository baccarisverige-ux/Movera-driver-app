import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Counts native maps made and camera moves.
class _Maps extends HeadlessMapPlatform {
  int created = 0, moves = 0;
  @override
  Future<void> init(int mapId) async => created++;
  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async => moves++;
}

class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  final _nearby = StreamController<List<RideOffer>>.broadcast();
  List<RideOffer> offers = const [];

  void publish(List<RideOffer> next) {
    offers = List<RideOffer>.unmodifiable(next);
    _nearby.add(offers);
  }

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream<List<RideOffer>>.multi((sink) {
    final sub = _nearby.stream.listen(sink.addSync);
    sink.onCancel = sub.cancel;
    sink.addSync(offers);
  }, isBroadcast: true);

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

RideOffer _trip(String id, {String payment = 'Card'}) => RideOffer(
  id: id,
  category: 'Comfort',
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  pickupMinutes: 3,
  pickupKm: 0.9,
  tripMinutes: 12,
  tripKm: 5.2,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3428, 18.0475),
  isNearby: true,
  followsDestination: false,
  payment: payment,
);

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<DriverSessionController> _pumpHome(
  WidgetTester tester,
  DispatchRepository dispatch,
  _Maps maps0,
) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = maps0;
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = DriverSessionController();
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: session,
            dispatchRepository: dispatch,
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
  await _frames(tester, const Duration(milliseconds: 1500));
  return session;
}

// D-11: opening the Radar list (and closing it) keeps the one Home map and
// its camera; before, the map was made again and the camera started over.
void main() {
  testWidgets('the Radar list opens over the same Home map', (tester) async {
    // A returning driver: the map opens at the last saved position.
    SharedPreferences.setMockInitialValues({
      DriverStartPosition.key: '{"lat":59.3326,"lng":18.0649}',
    });
    DriverStartPosition.clearMemory();
    final maps = _Maps();
    final dispatch = _Dispatch();
    await _pumpHome(tester, dispatch, maps);
    dispatch.publish([_trip('r1')]);
    // Home's demo Exclusive offer comes first; the Radar trip after it.
    await _frames(tester, const Duration(milliseconds: 2600));
    await _frames(
      tester,
      DriverOfferRules.current.exclusiveAcceptTime + const Duration(seconds: 2),
    );
    final made = maps.created;
    expect(made, 1);
    // Owner N1: the island's middle opens the list.
    final allOffers = find.byKey(const ValueKey<String>('island-radar-offers'));
    expect(allOffers, findsOneWidget);
    await tester.tap(allOffers);
    await _frames(tester, const Duration(milliseconds: 400));
    expect(find.byType(RideRequests), findsOneWidget);
    expect(maps.created, made, reason: 'no second native map');
    await tester.tap(find.byTooltip('Back'));
    await _frames(tester, const Duration(milliseconds: 400));
    expect(find.byType(RideRequests), findsNothing);
    expect(maps.created, made, reason: 'the same map is back under the sheet');
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  });
}
