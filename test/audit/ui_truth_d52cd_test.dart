// Wave 5 D5.2 (UI truth), parts c and d: history, safety, scheduled rides
// and map widgets show only what really happened.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/presentation/driver/ride%20completed/ride_completed.dart';
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart';
import 'package:movera/presentation/driver/ride%20history/ride_history.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';

import '../../integration_test/headless_map_platform.dart';

/// [screen] as the app's first route on a phone.
/// A screen that never settles (a live animation) is pumped once.
Future<void> _show(WidgetTester tester, Widget screen,
    {bool settle = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(home: screen),
  ));
  settle ? await tester.pumpAndSettle() : await tester.pump();
}

/// Trip details of [status] for a 152,40 kr trip with a 40 kr bonus.
Future<void> _detail(WidgetTester tester,
    {TripStatus status = TripStatus.completed,
    List<RideCheckRecord> checks = const []}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      home: DriverRideHistoryDetail(
        record: TripHistoryRecord(
          tripId: 'trip-1',
          riderName: 'Karin',
          whenLabel: '15/10/2026, 07:59',
          pickup: 'Gamla vägen',
          dropoff: 'Solna centrum',
          fare: '152,40 kr',
          category: 'Comfort',
          status: status,
          driverBonus: '40 kr',
        ),
        loadRideChecks: (_) async => checks,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

RideOffer _offer(String id, {String payment = 'Card'}) => RideOffer(
      id: id,
      category: 'Comfort',
      fare: const Money(minorUnits: 10000),
      rating: '4.9',
      pickupMinutes: 2,
      pickupKm: 1,
      tripMinutes: 10,
      tripKm: 5,
      pickup: 'Pickup $id, Stockholm',
      dropoff: 'Dropoff, Stockholm',
      pickupPosition: const GeoPoint(59.3279, 18.0615),
      dropoffPosition: const GeoPoint(59.3326, 18.0649),
      isNearby: true,
      followsDestination: true,
      payment: payment,
    );

/// Dispatch whose nearby feed the test sends.
class _Dispatch implements DispatchRepository {
  final nearby = StreamController<List<RideOffer>>.broadcast();
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => nearby.stream;
  @override
  Stream<List<RideOffer>> watchNextTripOffers() => const Stream.empty();
  @override
  void refreshOffers() {}
  @override
  void releaseReservation(String reservationId) {}
  @override
  Stream<ReservationRequestPreview> watchAssignments() => const Stream.empty();
  @override
  Future<ClaimResult> claimOffer(String offerId) async =>
      const ClaimResult.unavailable();
  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() => const Stream.empty();
}

/// Safety toolkit: Contact 112 > Call 112 with a dial launch answering
/// [opened].
Future<void> _call112(WidgetTester tester,
    {required bool opened, bool web = false}) async {
  await _show(tester, Scaffold(
      body: SafetyToolKits(launchEmergencyDial: () async => opened, web: web)));
  await tester.tap(find.text('Contact 112'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Call 112'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  testWidgets("driver-u151: Ride completed names the payment in the driver's "
      'language and never calls an in-app payment Card', (tester) async {
    DriverAppTexts.language = 'sv';
    await _show(tester, const DriverRideCompleted(paidByCash: false));
    expect(find.text('I appen'), findsOneWidget);
    expect(find.text('Card'), findsNothing);
    await _show(tester, const DriverRideCompleted(paidByCash: true));
    expect(find.text('Kontant'), findsOneWidget);
  });

  testWidgets('driver-83: a cancelled trip shows no ride cost and no bonus',
      (tester) async {
    await _detail(tester, status: TripStatus.cancelledByDriver);
    expect(find.text('152,40 kr'), findsNothing);
    expect(find.byKey(const ValueKey('history-driver-bonus')), findsNothing);
    tester.takeException();
  });

  testWidgets("driver-u156: a Ride check alert kept in the demo outbox is not "
      "shown as 'Movera safety team alerted'", (tester) async {
    final at = DateTime(2026, 10, 15, 7, 50);
    await _detail(tester, checks: [
      RideCheckRecord(
        id: 'rc-1',
        tripId: 'trip-1',
        trigger: RideCheckTrigger.longStop,
        reason: 'Your car has stopped for 4 min',
        openedAt: at,
        answeredAt: at,
        alertSent: true,
      ),
    ]);
    expect(find.text('Movera safety team alerted'), findsNothing);
    expect(find.text(
            'Demo: alert kept on this phone only. No one at Movera was notified.'),
        findsOneWidget);
    tester.takeException();
  });

  testWidgets('driver-85: with only cancelled trips, History says there is no '
      'completed ride and counts the trips it lists', (tester) async {
    await _show(tester, DriverRideHistory(loadHistory: () async => [
          for (var i = 0; i < 3; i++)
            TripHistoryRecord(
              tripId: 'c$i',
              riderName: 'Karin',
              whenLabel: 'Today',
              pickup: 'Gamla vägen',
              dropoff: 'Solna centrum',
              fare: '152,40 kr',
              category: 'Comfort',
              status: TripStatus.cancelledByDriver,
              completedAt: DateTime.now(),
            ),
        ]));
    expect(find.text('No completed rides in this period.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-view-all-rides')));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 rides in'), findsOneWidget);
  });

  testWidgets("driver-u160: Radar's refresh pill lights only for new trips "
      "the driver's filter shows", (tester) async {
    final maps = GoogleMapsFlutterPlatform.instance;
    GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
    addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
    final dispatch = _Dispatch();
    await _show(tester, RideRequests(
        dispatchRepository: dispatch,
        offerFilter: (offer) => offer.payment != 'Cash'), settle: false);
    const pill = ValueKey<String>('radar-refresh-new');
    dispatch.nearby.add([_offer('a')]);
    await tester.pump();
    dispatch.nearby.add([_offer('a'), _offer('cash', payment: 'Cash')]);
    await tester.pump();
    expect(find.byKey(pill), findsNothing, reason: 'cash rides are off');
    dispatch.nearby.add([_offer('a'), _offer('b')]);
    await tester.pump();
    expect(find.byKey(pill), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets("driver-91: in a browser the toolkit does not claim the dialer "
      "opened", (tester) async {
    await _call112(tester, opened: true, web: true);
    expect(find.textContaining('dialer opened'), findsNothing);
    expect(find.textContaining('Your browser was asked to call 112'),
        findsOneWidget);
  });
}
