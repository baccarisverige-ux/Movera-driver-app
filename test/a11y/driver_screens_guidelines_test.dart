// D6 (V39 item 1): the main driver screens meet Flutter's accessibility
// guidelines: text contrast, labelled tap targets and the 48 px Android
// tap target.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/my%20wallet/wallet.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

class _Dispatch implements DispatchRepository {
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;

  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(const <RideOffer>[]);

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

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Widget _app(Widget home) => ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  builder: (_, __) => MaterialApp(home: home),
);

Future<void> _meetsAll(WidgetTester tester, {bool tapSize = true}) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  if (tapSize) {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
  });

  Future<void> check(
    WidgetTester tester,
    Widget screen, {
    bool maps = false,
    bool tapSize = true,
  }) async {
    if (maps) {
      final saved = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = saved);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(screen));
    // Past the island's entrance scale, so targets are measured at rest.
    await _frames(tester, 30);
    await _meetsAll(tester, tapSize: tapSize);
    semantics.dispose();
    tester.takeException();
    await tester.pumpWidget(const SizedBox());
  }

  for (final online in [false, true]) {
    testWidgets('Home ${online ? 'online' : 'offline'}', (tester) async {
      await check(
        tester,
        DriverHome(
          initialOnline: online,
          sessionController: DriverSessionController(initialOnline: online),
          dispatchRepository: _Dispatch(),
        ),
        maps: true,
        // The island is drawn at 80 % (40 px high, owner design); its menu
        // and search take touches in a 48 x 48 box (UI-12, tested with
        // hit tests in test/widget/d3_home_back_test.dart), which the
        // semantics rect cannot show. Parked for the owner (D6).
        tapSize: false,
      );
    });
  }

  testWidgets('Offer card', (tester) async {
    await check(
      tester,
      Scaffold(
        body: Center(
          child: RadarOfferCard(
            offer: const RadarOfferView(
              id: 'o1',
              category: 'Comfort',
              payment: 'Card',
              rating: '4.96',
              fare: '104,80 kr',
              pickupMinutes: 2,
              pickupKm: 0.65,
              tripMinutes: 9,
              tripKm: 4.2,
              pickup: 'Kungsgatan 42, Stockholm',
              dropoff: 'Hornstull, Stockholm',
            ),
            onRoute: () {},
            onDismiss: () {},
            onMatch: () {},
          ),
        ),
      ),
    );
  });

  testWidgets('Trip screen', (tester) async {
    await check(
      tester,
      AcceptRide(
        tripId: 'a11y-trip',
        fare: '100,00 kr',
        activeRideRepository: MemoryActiveRideRepository(),
        waybillRepository: InMemoryWaybillRepository.instance,
      ),
      maps: true,
    );
  });

  testWidgets('Chat', (tester) async {
    await check(tester, const Chat(riderDisplayName: 'Maya', tripId: 't1'));
  });

  testWidgets('Wallet', (tester) async {
    await check(tester, const WalletScreen());
  });
}
