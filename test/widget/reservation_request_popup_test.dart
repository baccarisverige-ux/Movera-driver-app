import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_edge_dash.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

const _request = ReservationRequestPreview(
  category: 'Comfort',
  fare: '126.75 kr',
  pickupLabel: 'Pickup today at 07:40',
  pickupAddress: 'Gamla vägen, Stockholm',
  dropoffAddress: 'Solna centrum, Solna',
  pickupTime: '07:40',
  pickupDay: 'Today',
  tripMinutes: 19,
  tripKm: 9.4,
  pickup: GeoPoint(59.3362, 18.0714),
  dropoff: GeoPoint(59.3603, 18.0009),
  stops: [
    ReservationStop(
      address: 'Odenplan, Stockholm',
      point: GeoPoint(59.3430, 18.0496),
    ),
  ],
);

Widget _fakeMap(BuildContext context) =>
    const ColoredBox(key: ValueKey<String>('fake-map'), color: Color(0xFFE6EAED));

DateTime _sixOhSeven() => DateTime(2026, 10, 15, 6, 7);

const _hide = ValueKey<String>('reservation-hide');
const _reserveRadar = ValueKey<String>('home-radar-reserve');
const _radarTouch = ValueKey<String>('trip-radar-touch-target');

Future<void> _pumpSheet(
  WidgetTester tester,
  ReservationRequestPreview request, {
  VoidCallback? onHide,
}) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ReservationRequestSheet(
            request: request,
            mapBuilder: _fakeMap,
            clock: _sixOhSeven,
            onHide: onHide ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Home with the reservation popup switched on, as in the app.
Future<DemoDispatchRepository> _pumpHome(
  WidgetTester tester, {
  bool online = true,
  String losingOfferId = 'nearby-2',
}) async {
  final previous = DriverRuntimeConfig.current;
  DriverRuntimeConfig.current = DriverRuntimeConfig(
    simulatedArrival: previous.simulatedArrival,
    externalRouting: previous.externalRouting,
    skipAccountActivation: previous.skipAccountActivation,
    liveMapTicker: previous.liveMapTicker,
    islandHint: previous.islandHint,
  );
  addTearDown(() => DriverRuntimeConfig.current = previous);
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final dispatch = DemoDispatchRepository(
    claimDelay: const Duration(milliseconds: 600),
    newOfferDelay: const Duration(days: 1),
    externalClaimDelay: const Duration(days: 1),
    reservationRadarDelay: const Duration(days: 1),
    losingOfferId: losingOfferId,
  );
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: DriverSessionController(initialOnline: online),
            initialOnline: online,
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ),
  );
  return dispatch;
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

/// Past the demo delay to Home, the rise delay and the spring.
Future<void> _waitForPopup(WidgetTester tester) => _frames(
  tester,
  ReservationDemoTimings.homePopupAfter +
      HomeReservationSheet.riseDelay +
      const Duration(milliseconds: 1200),
);

