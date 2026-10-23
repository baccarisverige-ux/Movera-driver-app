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
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/movera_radar_orb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

// The Exclusive offer on Home is the same sheet as the reservation
// request, with no blue: the sheet rises over the dock, the grey radar orb
// on its top edge accepts inside a thin dark time ring, the grey pill
// counts the seconds down and the island says "Exclusive · Pickup 3 min".

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

const _card = ValueKey<String>('exclusive-offer-card-home-direct-close');
const _sheet = ValueKey<String>('home-exclusive-sheet');
const _hide = ValueKey<String>('direct-offer-dismiss');
final _orbFinder = find.byKey(const ValueKey<String>('home-radar-exclusive'));

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

/// Pumps single frames until the Exclusive sheet is on screen.
Future<void> _untilSheet(WidgetTester tester) async {
  for (var i = 0; i < 400 && find.byKey(_card).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(find.byKey(_card), findsOneWidget);
}

/// Until the sheet is up (its rise starts on the next frame).
Future<void> _untilUp(WidgetTester tester) async {
  await _untilSheet(tester);
  await tester.pump(const Duration(milliseconds: 16));
  await tester.pump(const Duration(milliseconds: 450));
}

/// How far down the sheet is: 0 up, 1 below the screen.
double _down(WidgetTester tester) => tester
    .widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.byKey(_sheet),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    )
    .translation
    .dy;

MoveraRadarOrb _orb(WidgetTester tester) => tester.widget<MoveraRadarOrb>(
  find.descendant(of: _orbFinder, matching: find.byType(MoveraRadarOrb)),
);

String _pill(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey<String>('exclusive-timer-text')))
    .data!;

int _seconds(WidgetTester tester) =>
    int.parse(RegExp(r'(\d+) s$').firstMatch(_pill(tester))!.group(1)!);

const _blue = Color(0xFF1769E8);

/// Every colour drawn by boxes, texts and the time ring under [root].
Iterable<Color> _colours(WidgetTester tester, Finder root) sync* {
  Iterable<Color> ofDecoration(Decoration? d) sync* {
    if (d is! BoxDecoration) return;
    if (d.color case final c?) yield c;
    if (d.border case final Border b) yield b.top.color;
    for (final shadow in d.boxShadow ?? const <BoxShadow>[]) {
      yield shadow.color;
    }
    yield* d.gradient?.colors ?? const <Color>[];
  }

  for (final e in find
      .descendant(of: root, matching: find.byWidgetPredicate((_) => true))
      .evaluate()) {
    final w = e.widget;
    if (w is Container) yield* ofDecoration(w.decoration);
    if (w is DecoratedBox) yield* ofDecoration(w.decoration);
    if (w is Ink) yield* ofDecoration(w.decoration);
    if (w is Text && w.style?.color != null) yield w.style!.color!;
    if (w is CustomPaint && w.painter is ExclusiveTimeRingPainter) {
      yield (w.painter! as ExclusiveTimeRingPainter).color;
    }
  }
}

bool _isBlue(Color c) => (c.toARGB32() & 0xFFFFFF) == (_blue.toARGB32() & 0xFFFFFF);

