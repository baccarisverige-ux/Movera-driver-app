import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/digital_island.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_edge_dash.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// P4: the Exclusive offer grows up out of the Home sheet and stays
// attached to it; the radar in the dock turns blue and is its Accept,
// ringed by the time left.

class _Dispatch implements DispatchRepository {
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

const _card = ValueKey<String>('exclusive-offer-card-home-direct-close');
final _blueRadar = find.byKey(const ValueKey<String>('home-radar-exclusive'));

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

Future<void> _pumpHome(WidgetTester tester, {bool reduceMotion = false}) async {
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: DriverHome(
            sessionController: DriverSessionController(),
            dispatchRepository: _Dispatch(),
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
}

/// Pumps single frames until the Exclusive card is on screen.
Future<void> _untilCard(WidgetTester tester) async {
  for (var i = 0; i < 400 && find.byKey(_card).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(find.byKey(_card), findsOneWidget);
}

/// How far down the card is: 0 up, 1 under the dock.
double _down(WidgetTester tester) => tester
    .widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.byKey(_card),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    )
    .translation
    .dy;

MoveraRadarOrb _orb(WidgetTester tester) => tester.widget<MoveraRadarOrb>(
  find.descendant(of: _blueRadar, matching: find.byType(MoveraRadarOrb)),
);

const _blue = Color(0xFF1769E8);
const _black = Color(0xFF111518);

/// The attached card's contour.
BorderSide _cardContour(WidgetTester tester) {
  final box = tester.widget<Container>(find.byKey(_card));
  return ((box.decoration! as BoxDecoration).border! as Border).top;
}

/// The dock's top line around the radar; null when it is the grey
/// outline with the online dash.
RadarSheetOutline? _dockLine(WidgetTester tester) {
  final line = find.byKey(const ValueKey<String>('dock-contour-custom'));
  return line.evaluate().isEmpty
      ? null
      : tester.widget<RadarSheetOutline>(line);
}

/// How much of the island's blue ring and glow shows.
double _island(WidgetTester tester) =>
    tester.widget<DigitalIslandShell>(find.byType(DigitalIslandShell)).exclusive;

Border? _islandRing(WidgetTester tester) =>
    (tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey<String>('island-exclusive-ring')),
                )
                .decoration
            as BoxDecoration)
        .border as Border?;

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
  });

  testWidgets('slides up out of the sheet and stays attached, full width', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    // Just arrived: still mostly under the dock.
    expect(_down(tester), greaterThan(0.3));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_down(tester), inExclusiveRange(0, 0.3));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_down(tester), 0);

    // Edge to edge, its bottom behind the dock at the screen edge.
    final rect = tester.getRect(find.byKey(_card));
    expect(rect.left, -1);
    expect(rect.right, 376);
    expect(rect.bottom, 812);
    // The dock and its radar stay; the map is not dimmed.
    expect(find.byKey(const ValueKey<String>('home-map-dim')), findsNothing);
    expect(_blueRadar, findsOneWidget);
    // No Accept in the card: the radar is the Accept.
    expect(
      find.descendant(of: find.byKey(_card), matching: find.text('Accept')),
      findsNothing,
    );
    await _end(tester);
  });

  testWidgets('the radar turns blue and shows Accept and the seconds left', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final lifetime = DriverOfferRules.current.exclusiveAcceptTime;

    expect(_orb(tester).exclusive, isTrue);
    expect(
      find.descendant(of: _blueRadar, matching: find.text('Accept')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _blueRadar,
        matching: find.text('${lifetime.inSeconds}s'),
      ),
      findsOneWidget,
    );
    final core = tester.widget<Container>(
      find.byKey(const ValueKey<String>('radar-exclusive-core')),
    );
    final gradient = (core.decoration! as BoxDecoration).gradient!;
    expect(gradient.colors, contains(const Color(0xFF1769E8)));

    // The ring empties over the offer's lifetime.
    ExclusiveTimeRingPainter ring() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('radar-exclusive-ring')),
                )
                .painter!
            as ExclusiveTimeRingPainter;
    expect(ring().timeLeft, greaterThan(0.9));
    await _frames(tester, lifetime ~/ 2);
    expect(ring().timeLeft, closeTo(0.5, 0.05));
    expect(
      find.descendant(
        of: _blueRadar,
        matching: find.textContaining(RegExp(r'^\d+s$')),
      ),
      findsOneWidget,
    );
    expect(_orb(tester).status, '${(lifetime.inSeconds / 2).ceil()}s');
    await _end(tester);
  });

  testWidgets('tapping the blue radar accepts the offer', (tester) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(_blueRadar);
    await _frames(tester, const Duration(milliseconds: 800));
    final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
    expect(trip.matchedVia, 'Exclusive offer');
    expect(trip.riderName, 'Nils');
    await _end(tester);
  });

  testWidgets('× slides the card back down before the offer clears', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey<String>('direct-offer-dismiss')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    // On its way down; the radar is already itself again.
    expect(find.byKey(_card), findsOneWidget);
    expect(_down(tester), inExclusiveRange(0, 1));
    expect(find.byKey(const ValueKey<String>('radar-online')), findsOneWidget);
    await _frames(tester, const Duration(milliseconds: 500));
    expect(find.byKey(_card), findsNothing);
    expect(_blueRadar, findsNothing);
    expect(find.byType(AcceptRide), findsNothing);
    await _end(tester);
  });

  testWidgets('when the time runs out the card slides away, radar normal', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    final lifetime = DriverOfferRules.current.exclusiveAcceptTime;
    await _frames(tester, lifetime + const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 60));
    // Leaving: still drawn, on its way down.
    expect(find.byKey(_card), findsOneWidget);
    expect(_down(tester), inExclusiveRange(0, 1));
    await _frames(tester, const Duration(milliseconds: 600));
    expect(find.byKey(_card), findsNothing);
    expect(_blueRadar, findsNothing);
    expect(
      tester
          .widgetList<MoveraRadarOrb>(find.byType(MoveraRadarOrb))
          .where((orb) => orb.exclusive),
      isEmpty,
    );
    await _end(tester);
  });

  testWidgets('reduced motion: the card is just there, and just goes', (
    tester,
  ) async {
    await _pumpHome(tester, reduceMotion: true);
    await _untilCard(tester);
    expect(_down(tester), 0);
    await tester.tap(find.byKey(const ValueKey<String>('direct-offer-dismiss')));
    await tester.pump();
    expect(find.byKey(_card), findsNothing);
    await _end(tester);
  });

  testWidgets('while the offer is live the card, dock and island are blue', (
    tester,
  ) async {
    await _pumpHome(tester);
    // Before the offer: the plain island and the grey dock line.
    expect(_island(tester), 0);
    expect(_islandRing(tester), isNull);
    expect(_dockLine(tester), isNull);

    await _untilCard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    // Card: a 2 px blue line with a soft blue shadow.
    final contour = _cardContour(tester);
    expect(contour.color, _blue);
    expect(contour.width, 2);
    final card = tester.widget<Container>(find.byKey(_card));
    final shadow = (card.decoration! as BoxDecoration).boxShadow!.single;
    expect(shadow.color, _blue.withValues(alpha: 0x1F / 255));
    expect(shadow.blurRadius, 26);
    expect(shadow.offset.dy, lessThan(0));
    // Dock: the line round the radar is blue too.
    expect(_dockLine(tester)!.color, _blue);
    expect(_dockLine(tester)!.strokeWidth, 2);
    // Island: a blue ring and a soft blue glow.
    expect(_island(tester), 1);
    expect(_islandRing(tester)!.top.color, _blue);
    final glow = (tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey<String>('island-exclusive-glow')),
                )
                .decoration
            as BoxDecoration)
        .boxShadow!
        .single;
    expect(glow.color.b, closeTo(_blue.b, 0.01));
    expect(glow.color.a, closeTo(0.40, 0.01));
    await _end(tester);
  });

  testWidgets('the blue fades in with the slide up and out with the slide down', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    await tester.pump(const Duration(milliseconds: 60));
    // Rising: part way between black and blue, like the card.
    final rising = _cardContour(tester).color;
    expect(rising, isNot(_blue));
    expect(_island(tester), inExclusiveRange(0, 1));
    expect(_island(tester), closeTo(1 - _down(tester), 0.001));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_island(tester), 1);

    await tester.tap(find.byKey(const ValueKey<String>('direct-offer-dismiss')));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    // Sinking: the blue goes with it.
    expect(_island(tester), inExclusiveRange(0, 1));
    final sinking = _dockLine(tester)!.color;
    expect(sinking, isNot(_blue));
    expect(sinking, isNot(_black));
    await _frames(tester, const Duration(milliseconds: 500));
    // Down: back to black (the plain island, the grey dock line).
    expect(find.byKey(_card), findsNothing);
    expect(_island(tester), 0);
    expect(_islandRing(tester), isNull);
    expect(_dockLine(tester), isNull);
    await _end(tester);
  });

  testWidgets('time out takes the blue away with the card', (tester) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    final lifetime = DriverOfferRules.current.exclusiveAcceptTime;
    await _frames(tester, lifetime ~/ 2);
    expect(_island(tester), 1);
    expect(_dockLine(tester)!.color, _blue);
    await _frames(tester, lifetime + const Duration(milliseconds: 800));
    expect(find.byKey(_card), findsNothing);
    expect(_island(tester), 0);
    expect(_dockLine(tester), isNull);
    await _end(tester);
  });

  testWidgets('accepting takes the blue away with the card', (tester) async {
    await _pumpHome(tester);
    await _untilCard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_island(tester), 1);
    await tester.tap(_blueRadar);
    await _frames(tester, const Duration(milliseconds: 800));
    expect(find.byType(AcceptRide), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
    expect(
      tester
          .widgetList<DigitalIslandShell>(find.byType(DigitalIslandShell))
          .where((island) => island.exclusive > 0),
      isEmpty,
    );
    await _end(tester);
  });

  testWidgets('reduced motion: the contours just turn blue, and just go', (
    tester,
  ) async {
    await _pumpHome(tester, reduceMotion: true);
    await _untilCard(tester);
    expect(_cardContour(tester).color, _blue);
    expect(_dockLine(tester)!.color, _blue);
    expect(_island(tester), 1);
    await tester.tap(find.byKey(const ValueKey<String>('direct-offer-dismiss')));
    await tester.pump();
    expect(_island(tester), 0);
    expect(_dockLine(tester), isNull);
    await _end(tester);
  });
}
