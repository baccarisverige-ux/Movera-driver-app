import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/demo_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_edge_dash.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
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

const _airportRequest = ReservationRequestPreview(
  category: 'Premium',
  fare: '248.40 kr',
  pickupLabel: '',
  pickupAddress: 'Kungsholmstorg, Stockholm',
  dropoffAddress: 'Arlanda Terminal 5, Arlanda',
  pickupTime: '07:40',
  pickupDay: 'Today',
  tripMinutes: 36,
  tripKm: 40.8,
  pickup: GeoPoint(59.3297, 18.0436),
  dropoff: GeoPoint(59.6497, 17.9237),
);

Widget _fakeMap(BuildContext context) =>
    const ColoredBox(key: ValueKey<String>('fake-map'), color: Color(0xFFE6EAED));

DateTime _sixOhSeven() => DateTime(2026, 10, 15, 6, 7);

const _hide = ValueKey<String>('reservation-hide');
const _viewDetails = ValueKey<String>('reservation-view-details');

/// The popup is up (its title, not the island's "New reservation").
final _popup = find.byKey(const ValueKey<String>('reservation-popup'));
const _reserveRadar = ValueKey<String>('home-radar-reserve');
const _radarTouch = ValueKey<String>('trip-radar-touch-target');

Future<void> _pumpSheet(
  WidgetTester tester,
  ReservationRequestPreview request, {
  VoidCallback? onHide,
  int position = 1,
  int count = 1,
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
            position: position,
            count: count,
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
  List<ReservationRequestPreview>? assignedRides,
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
    assignedRides: assignedRides,
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

  testWidgets('the popup shows one calm card, no Accept/Decline', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    expect(find.text('New reservation'), findsOneWidget);
    // Only one request waits: no "1 of 1".
    expect(find.byKey(const ValueKey<String>('reservation-counter')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('reservation-picture-booked')),
      findsOneWidget,
    );
    expect(find.byKey(_hide), findsOneWidget);
    expect(find.text('Comfort'), findsOneWidget);
    final fare = tester.widget<Text>(
      find.byKey(const ValueKey<String>('reservation-fare')),
    );
    expect(fare.textSpan!.toPlainText(), '126,75 kr');
    expect(
      find.text('Pickup today 07:40 · in 1 h 33 min', findRichText: true),
      findsOneWidget,
    );
    // From → to with short place names.
    expect(find.text('Gamla vägen'), findsOneWidget);
    expect(find.text('Solna centrum'), findsOneWidget);
    expect(find.text('View details'), findsOneWidget);
    // Only the small framed map shows; the stops wait behind View details.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('reservation-map-strip')),
        matching: find.byKey(const ValueKey<String>('fake-map')),
      ),
      findsOneWidget,
    );
    expect(find.text('PICKUP'), findsNothing);
    // The radar accepts and the × only hides: no buttons on the card.
    for (final word in ['Accept', 'Accept ride', 'Decline', 'Deny']) {
      expect(find.text(word), findsNothing);
    }
    // Card payment: nothing about it (notes R2).
    expect(find.text('Cash'), findsNothing);
    expect(find.text('CARD'), findsNothing);
    // White card with a light contour.
    final card = tester.widget<Container>(
      find.byKey(const ValueKey<String>('reservation-card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(24));
    expect((decoration.border! as Border).top.width, 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the counter shows only while more requests wait', (
    tester,
  ) async {
    await _pumpSheet(tester, _request, count: 1);
    expect(find.byKey(const ValueKey<String>('reservation-counter')), findsNothing);
    expect(find.text('1 of 1'), findsNothing);
    await _pumpSheet(tester, _request, position: 2, count: 2);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('airport rides get the plane and traveller picture', (
    tester,
  ) async {
    const airport = _airportRequest;
    expect(ReservationPicture.forRequest(airport), ReservationPicture.airport);
    expect(ReservationPicture.forRequest(_request), ReservationPicture.booked);
    expect(
      ReservationPicture.forRequest(_request, order: 1),
      ReservationPicture.calendar,
    );
    await _pumpSheet(tester, airport);
    final picture = find.byKey(
      const ValueKey<String>('reservation-picture-airport'),
    );
    expect(picture, findsOneWidget);
    // The plane and the traveller with a bag, together.
    expect(
      find.descendant(of: picture, matching: find.byType(SvgPicture)),
      findsNWidgets(2),
    );
    expect(find.text('Arlanda T5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pictures\' accent is the colour of the Accept orb', (
    tester,
  ) async {
    // The real orb in the dock while a reservation is up.
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MoveraRadarOrb(
            title: 'Accept',
            status: 'TAP',
            subtitle: 'Accept the reservation',
            reserve: true,
            active: true,
          ),
        ),
      ),
    );
    final ink = tester
        .widgetList<InkWell>(
          find.descendant(
            of: find.byType(MoveraRadarOrb),
            matching: find.byType(InkWell),
          ),
        )
        .firstWhere((ink) => ink.splashColor != null);
    final orb = ink.splashColor!.withValues(alpha: 1);
    expect(orb.toARGB32(), reservationAcceptOrbColor.toARGB32());
    expect(reservationAcceptOrbColor, MoveraRadarOrb.reserveInk);

    for (final request in [_request, _airportRequest]) {
      await _pumpSheet(tester, request);
      final pictures = tester.widgetList<SvgPicture>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('reservation-picture')),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(pictures, isNotEmpty);
      for (final picture in pictures) {
        final mapper = (picture.bytesLoader as SvgAssetLoader).colorMapper!;
        // The accent becomes the orb's colour; the other greys stay.
        expect(
          mapper
              .substitute(null, 'path', 'fill', reservationPictureAccent)
              .toARGB32(),
          orb.toARGB32(),
        );
        const grey = Color(0xFF3F3D56);
        expect(mapper.substitute(null, 'path', 'fill', grey), grey);
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('only an exclusive reservation adds pickup pay to the price', (
    tester,
  ) async {
    Future<String> priceWith(PickupPayQuote? pay) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReservationRequestSheet(
              request: _request,
              mapBuilder: _fakeMap,
              clock: _sixOhSeven,
              pickupPay: pay,
            ),
          ),
        ),
      );
      await tester.pump();
      return tester
          .widget<Text>(find.byKey(const ValueKey<String>('reservation-fare')))
          .textSpan!
          .toPlainText();
    }

    final pay = PickupPayQuote(
      pay: Money.ore(2160),
      leg: const PickupLeg(km: 4.2, minutes: 9),
    );
    // An exclusive reservation: one total, fare + pickup pay.
    expect(await priceWith(pay), '148,35 kr');
    // A normal reservation (the Home popup, Scheduled rides): the fare.
    expect(await priceWith(null), '126,75 kr');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the framed 3D map under View details opens the details', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    final strip = find.byKey(const ValueKey<String>('reservation-map-strip'));
    expect(strip, findsOneWidget);
    expect(
      find.descendant(
        of: strip,
        matching: find.byKey(const ValueKey<String>('fake-map')),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('reservation-map-strip-open')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('reservation-details')), findsOneWidget);
    expect(strip, findsNothing);
  });

  testWidgets('View details opens the route, the stops and the numbers', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    await tester.tap(find.byKey(_viewDetails));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('reservation-details')), findsOneWidget);
    expect(find.text('Today, 07:40'), findsOneWidget);
    expect(find.text('in 1 h 33 min · Comfort'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('reservation-details-fare')),
          )
          .textSpan!
          .toPlainText(),
      '126,75 kr',
    );
    expect(find.byKey(const ValueKey<String>('fake-map')), findsOneWidget);
    for (final label in ['PICKUP', 'STOP', 'DROP-OFF']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Gamla vägen, Stockholm'), findsOneWidget);
    expect(find.text('Odenplan, Stockholm'), findsOneWidget);
    expect(find.text('Solna centrum, Solna'), findsOneWidget);
    expect(find.text('07:40'), findsOneWidget);
    expect(find.text('~07:59'), findsOneWidget);
    for (final label in ['TRIP', 'DISTANCE', 'STOPS']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('19 min'), findsOneWidget);
    expect(find.text('9.4 km'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    // Accept stays on the radar.
    expect(find.text('Accept'), findsNothing);

    await tester.tap(find.byKey(const ValueKey<String>('reservation-details-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('reservation-details')), findsNothing);
    expect(find.text('View details'), findsOneWidget);
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
    expect(find.byKey(const ValueKey<String>('reservation-boost')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a raised fare shows its "+X kr" boost on the popup (Q13)', (
    tester,
  ) async {
    const boosted = ReservationRequestPreview(
      category: 'Comfort',
      fare: '166.75 kr',
      fareBoost: '+40 kr',
      pickupLabel: '',
      pickupAddress: 'Gamla vägen, Stockholm',
      dropoffAddress: 'Solna centrum, Solna',
      pickupTime: '07:40',
      pickupDay: 'Today',
      tripMinutes: 19,
      tripKm: 9.4,
      pickup: GeoPoint(59.3362, 18.0714),
      dropoff: GeoPoint(59.3603, 18.0009),
    );
    await _pumpSheet(tester, boosted);
    final badge = find.byKey(const ValueKey<String>('reservation-boost'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('+40 kr')), findsOneWidget);
    // The driver sees only the new fare.
    expect(find.byKey(const ValueKey<String>('reservation-fare')), findsOneWidget);
    expect(find.textContaining('126'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the details map opens the full route and Back returns', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    await tester.tap(find.byKey(_viewDetails));
    await tester.pumpAndSettle();
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
    expect(find.byKey(const ValueKey<String>('reservation-details')), findsOneWidget);
    tester.takeException();
  });

  testWidgets('the popup shows on Home only while the driver is online', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester, online: false);
    await _waitForPopup(tester);
    await _frames(tester, const Duration(seconds: 2));
    // Offline: it waits in Scheduled rides, nothing rises.
    expect(_popup, findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);

    tester
        .widget<GestureDetector>(find.byKey(_radarTouch))
        .onTap!
        .call();
    await _frames(tester, const Duration(milliseconds: 1500));
    // Radar goes live first, then the sheet rises from under the dock.
    expect(_popup.hitTestable(), findsNothing);
    await _frames(tester, const Duration(milliseconds: 1500));
    expect(_popup, findsOneWidget);
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
      const BorderRadius.vertical(top: Radius.circular(32)),
    );
    final border = decoration.border! as Border;
    expect(border.top.color, const Color(0xFF0F1214));
    expect(border.top.width, 1);
    // The map behind is dimmed.
    final barrier = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('home-reservation-barrier')),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(barrier.color.a, inInclusiveRange(0.42, 0.45));

    // While it shows the radar is a black Accept · TAP, the dock contour
    // is black and the green online dash is gone.
    final radar = find.byKey(_reserveRadar);
    expect(find.descendant(of: radar, matching: find.text('Accept')), findsOneWidget);
    expect(find.descendant(of: radar, matching: find.text('TAP')), findsOneWidget);
    final outline = tester.widget<RadarSheetOutline>(
      find.byKey(const ValueKey<String>('dock-contour-custom')),
    );
    expect(outline.color, const Color(0xFF111518));
    // Only an Exclusive offer turns the contours blue: the reservation
    // keeps its thin black line and the island stays plain.
    expect(outline.strokeWidth, 1);
    expect(
      tester.widget<DigitalIslandShell>(find.byType(DigitalIslandShell))
          .exclusive,
      0,
    );
    expect(find.byType(RadarEdgeDash), findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('× only hides the popup: it stays in Scheduled rides', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    expect(_popup, findsOneWidget);

    await tester.tap(find.byKey(_hide));
    await _frames(tester, const Duration(milliseconds: 800));
    expect(_popup, findsNothing);
    // Not declined: still open to take, and the radar is Radar again.
    expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);
    expect(ScheduledRideStore.openRequests.value, 2);
    expect(find.byKey(_reserveRadar), findsNothing);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('dock-contour-custom')), findsNothing);
    expect(_said, isNot(contains('Reservation declined')));

    // It does not come back by itself.
    await _frames(tester, const Duration(seconds: 5));
    expect(_popup, findsNothing);
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

    // Only saved for later: Scheduled rides › Accepted.
    expect(_said, contains('Reservation accepted · pickup 07:40'));
    expect(_popup, findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    // It left the requests and waits in Accepted; the 08:05 request
    // clashes with it and leaves this driver's list (Q9).
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(ScheduledRideStore.openRequests.value, 0);
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
    expect(_said.where((t) => t.startsWith('Reservation accepted')), isEmpty);
    expect(_popup, findsNothing);
    expect(find.byKey(_reserveRadar), findsNothing);
    // Gone from Scheduled rides too, and not this driver's.
    expect(ScheduledRideStore.isOpen(demoReservationId), isFalse);
    expect(ScheduledRideStore.openRequests.value, 1);
    await _frames(tester, const Duration(seconds: 5));
    expect(_popup, findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('View details grows the Home sheet; its map opens the route', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    final sheet = find.byKey(const ValueKey<String>('home-reservation-sheet'));
    final popupTop = tester.getRect(sheet).top;
    await tester.tap(find.byKey(_viewDetails));
    await _frames(tester, const Duration(milliseconds: 600));
    final details = find.byKey(const ValueKey<String>('reservation-details'));
    expect(details, findsOneWidget);
    // Full height, just under the top island; Accept stays on the radar.
    expect(tester.getRect(sheet).top, lessThan(popupTop));
    expect(tester.getRect(sheet).top, lessThan(812 * 0.12));
    expect(find.byKey(_reserveRadar), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('reservation-map-open')));
    await _frames(tester, const Duration(milliseconds: 600));
    expect(find.byType(ReservationRouteMapPage), findsOneWidget);
    expect(find.text('07:59'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('reservation-map-close')));
    await _frames(tester, const Duration(milliseconds: 800));
    // Back returns to the details on Home.
    expect(find.byType(ReservationRouteMapPage), findsNothing);
    expect(details, findsOneWidget);
    expect(find.byKey(_reserveRadar), findsOneWidget);

    // ‹ goes back to the popup card.
    await tester.tap(find.byKey(const ValueKey<String>('reservation-details-back')));
    await _frames(tester, const Duration(milliseconds: 600));
    expect(_popup, findsOneWidget);
    expect(tester.getRect(sheet).top, closeTo(popupTop, 1));
    await _end(tester, dispatch);
  });

  testWidgets('taken elsewhere while on Home: the popup goes at once', (
    tester,
  ) async {
    final dispatch = await _pumpHome(tester);
    await _waitForPopup(tester);
    expect(_popup, findsOneWidget);
    ScheduledRideStore.take(demoReservationId);
    await _frames(tester, const Duration(milliseconds: 800));
    expect(_popup, findsNothing);
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
    expect(_popup.hitTestable(), findsOneWidget);
    expect(find.byKey(_reserveRadar), findsOneWidget);
    await _end(tester, dispatch);
  });

  group('two requests waiting', () {
    setUp(() {
      // The app's demo: a second, airport request after the first.
      DemoReservations.plan = const DemoReservationPlan(
        main: Duration(minutes: 40),
        clashing: Duration(minutes: 65),
        assigned: Duration(minutes: 150),
        airport: Duration(hours: 5),
      );
      DemoReservations.reset();
      ScheduledRideStore.reset();
    });
    tearDown(() {
      DemoReservations.plan = DemoReservationPlan.testDay;
      DemoReservations.reset();
      ScheduledRideStore.reset();
    });

    testWidgets('one at a time: after × the next one rises, "2 of 2"', (
      tester,
    ) async {
      final dispatch = await _pumpHome(tester);
      await _waitForPopup(tester);
      expect(_popup, findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Gamla vägen'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('reservation-picture-booked')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(_hide));
      await _frames(
        tester,
        HomeReservationSheet.riseDelay + const Duration(milliseconds: 1600),
      );
      expect(_popup, findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Arlanda T5'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('reservation-picture-airport')),
        findsOneWidget,
      );
      expect(find.byKey(_reserveRadar), findsOneWidget);

      // Accept takes the airport ride for later; nothing else waits.
      await tester.tap(find.byKey(_reserveRadar));
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_said, contains('Reservation accepted · pickup 12:00'));
      expect(ScheduledRideStore.isOpen(demoAirportReservationId), isFalse);
      expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);
      await _frames(tester, const Duration(seconds: 3));
      expect(_popup, findsNothing);
      expect(find.byKey(_reserveRadar), findsNothing);
      await _end(tester, dispatch);
    });
  });

  group('on the real clock', () {
    setUp(() {
      // The app: the real clock and rides booked from now (2 h, 5 h).
      ScheduledClock.instance = ScheduledClock();
      DemoReservations.plan = DemoReservationPlan.app;
      DemoReservations.reset();
      ScheduledRideStore.reset();
    });
    tearDown(() {
      ScheduledClock.instance = ScheduledClock.fastDay();
      DemoReservations.plan = DemoReservationPlan.testDay;
      DemoReservations.reset();
      ScheduledRideStore.reset();
    });

    testWidgets('Accept only saves it; the trip opens at its real time', (
      tester,
    ) async {
      final dispatch = await _pumpHome(
        tester,
        assignedRides: const <ReservationRequestPreview>[],
      );
      await _waitForPopup(tester);
      final ride = demoReservationRequest;
      // Booked relative to now: pickup in 2 h.
      final now = ScheduledClock.instance.now();
      expect(
        ride.pickupAt(now)!.difference(now).inMinutes,
        inInclusiveRange(115, 125),
      );
      expect(find.text('1 of 2'), findsOneWidget);
      await tester.tap(find.byKey(_reserveRadar));
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_said, contains('Reservation accepted · pickup ${ride.pickupTime}'));
      expect(ScheduledRideStore.upcoming, contains(ride));

      // Minutes later (the old fast day was at its Exclusive step after
      // 40 s): still not the active trip.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(minutes: 1));
      }
      expect(find.byType(AcceptRide), findsNothing);
      expect(ScheduledRideStore.upcoming, contains(ride));
      expect(_said.where((t) => t.startsWith('Leave now')), isEmpty);

      // Not before its "be online" window (45 min before a Comfort
      // pickup) either.
      final pickupAt = ride.pickupAt(ScheduledClock.instance.now())!;
      final windowOpens = pickupAt.subtract(const Duration(minutes: 45));
      while (ScheduledClock.instance.now().isBefore(windowOpens)) {
        await tester.pump(const Duration(minutes: 1));
      }
      expect(find.byType(AcceptRide), findsNothing);

      // "Leave now" by the real clock: it lands as the active trip.
      while (find.byType(AcceptRide).evaluate().isEmpty &&
          ScheduledClock.instance.now().isBefore(pickupAt)) {
        await tester.pump(const Duration(minutes: 1));
      }
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.byType(AcceptRide), findsOneWidget);
      expect(
        tester.widget<AcceptRide>(find.byType(AcceptRide)).matchedVia,
        'Scheduled ride',
      );
      expect(_said, contains('Leave now for ${ride.pickupTime} pickup'));
      await _end(tester, dispatch);
    });
  });
}
