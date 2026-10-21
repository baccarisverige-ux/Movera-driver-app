import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/session/driver_route_observer.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// D3 (driver-74/75): "Leave now" while a screen or sheet covers Home keeps
// the accepted ride and opens it once Home is back on top.

/// Dispatch with no offers of its own.
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
      ClaimResult.success(RideOffer.reservation(demoReservationRequest));
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(WidgetTester tester) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          // As in the app: Home hears routes covering it and leaving.
          navigatorObservers: [driverRouteObserver],
          home: DriverHome(
            sessionController: DriverSessionController(initialOnline: true),
            initialOnline: true,
            dispatchRepository: _Dispatch(),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    ExclusiveAnswers.instance.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  for (final cover in ['screen', 'sheet']) {
    testWidgets(
      'driver-74/75: "Leave now" under a $cover keeps the ride in Accepted '
      'and opens the trip once Home is back on top',
      (tester) async {
        ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
        await _pumpHome(tester);
        await _frames(tester, const Duration(seconds: 40));
        expect(find.byType(AcceptRide), findsNothing);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        if (cover == 'screen') {
          navigator.push(MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('covering')),
          ));
        } else {
          showModalBottomSheet<void>(
            context: navigator.context,
            builder: (_) => const SizedBox(height: 200, child: Text('covering')),
          );
        }
        // "Leave now" (about 46 s into the demo day) passes while covered.
        await _frames(tester, const Duration(seconds: 9));
        expect(find.byType(AcceptRide), findsNothing);
        expect(ScheduledRideStore.upcoming, contains(demoReservationRequest));
        expect(_saidTitles, isNot(contains('Leave now for 07:40 pickup')));

        navigator.pop();
        await _frames(tester, const Duration(seconds: 2));
        expect(find.byType(AcceptRide), findsOneWidget);
        expect(
          tester.widget<AcceptRide>(find.byType(AcceptRide)).pickupAddress,
          'Gamla vägen, Stockholm',
        );
        expect(_saidTitles, contains('Leave now for 07:40 pickup'));
        expect(ScheduledRideStore.upcoming, isNot(contains(demoReservationRequest)));
        expect(ScheduledRideStore.backupNote.value, isNull);
        tester.takeException();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}

Iterable<String> get _saidTitles => IslandMessages.posted.map((m) => m.title);
