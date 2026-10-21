import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// Audit round 4, the dispatch contract seam (`ApiDispatchRepository`,
// `OfferWire`) and the config readers: driver-r4-4.

/// Contract `Offer` (openapi.yaml#Offer).
Map<String, dynamic> _wire({
  String id = 'o1',
  String kind = 'radar',
  String source = 'system',
  String? reasonCode,
  String? expiresAt,
}) => {
  'offerId': id,
  'tripId': 'trip-$id',
  'kind': kind,
  'status': 'open',
  'version': 1,
  'expiresAt': expiresAt ?? '2026-10-20T12:00:15Z',
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': source,
  if (reasonCode != null) 'reasonCode': reasonCode,
  'pickup': {'address': 'Tegnérgatan, Stockholm', 'lat': 59.3335, 'lng': 18.0610},
  'dropoff': {'address': 'Odengatan, Stockholm', 'lat': 59.3428, 'lng': 18.0475},
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);
  final List<RideOffer> offers;
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(offers);
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
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

Future<void> _until(WidgetTester tester, Finder finder, Duration limit) async {
  for (var t = Duration.zero;
      t < limit && finder.evaluate().isEmpty;
      t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _online(WidgetTester tester, List<RideOffer> offers) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(LayoutViewport(
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (_, __) => MaterialApp(
        home: DriverHome(
          sessionController: DriverSessionController(),
          dispatchRepository: _Dispatch(offers),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  group('driver-r4-4: Offer.kind, expiresAt and reasonCode', () {
    test('OfferWire keeps them', () {
      final offer = OfferWire.parse(_wire(
        kind: 'exclusive',
        reasonCode: 'nearby',
        expiresAt: '2026-10-20T12:00:15Z',
      ));
      expect(offer.kind, OfferKind.exclusive);
      expect(offer.reasonCode, 'nearby');
      expect(offer.expiresAt, DateTime.utc(2026, 10, 20, 12, 0, 15));
      expect(offer.isExclusive, isTrue);
      expect(OfferWire.parse(_wire()).isExclusive, isFalse);
    });

    testWidgets('a system kind=exclusive offer is the Exclusive sheet, '
        'with its reason', (tester) async {
      // The server lets it go in 8 s, not the app's 15 s.
      final expires = DateTime.now().add(const Duration(seconds: 8));
      await _online(tester, [
        OfferWire.parse(_wire(
          kind: 'exclusive',
          reasonCode: 'favourite',
          expiresAt: expires.toUtc().toIso8601String(),
        )),
      ]);
      final card = find.byKey(const ValueKey<String>('exclusive-offer-card-o1'));
      await _until(tester, card, const Duration(seconds: 5));
      expect(card, findsOneWidget);
      expect(find.byKey(const ValueKey<String>('radar-offer-card-o1')),
          findsNothing);
      expect(find.textContaining(RegExp(r"Rider's favourite · [0-8] s")),
          findsWidgets);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
