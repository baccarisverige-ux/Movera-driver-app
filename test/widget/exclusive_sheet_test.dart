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
import 'package:movera/presentation/driver/home/components/island_messages.dart';
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
}