Future<void> _end(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
  });

  // First: the pins are drawn in real time and cached per label.
  testWidgets('the route comes once the sheet is up: chips 3 min, 14 min', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilSheet(tester);
    Set<String> pins() => find.byType(CustomGoogleMap).evaluate().isEmpty
        ? const <String>{}
        : {
            for (final m in tester
                .widget<CustomGoogleMap>(find.byType(CustomGoogleMap))
                .markers!)
              if (m.markerId.value.startsWith('radar_')) m.markerId.value,
          };
    // Rising: no route yet.
    expect(pins(), isEmpty);
    for (var i = 0; i < 60 && !pins().contains('radar_dropoff'); i++) {
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
    expect(chip('radar_pickup'), '3 min');
    expect(chip('radar_dropoff'), '14 min');
    await _end(tester);
  });

  testWidgets('rises like the reservation sheet, full width, orb on top', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilSheet(tester);
    // Just arrived: still mostly below the screen.
    expect(_down(tester), greaterThan(0.3));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_down(tester), inExclusiveRange(0, 0.3));
    await tester.pump(const Duration(milliseconds: 250));
    expect(_down(tester), 0);

    // Edge to edge, about 40 % of the screen, down to its bottom.
    final rect = tester.getRect(find.byKey(_sheet));
    expect(rect.left, 0);
    expect(rect.right, 375);
    expect(rect.bottom, 812);
    expect(rect.height, greaterThanOrEqualTo(812 * 0.4 - 1));
    // The grey orb sits centred on the sheet's top edge.
    final orb = tester.getRect(_orbFinder);
    expect(orb.center.dx, closeTo(375 / 2, 1));
    expect(orb.center.dy, closeTo(rect.top, 2));
    // The down arrow top right; no Accept inside the sheet itself.
    expect(
      find.descendant(of: find.byKey(_sheet), matching: find.byKey(_hide)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(_card), matching: find.text('Accept')),
      findsNothing,
    );

    // The details: fare, trip minutes, pickup minutes, trip distance.
    final fare = tester
        .widget<RichText>(find.descendant(
          of: find.byKey(const ValueKey<String>('exclusive-fare')),
          matching: find.byType(RichText),
        ))
        .text
        .toPlainText();
    // 104,80 kr and its pickup pay: one total.
    expect(fare, matches(RegExp(r'^\d+,\d\d kr$')));
    expect(find.text('14 min trip'), findsOneWidget);
    String value(String row) => tester
        .widget<Text>(find.byKey(ValueKey<String>('exclusive-$row-trailing')))
        .data!;
    expect(value('pickup'), '3 min');
    expect(value('dropoff'), '7.6 km');
    expect(find.text('Kungsgatan 42'), findsOneWidget);
    expect(find.text('Hornstull'), findsOneWidget);
    expect(_pill(tester), startsWith('Exclusive for you · '));
    await _end(tester);
  });

  testWidgets('the pill counts the seconds down live', (tester) async {
    await _pumpHome(tester);
    await _untilUp(tester);
    final lifetime = DriverOfferRules.current.exclusiveAcceptTime;
    final first = _seconds(tester);
    expect(first, inInclusiveRange(lifetime.inSeconds - 1, lifetime.inSeconds));
    await _frames(tester, const Duration(seconds: 3));
    expect(_seconds(tester), first - 3);
    await _end(tester);
  });

  testWidgets('the orb: reservation grey, black Accept, dark ring, no blue', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilUp(tester);
    final lifetime = DriverOfferRules.current.exclusiveAcceptTime;

    expect(_orb(tester).exclusive, isTrue);
    expect(_orb(tester).reserve, isTrue);
    Text text(String t) => tester.widget<Text>(
      find.descendant(of: _orbFinder, matching: find.text(t)),
    );
    expect(text('Accept').style!.color, MoveraRadarOrb.reserveTitle);
    expect(text('MATCH').style!.color, MoveraRadarOrb.offerInk);
    expect(find.text('Tap here'), findsOneWidget);
    // No icon inside.
    expect(find.byKey(const ValueKey<String>('radar-exclusive-icon')),
        findsNothing);

    // The thin dark hairline empties over the offer's lifetime.
    ExclusiveTimeRingPainter ring() =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('radar-exclusive-ring')),
                )
                .painter!
            as ExclusiveTimeRingPainter;
    expect(ring().color, MoveraRadarOrb.reserveInk);
    expect(ring().stroke, 1.5);
    expect(ring().timeLeft, greaterThan(0.9));
    await _frames(tester, lifetime ~/ 2);
    expect(ring().timeLeft, closeTo(0.5, 0.06));

    // Nothing on Home is blue: orb, sheet, island.
    expect(_colours(tester, find.byType(DriverHome)).where(_isBlue), isEmpty);
    await _end(tester);
  });

  testWidgets('the island says "Exclusive · Pickup 3 min"', (tester) async {
    await _pumpHome(tester);
    await _untilSheet(tester);
    final face = find.byKey(const ValueKey<String>('island-exclusive'));
    // Once "Exclusive ride" has passed.
    for (var i = 0; i < 80 && face.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final span = tester.widget<Text>(face).textSpan!;
    expect(span.toPlainText(), 'Exclusive · Pickup 3 min');
    final parts = (span as TextSpan).children!.cast<TextSpan>();
    expect(parts.first.style!.color, Colors.white);
    expect(parts.first.style!.fontWeight, FontWeight.w700);
    expect(parts.last.style!.color, const Color(0xFF9FB0BD));
    expect(find.byKey(const ValueKey<String>('island-exclusive-icon')),
        findsOneWidget);
    await _end(tester);
  });

  testWidgets('tapping the grey orb accepts the offer', (tester) async {
    await _pumpHome(tester);
    await _untilUp(tester);
    await tester.tap(_orbFinder);
    await _frames(tester, const Duration(milliseconds: 800));
    final trip = tester.widget<AcceptRide>(find.byType(AcceptRide));
    expect(trip.matchedVia, 'Exclusive offer');
    expect(trip.riderName, 'Nils');
    await _end(tester);
  });

  testWidgets('the down arrow: the sheet waits for the route, then slides', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _untilUp(tester);
    await tester.tap(find.byKey(_hide));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    // The route fades first; the sheet stays put meanwhile.
    expect(_down(tester), 0);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_down(tester), inExclusiveRange(0, 1));
    await _frames(tester, const Duration(milliseconds: 600));
    // Home is normal again.
    expect(find.byKey(_card), findsNothing);
    expect(_orbFinder, findsNothing);
    expect(find.byKey(const ValueKey<String>('radar-online')), findsOneWidget);
    expect(find.byType(AcceptRide), findsNothing);
    await _end(tester);
  });

  testWidgets('when the time runs out it leaves the same way', (tester) async {
    await _pumpHome(tester);
    await _untilSheet(tester);
    final lifetime = DriverOfferRules.current.exclusiveAcceptTime;
    await _frames(tester, lifetime + const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 150));
    // Leaving: still drawn, on its way down.
    expect(find.byKey(_card), findsOneWidget);
    expect(_down(tester), inExclusiveRange(0, 1));
    await _frames(tester, const Duration(milliseconds: 700));
    expect(find.byKey(_card), findsNothing);
    expect(
      tester
          .widgetList<MoveraRadarOrb>(find.byType(MoveraRadarOrb))
          .where((orb) => orb.exclusive),
      isEmpty,
    );
    await _end(tester);
  });

  testWidgets('reduced motion: the sheet is just there, and just goes', (
    tester,
  ) async {
    await _pumpHome(tester, reduceMotion: true);
    await _untilSheet(tester);
    await tester.pump();
    expect(_down(tester), 0);
    await tester.tap(find.byKey(_hide));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(_card), findsNothing);
    await _end(tester);
  });
}