Future<void> _end(WidgetTester tester, DemoDispatchRepository dispatch) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
  dispatch.dispose();
}

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
  });

  test('arrival time adds the ride to the pickup time', () {
    expect(_request.arrivalTime, '07:59');
    const late = ReservationRequestPreview(
      category: 'Comfort',
      fare: '1 kr',
      pickupLabel: '',
      pickupAddress: '',
      dropoffAddress: '',
      pickupTime: '23:50',
      pickupDay: 'Today',
      tripMinutes: 25,
      tripKm: 1,
      pickup: GeoPoint(0, 0),
      dropoff: GeoPoint(0, 0),
    );
    expect(late.arrivalTime, '00:15');
    expect(_request.untilPickup(_sixOhSeven()), const Duration(minutes: 93));
    expect(_request.untilPickup(DateTime(2026, 10, 15, 8)), isNull);
  });

  testWidgets('the popup shows the clean reservation card, no Accept/Decline', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    expect(find.text('RESERVATION REQUEST'), findsOneWidget);
    expect(find.text('Your next ride'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('reservation-picture')),
      findsOneWidget,
    );
    expect(find.byKey(_hide), findsOneWidget);
    expect(find.text('Comfort'), findsOneWidget);
    expect(find.text('Today, 07:40'), findsOneWidget);
    final fare = tester.widget<Text>(
      find.byKey(const ValueKey<String>('reservation-fare')),
    );
    expect(fare.textSpan!.toPlainText(), '126,75 kr');
    expect(find.text('Fare · in 1 h 33 min'), findsOneWidget);
    expect(find.text('19 min'), findsOneWidget);
    expect(find.text('9.4 km'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('fake-map')), findsOneWidget);
    expect(find.text('View route'), findsOneWidget);
    for (final label in ['PICKUP', 'STOP', 'DROP-OFF']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Gamla vägen, Stockholm'), findsOneWidget);
    expect(find.text('Odenplan, Stockholm'), findsOneWidget);
    expect(find.text('Solna centrum, Solna'), findsOneWidget);
    expect(find.text('07:40'), findsOneWidget);
    expect(find.text('1 stop'), findsOneWidget);
    expect(find.text('~07:59'), findsOneWidget);
    // The radar accepts and the × only hides: no buttons on the card.
    for (final word in ['Accept', 'Accept ride', 'Decline', 'Deny']) {
      expect(find.text(word), findsNothing);
    }
    // Card payment: nothing about it (notes R2).
    expect(find.text('Cash'), findsNothing);
    expect(find.text('CARD'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cash reservation shows only a Cash badge', (tester) async {
    const cash = ReservationRequestPreview(
      category: 'Comfort',
      fare: '126.75 kr',
      pickupLabel: '',
      pickupAddress: 'Gamla vägen, Stockholm',
      dropoffAddress: 'Solna centrum, Solna',
      pickupTime: '07:40',
      pickupDay: 'Today',
      tripMinutes: 19,
      tripKm: 9.4,
      pickup: GeoPoint(59.3362, 18.0714),
      dropoff: GeoPoint(59.3603, 18.0009),
      paidByCash: true,
    );
    await _pumpSheet(tester, cash);
    final badge = find.byKey(const ValueKey<String>('reservation-cash'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('Cash')), findsOneWidget);
    expect(find.text('STOP'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the popup map opens the full route and Back returns', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    await tester.tap(find.byKey(const ValueKey<String>('reservation-map-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The route screen that already exists, unchanged (notes R26).
    expect(find.byType(ReservationRouteMapPage), findsOneWidget);
    expect(find.text('07:59'), findsOneWidget);
    expect(find.text('Solna centrum, Solna'), findsWidgets);
    tester.takeException();

    await tester.tap(find.byKey(const ValueKey<String>('reservation-map-close')));
    await tester.pumpAndSettle();
    expect(find.byType(ReservationRouteMapPage), findsNothing);
    expect(find.text('Your next ride'), findsOneWidget);
    tester.takeException();
  });

  testWidgets('the popup shows on Home only while the driver is online', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester, online: false);
    await _waitForPopup(tester);
    await _frames(tester, const Duration(seconds: 2));
    // Offline: it waits in Scheduled rides, nothing rises.
    expect(find.text('Your next ride'), findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);

    tester
        .widget<GestureDetector>(find.byKey(_radarTouch))
        .onTap!
        .call();
    await _frames(tester, const Duration(milliseconds: 1500));
    // Radar goes live first, then the sheet rises from under the dock.
    expect(find.text('Your next ride').hitTestable(), findsNothing);
    await _frames(tester, const Duration(milliseconds: 1500));
    expect(find.text('Your next ride'), findsOneWidget);
    expect(find.byKey(_reserveRadar), findsOneWidget);
    expect(_said.where((t) => t == 'New reservation'), hasLength(1));
    await _end(tester, dispatch);
  });

  testWidgets('the popup rises as an extension of the Home sheet', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _frames(
      tester,
      ReservationDemoTimings.homePopupAfter + HomeReservationSheet.riseDelay,
    );
    final sheet = find.byKey(const ValueKey<String>('home-reservation-sheet'));
    expect(sheet, findsOneWidget);
    final rising = tester.getRect(sheet).top;
    await _frames(tester, const Duration(milliseconds: 1200));
    final settled = tester.getRect(sheet);
    // It came up from below and settled about half the screen high.
    expect(rising, greaterThan(settled.top));
    expect(settled.top, inInclusiveRange(812 * 0.15, 812 * 0.5));
    // Edge to edge, down to the screen bottom behind the dock.
    expect(settled.left, lessThanOrEqualTo(0));
    expect(settled.right, greaterThanOrEqualTo(375));
    expect(settled.bottom, closeTo(812, 1));
    final box = tester.widget<DecoratedBox>(sheet);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(24)),
    );
    final border = decoration.border! as Border;
    expect(border.top.color, const Color(0xFF111518));
    expect(border.top.width, 1);

    // While it shows the radar is a black Accept · TAP, the dock contour
    // is black and the green online dash is gone.
    final radar = find.byKey(_reserveRadar);
    expect(find.descendant(of: radar, matching: find.text('Accept')), findsOneWidget);
    expect(find.descendant(of: radar, matching: find.text('TAP')), findsOneWidget);
    final outline = tester.widget<RadarSheetOutline>(
      find.byKey(const ValueKey<String>('dock-contour-custom')),
    );
    expect(outline.color, const Color(0xFF111518));
    expect(find.byType(RadarEdgeDash), findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('× only hides the popup: it stays in Scheduled rides', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    expect(find.text('Your next ride'), findsOneWidget);

    await tester.tap(find.byKey(_hide));
    await _frames(tester, const Duration(milliseconds: 800));
    expect(find.text('Your next ride'), findsNothing);
    // Not declined: still open to take, and the radar is Radar again.
    expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);
    expect(ScheduledRideStore.openRequests.value, 2);
    expect(find.byKey(_reserveRadar), findsNothing);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('dock-contour-custom')), findsNothing);
    expect(_said, isNot(contains('Reservation declined')));

    // It does not come back by itself.
    await _frames(tester, const Duration(seconds: 5));
    expect(find.text('Your next ride'), findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('the radar Accept takes the reservation for this driver', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    await tester.tap(find.byKey(_reserveRadar));
    await tester.pump(const Duration(milliseconds: 100));
    // The server decides; the radar says so meanwhile and × waits.
    expect(find.descendant(of: find.byKey(_reserveRadar), matching: find.text('Matching')),
        findsOneWidget);
    expect(_said, contains('Matching…'));
    await _frames(tester, const Duration(milliseconds: 1400));

    expect(_said, contains('Reservation accepted'));
    expect(find.text('Your next ride'), findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    // It left the requests and waits in Accepted.
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(ScheduledRideStore.openRequests.value, 1);
    // Taken once, the server gives it to nobody else.
    final again = dispatch.claimOffer(demoReservationId);
    await tester.pump(const Duration(milliseconds: 700));
    expect((await again).outcome, ClaimOutcome.unavailable);
    await _end(tester, dispatch);
  });

  testWidgets('taken by another driver first: "No longer available", gone', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester, losingOfferId: demoReservationId);
    await _waitForPopup(tester);
    await tester.tap(find.byKey(_reserveRadar));
    await _frames(tester, const Duration(milliseconds: 1500));

    expect(_said, contains('No longer available'));
    expect(_said, isNot(contains('Reservation accepted')));
    expect(find.text('Your next ride'), findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    // Gone from Scheduled rides too, and not this driver's.
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(ScheduledRideStore.openRequests.value, 1);
    await _frames(tester, const Duration(seconds: 5));
    expect(find.text('Your next ride'), findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('View route on the Home popup opens the route screen', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    await tester.tap(find.byKey(const ValueKey<String>('reservation-map-open')));
    await _frames(tester, const Duration(milliseconds: 600));
    expect(find.byType(ReservationRouteMapPage), findsOneWidget);
    expect(find.text('07:59'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('reservation-map-close')));
    await _frames(tester, const Duration(milliseconds: 800));
    // Back returns to the popup.
    expect(find.byType(ReservationRouteMapPage), findsNothing);
    expect(find.text('Your next ride'), findsOneWidget);
    expect(find.byKey(_reserveRadar), findsOneWidget);
    await _end(tester, dispatch);
  });

  testWidgets('taken elsewhere while on Home: the popup goes at once', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    expect(find.text('Your next ride'), findsOneWidget);
    ScheduledRideStore.take(demoReservationId);
    await _frames(tester, const Duration(milliseconds: 800));
    expect(find.text('Your next ride'), findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('cancelled after taking: back in Scheduled rides and on Home', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    await tester.tap(find.byKey(_reserveRadar));
    await _frames(tester, const Duration(milliseconds: 1500));
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);

    // Cancel it from Scheduled rides → Accepted.
    final scheduled = find.byTooltip('Scheduled');
    await tester.tap(scheduled.first);
    await _frames(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text('Accepted'));
    await _frames(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Gamla vägen, Stockholm').first);
    await _frames(tester, const Duration(milliseconds: 800));
    final cancel = find.text('Cancel reservation');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await _frames(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text('Vehicle issue'));
    await _frames(tester, const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await _frames(tester, const Duration(milliseconds: 800));
    final confirm = find.widgetWithText(FilledButton, 'Cancel reservation');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await _frames(tester, const Duration(milliseconds: 800));

    // It went back out: open in Scheduled rides, claimable again.
    expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);
    expect(ScheduledRideStore.openRequests.value, 2);
    await tester.tap(find.byTooltip('Back').first);
    await _frames(tester, const Duration(milliseconds: 800));

    // And after the demo delay on Home again. Back on Home the demo's
    // Exclusive offer comes first (2.2 s, 8.5 s long); the popup follows.
    await _frames(tester, const Duration(seconds: 13));
    expect(find.text('Your next ride').hitTestable(), findsOneWidget);
    expect(find.byKey(_reserveRadar), findsOneWidget);
    await _end(tester, dispatch);
  });
}
