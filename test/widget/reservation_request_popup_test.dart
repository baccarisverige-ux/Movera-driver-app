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
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/reservation_island_face.dart';
import 'package:movera/presentation/driver/home/components/reservation_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/reservation_route_map.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
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

DateTime _sixOhSeven() => DateTime(2026, 10, 15, 6, 7);

const _hide = ValueKey<String>('reservation-hide');

/// The popup is up (its title, not the island's "New reservation").
final _popup = find.byKey(const ValueKey<String>('reservation-popup'));
const _reserveRadar = ValueKey<String>('home-radar-reserve');
const _radarTouch = ValueKey<String>('trip-radar-touch-target');

Future<void> _pumpSheet(
  WidgetTester tester,
  ReservationRequestPreview request, {
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
            clock: _sixOhSeven,
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

  test('the island says when, as the sheet does', () {
    ReservationRequestPreview on(String day) => ReservationRequestPreview(
      category: 'Comfort',
      fare: '1 kr',
      pickupLabel: '',
      pickupAddress: '',
      dropoffAddress: '',
      pickupTime: '06:35',
      pickupDay: day,
      tripMinutes: 42,
      tripKm: 38,
      pickup: const GeoPoint(0, 0),
      dropoff: const GeoPoint(0, 0),
    );
    final now = DateTime(2026, 10, 15, 4, 30);
    // Soon: the time is added.
    expect(DigitalReservationFace.whenOf(on('Today'), now), 'In 2 h · 06:35');
    expect(
      DigitalReservationFace.whenOf(on('Today'), DateTime(2026, 10, 15, 1)),
      'Today 06:35',
    );
    expect(
      DigitalReservationFace.whenOf(on('tomorrow'), now),
      'Tomorrow 06:35',
    );
    // Thursday 15 October: Tuesday 20 is within the week.
    expect(
      DigitalReservationFace.whenOf(on('Tue 20 Oct'), now),
      'Tuesday 06:35',
    );
  });

  testWidgets('the sheet holds every detail, a picture and when, no map', (
    tester,
  ) async {
    await _pumpSheet(tester, _request);
    // Only one request waits: no "1 of 1", and no "New reservation".
    expect(find.text('New reservation'), findsNothing);
    expect(find.byKey(const ValueKey<String>('reservation-count')),
        findsNothing);
    expect(find.text('Comfort'), findsOneWidget);
    final fare = tester.widget<Text>(
      find.byKey(const ValueKey<String>('reservation-fare')),
    );
    expect(fare.textSpan!.toPlainText(), '126,75 kr');
    expect(find.text('19 min trip'), findsOneWidget);
    // Pickup with its clock time, drop-off with the trip distance.
    final pickup = find.byKey(const ValueKey<String>('reservation-pickup'));
    final dropoff = find.byKey(const ValueKey<String>('reservation-dropoff'));
    expect(find.descendant(of: pickup, matching: find.text('Gamla vägen')),
        findsOneWidget);
    expect(find.descendant(of: pickup, matching: find.text('07:40')),
        findsOneWidget);
    expect(find.descendant(of: dropoff, matching: find.text('Solna centrum')),
        findsOneWidget);
    expect(find.descendant(of: dropoff, matching: find.text('9.4 km')),
        findsOneWidget);
    expect(find.text('1 stop'), findsOneWidget);
    // A booked-calendar picture right of the fare, about 98 x 75.
    final picture = find.byKey(const ValueKey<String>('reservation-picture'));
    expect(picture, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reservation-picture-booked')),
        findsOneWidget);
    expect(tester.getSize(picture), const Size(98, 75));
    expect(
      tester.getRect(picture).left,
      greaterThan(tester.getRect(find.text('19 min trip')).right),
    );
    // No map inside the sheet: the Home map shows the route.
    expect(find.byType(ReservationRouteMap), findsNothing);
    // The radar accepts; the bottom says when the ride is (1 h 33 min
    // away: "In 2 h"), full width, grey, not a button.
    expect(find.text('Accept'), findsNothing);
    expect(find.text('Decline'), findsNothing);
    expect(find.text('Cash'), findsNothing);
    final when = find.byKey(const ValueKey<String>('reservation-when'));
    expect(tester.getSize(when).width, closeTo(375 - 44, 1));
    final box = tester.widget<Container>(when).decoration! as BoxDecoration;
    expect(box.color, const Color(0xFFF1F2F4));
    expect(find.descendant(of: when, matching: find.text('In 2 h')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('reservation-when-icon')),
        findsOneWidget);
    expect(
      find.ancestor(of: when, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the down arrow takes the sheet smoothly back down', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var visible = true;
    var leaving = 0, hidden = 0, settled = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: HomeReservationSheet(
                      request: _airportRequest,
                      visible: visible,
                      clock: _sixOhSeven,
                      orb: const SizedBox(width: 104, height: 104),
                      onDecline: () => update(() => visible = false),
                      onSettled: () => settled++,
                      onLeaving: () => leaving++,
                      onHidden: () => hidden++,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    final sheet = find.byKey(const ValueKey<String>('home-reservation-sheet'));
    await tester.pump(HomeReservationSheet.riseDelay);
    await tester.pump(const Duration(milliseconds: 100));
    // Rising: on its way up, partly faded in.
    final rising = tester.getRect(sheet).top;
    await tester.pump(const Duration(milliseconds: 400));
    final up = tester.getRect(sheet).top;
    expect(rising, greaterThan(up));
    expect(settled, 1);
    // The airport ride: plane and traveller; "Today 07:40".
    expect(find.byKey(const ValueKey<String>('reservation-picture-airport')),
        findsOneWidget);
    expect(find.text('40.8 km'), findsNothing);
    expect(find.text('41 km'), findsOneWidget);
    expect(find.text('In 2 h'), findsOneWidget);
    // A small grey down arrow in the top-right corner.
    // driver-u111: a 48 px touch box around the 34 px mark, which stays
    // 18 px from the right and 14 px below the top.
    final arrow = find.byKey(_hide);
    expect(tester.getSize(arrow), const Size(48, 48));
    final mark = find.descendant(of: arrow, matching: find.byType(Material));
    expect(tester.getSize(mark), const Size(34, 34));
    expect(tester.getRect(mark).right, closeTo(375 - 18, 1));
    expect(tester.getRect(mark).top, closeTo(up + 14, 1));

    await tester.tap(arrow);
    await tester.pump();
    expect(leaving, 1);
    // The route fades first; the sheet stays put meanwhile.
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.getRect(sheet).top, closeTo(up, 1));
    // Then it slides down, still there halfway.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.getRect(sheet).top, greaterThan(up + 4));
    expect(hidden, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sheet, findsNothing);
    expect(hidden, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the count shows only while more requests wait', (
    tester,
  ) async {
    await _pumpSheet(tester, _request, count: 1);
    expect(find.textContaining('of 1'), findsNothing);
    await _pumpSheet(tester, _airportRequest, position: 2, count: 2);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Arlanda Terminal 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reservation orb is the Radar-offer orb in grey', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: MoveraRadarOrb(
            title: 'Accept',
            status: 'MATCH',
            subtitle: 'Tap to accept',
            reserve: true,
            active: true,
          ),
        ),
      ),
    );
    final match = tester.widget<Text>(find.text('MATCH'));
    expect(match.style!.color, MoveraRadarOrb.offerInk);
    // "Accept" is black; the normal radar keeps it white.
    final accept = tester.widget<Text>(find.text('Accept'));
    expect(accept.style!.color, const Color(0xFF111518));
    // Grey waves (pulse 0: the light grey), no icon in the orb.
    final ink = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .firstWhere((ink) => ink.splashColor != null);
    expect(
      ink.splashColor!.withValues(alpha: 1).toARGB32(),
      const Color(0xFFC6CBD0).toARGB32(),
    );
    expect(find.byType(SvgPicture), findsNothing);
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

  testWidgets('the sheet rises to 40 %, the orb on its edge, route on the map', (
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
    // It came up from below and settled about 40 % of the screen high,
    // over the dock, edge to edge.
    expect(rising, greaterThan(settled.top));
    expect(settled.height, inInclusiveRange(812 * 0.38, 812 * 0.5));
    expect(settled.left, lessThanOrEqualTo(0));
    expect(settled.right, greaterThanOrEqualTo(375));
    expect(settled.bottom, closeTo(812, 1));
    final box = tester.widget<DecoratedBox>(sheet);
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
    // Every detail is in the sheet, with the down arrow; no map is dimmed.
    for (final key in [
      'reservation-fare',
      'reservation-when',
      'reservation-pickup',
      'reservation-dropoff',
      'reservation-picture',
      'reservation-hide',
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.byKey(ValueKey<String>(key))),
        findsOneWidget,
      );
    }
    // driver-u190: no tinted barrier over Home (any route's own barrier
    // is see-through).
    expect(
      find.byWidgetPredicate((w) =>
          w is ModalBarrier && w.color != null && w.color!.a > 0),
      findsNothing,
    );

    // The radar orb sits centred on the sheet's top edge: the normal
    // Radar-offer orb with grey waves and MATCH in light black, no icon.
    final radar = find.byKey(_reserveRadar);
    final orb = tester.getRect(radar);
    expect(orb.center.dy, closeTo(settled.top, 2));
    expect(orb.center.dx, closeTo(375 / 2, 1));
    for (final text in ['Accept', 'MATCH', 'Tap to accept']) {
      expect(find.descendant(of: radar, matching: find.text(text)), findsOneWidget);
    }
    final match = tester.widget<Text>(
      find.descendant(of: radar, matching: find.text('MATCH')),
    );
    expect(match.style!.color, MoveraRadarOrb.offerInk);
    expect(tester.widget<MoveraRadarOrb>(find.descendant(
      of: radar, matching: find.byType(MoveraRadarOrb))).reserve, isTrue);
    // driver-u190: the orb draws no icon (the Exclusive check carries
    // this key).
    expect(
      find.descendant(
        of: radar,
        matching: find.byKey(const ValueKey<String>('radar-exclusive-icon')),
      ),
      findsNothing,
    );

    // The Home map shows the route with clock times on the pins.
    // The pins draw in real time and then fade in; a slow machine gets
    // a little longer.
    // (The map itself waits for the start position, also in real time.)
    bool pinsShown() =>
        find.byType(CustomGoogleMap).evaluate().isNotEmpty &&
        tester
            .widget<CustomGoogleMap>(find.byType(CustomGoogleMap))
            .markers!
            .any((m) => m.markerId.value == 'radar_dropoff');
    for (var i = 0; i < 30 && !pinsShown(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 400));
    final map = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    String? chip(String id) => map.markers!
        .firstWhere((m) => m.markerId.value == id)
        .infoWindow
        .title;
    final ride = demoReservationRequest;
    expect(chip('radar_pickup'), ride.pickupTime);
    expect(chip('radar_dropoff'), ride.arrivalTime);

    // Once "New reservation" has passed, the island says when.
    await _frames(tester, const Duration(seconds: 4));
    // Under 3 hours away: "In 36 min · 07:40 · Reservation".
    final said = tester
        .widget<Text>(find.byKey(const ValueKey<String>('island-reservation')))
        .textSpan!
        .toPlainText();
    expect(said, startsWith('In '));
    expect(said, endsWith(' · ${ride.pickupTime} · Reservation'));
    expect(find.byKey(const ValueKey<String>('island-reservation-icon')),
        findsOneWidget);

    // The down arrow: the route fades, the sheet goes down, and the map
    // is normal Home again.
    await tester.tap(find.byKey(_hide));
    await _frames(tester, const Duration(milliseconds: 800));
    expect(sheet, findsNothing);
    final after = tester.widget<CustomGoogleMap>(find.byType(CustomGoogleMap));
    expect(
      after.markers!.where((m) => m.markerId.value.startsWith('radar_')),
      isEmpty,
    );
    expect(find.byKey(const ValueKey<String>('island-reservation-face')),
        findsNothing);
    await _end(tester, dispatch);
  });

  testWidgets('the down arrow only hides the popup: it stays in Scheduled rides', (
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
    expect(_said, contains('Accepted · pickup 07:40'));
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

    testWidgets('one at a time: after the down arrow the next one rises, "2 of 2"', (
      tester,
    ) async {
      final dispatch = await _pumpHome(tester);
      await _waitForPopup(tester);
      expect(_popup, findsOneWidget);
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Gamla vägen'), findsOneWidget);

      await tester.tap(find.byKey(_hide));
      await _frames(
        tester,
        HomeReservationSheet.riseDelay + const Duration(milliseconds: 1600),
      );
      expect(_popup, findsOneWidget);
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Arlanda Terminal 5'), findsOneWidget);
      expect(find.byKey(_reserveRadar), findsOneWidget);

      // Accept takes the airport ride for later; nothing else waits.
      await tester.tap(find.byKey(_reserveRadar));
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_said, contains('Accepted · pickup 12:00'));
      expect(ScheduledRideStore.isOpen(demoAirportReservationId), isFalse);
      expect(ScheduledRideStore.isOpen(demoReservationId), isTrue);
      await _frames(tester, const Duration(seconds: 3));
      expect(_popup, findsNothing);
      expect(find.byKey(_reserveRadar), findsNothing);
      await _end(tester, dispatch);
    });
  });

  group('on the real clock', () {
    late DateTime Function() testNow;
    setUp(() {
      // The app's real clock is local time, as DateTime.now() is; the test
      // clock reads UTC. Read it as local so the booking "2 h from now"
      // holds in every time zone.
      testNow = ScheduledClock.realNow;
      ScheduledClock.realNow = () => testNow().toLocal();
      // The app: the real clock and rides booked from now (2 h, 5 h).
      ScheduledClock.instance = ScheduledClock();
      DemoReservations.plan = DemoReservationPlan.app;
      DemoReservations.reset();
      ScheduledRideStore.reset();
    });
    tearDown(() {
      ScheduledClock.realNow = testNow;
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
      expect(_said, contains('Accepted · pickup ${ride.pickupTime}'));
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
