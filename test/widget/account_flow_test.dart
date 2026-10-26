import 'package:movera/core/money/money.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/admin/driver_home_config_repository.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/session/driving_time_clock.dart';
import 'package:movera/core/vehicle/ride_categories.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/components/radar_offer_deck.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/ride%20requests/ride_requests.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/widgets/custom_google_map.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

// Round 3 (D3) on Home: the driving limit (Q25), documents that run out
// (Q26), the categories the driver drives (Q27), admin's driver app texts
// (Q30) and notification popups (Q31).

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

RideOffer _trip(String id, String category) => RideOffer(
  id: id,
  category: category,
  fare: Money(minorUnits: 8810),
  rating: '4.92',
  pickupMinutes: 3,
  pickupKm: 0.9,
  tripMinutes: 12,
  tripKm: 5.2,
  pickup: 'Tegnérgatan, Stockholm',
  dropoff: 'Odengatan, Stockholm',
  pickupPosition: const GeoPoint(59.3335, 18.0610),
  dropoffPosition: const GeoPoint(59.3428, 18.0475),
  isNearby: true,
  followsDestination: false,
);

/// Admin's Home content with [appTexts] from Content › Driver app texts.
class _Config implements DriverHomeConfigRepository {
  const _Config(this.appTexts);

  final DriverAppTextOverrides appTexts;

  @override
  DriverHomeAdminConfig load() {
    final base = const DriverHomeAdminContentService().load();
    return DriverHomeAdminConfig(
      performance: base.performance,
      scheduledRides: base.scheduledRides,
      update: base.update,
      eventsSectionTitle: base.eventsSectionTitle,
      eventsSectionSubtitle: base.eventsSectionSubtitle,
      events: base.events,
      stockholmWork: base.stockholmWork,
      appTexts: appTexts,
    );
  }
}

Future<void> _frames(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += step) {
    await tester.pump(step);
  }
}

const _radar = ValueKey<String>('trip-radar-touch-target');
const _closeOffer = ValueKey<String>('exclusive-offer-card-home-direct-close');

void _tapRadar(WidgetTester tester) =>
    tester.widget<GestureDetector>(find.byKey(_radar)).onTap!.call();

Future<DriverSessionController> _pumpHome(
  WidgetTester tester, {
  DispatchRepository? dispatch,
  DriverHomeConfigRepository? config,
  bool online = true,
}) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final session = DriverSessionController();
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, __) => MaterialApp(
          home: DriverHome(
            sessionController: session,
            dispatchRepository: dispatch ?? _Dispatch(),
            homeConfigRepository: config,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  if (online) {
    _tapRadar(tester);
    await _frames(tester, const Duration(milliseconds: 1500));
  }
  return session;
}

Iterable<String> get _said => IslandMessages.posted.map((m) => m.title);

TrackedDocument _insurance(int daysLeft) {
  final now = ScheduledClock.realNow();
  return TrackedDocument(
    id: 'DOC-INS-418',
    title: 'Insurance letter',
    shortTitle: 'Insurance',
    expiresOn: DateTime(now.year, now.month, now.day + daysLeft),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    // Only the account rules are under test: missed offers never go offline.
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() => DriverOfferRules.current = const DriverOfferRules());

  group('Q25: 12 h of work, then 6 h of rest', () {
    testWidgets('warns at 30 and 10 min, then rests until HH:MM', (
      tester,
    ) async {
      DrivingTimeClock.instance.load(
        worked: const Duration(hours: 11, minutes: 25),
        offlineSince: ScheduledClock.realNow(),
      );
      final session = await _pumpHome(tester);
      expect(session.availableForOffers, isTrue);

      await tester.pump(const Duration(minutes: 5));
      await _frames(tester, const Duration(milliseconds: 300));
      expect(_said, contains('30 min left to drive'));
      expect(_said, isNot(contains('10 min left to drive')));

      await tester.pump(const Duration(minutes: 20));
      await _frames(tester, const Duration(milliseconds: 300));
      expect(_said, contains('10 min left to drive'));
      expect(session.availableForOffers, isTrue);

      await tester.pump(const Duration(minutes: 10));
      await _frames(tester, const Duration(seconds: 1));
      final until = DrivingTimeClock.instance.restUntil!;
      final rest = 'Rest until ${clockLabel(until)}';
      expect(_said, contains(rest));
      expect(session.availableForOffers, isFalse);
      expect(find.text('REST'), findsOneWidget);
      expect(find.text('Until ${clockLabel(until)}'), findsOneWidget);

      // Going online waits for the rest.
      IslandMessages.reset();
      _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(_said, [rest]);
      expect(session.availableForOffers, isFalse);

      await tester.pump(const Duration(hours: 6));
      await _frames(tester, const Duration(milliseconds: 300));
      expect(_said, contains('Rest over'));
      expect(find.text('REST'), findsNothing);
      expect(find.text('OFF'), findsOneWidget);
      expect(
        DriverNotificationFeed.instance.items.first.kind,
        DriverNoticeKind.restOver,
      );
      _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(session.availableForOffers, isTrue);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Q26: documents that run out', () {
    testWidgets('7 days before: island and notification with Upload new', (
      tester,
    ) async {
      DocumentExpiryStore.instance.load([_insurance(7)]);
      final session = await _pumpHome(tester, online: false);
      await _frames(tester, const Duration(milliseconds: 300));
      expect(_said, contains('Insurance expires in 7 days'));
      final notice = DriverNotificationFeed.instance.items.first;
      expect(notice.kind, DriverNoticeKind.documentExpiring);
      expect(notice.title, 'Insurance letter expires in 7 days');
      expect(notice.actionLabel, 'Upload new');
      // A warning does not block.
      _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(session.availableForOffers, isTrue);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('expired: offline until the new one is approved', (
      tester,
    ) async {
      DocumentExpiryStore.instance.load([_insurance(0)]);
      final session = await _pumpHome(tester, online: false);
      expect(find.text('HOLD'), findsOneWidget);
      expect(find.text('Document expired'), findsOneWidget);

      _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 600));
      expect(_said, contains('Insurance expired'));
      expect(session.availableForOffers, isFalse);
      expect(
        find.byKey(const ValueKey<String>('document-blocked-sheet')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('document-blocked-upload')));
      await _frames(tester, const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const ValueKey<String>('document-upload-send')));
      await _frames(tester, const Duration(milliseconds: 600));
      expect(DocumentExpiryStore.instance.blocking?.inReview, isTrue);
      expect(find.text('Sent for review'), findsOneWidget);

      // In review it still blocks; the demo approves it.
      await tester.tap(find.byKey(const ValueKey<String>('document-blocked-approve')));
      await _frames(tester, const Duration(milliseconds: 300));
      expect(DocumentExpiryStore.instance.blocking, isNull);
      expect(find.text('You can go online now.'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(_said, contains('Document approved'));
      expect(find.text('HOLD'), findsNothing);

      _tapRadar(tester);
      await _frames(tester, const Duration(milliseconds: 1500));
      expect(session.availableForOffers, isTrue);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Q27: offers follow the categories', () {
    testWidgets('a category switched off or not allowed brings no offers', (
      tester,
    ) async {
      DriverCategoryChoice.off.value = {'Comfort'};
      final dispatch = _Dispatch()
        ..publish([
          _trip('comfort-trip', 'Comfort'),
          _trip('premium-trip', 'Premium'),
          _trip('electric-trip', 'Electric'),
        ]);
      await _pumpHome(tester, dispatch: dispatch);
      // The Comfort Exclusive offer of the demo stays away too.
      await _frames(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(_closeOffer), findsNothing);
      // Radar trips follow the Exclusive offer's time to accept.
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(seconds: 4),
      );
      final deck = tester.widget<RadarOfferDeck>(
        find.byKey(const ValueKey<String>('radar-home-deck')),
      );
      expect(deck.ids, ['premium-trip']);
      // Owner N1: the island's middle ("N offers · radar") opens the list.
      await tester.tap(find.byKey(const ValueKey<String>('island-radar-offers')));
      await _frames(tester, const Duration(milliseconds: 800));
      expect(find.byType(RideRequests), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('radar-offer-card-premium-trip')),
        findsOneWidget,
      );
      for (final id in ['comfort-trip', 'electric-trip']) {
        expect(
          find.byKey(ValueKey<String>('radar-offer-card-$id')),
          findsNothing,
        );
      }
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('switching one off takes its offers off Home', (tester) async {
      await _pumpHome(tester);
      await _frames(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(_closeOffer), findsOneWidget);
      DriverCategoryChoice.off.value = {'Comfort'};
      // Its sheet slides down first.
      await _frames(tester, const Duration(milliseconds: 1000));
      expect(find.byKey(_closeOffer), findsNothing);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Q30: driver app texts from admin', () {
    testWidgets('island and offer texts follow admin; empty is the default', (
      tester,
    ) async {
      await _pumpHome(
        tester,
        config: const _Config(DriverAppTextOverrides({
          'en': {
            'island.online': 'Radar is on',
            'offer.accept': 'Take ride',
            'offer.viewRoute': '  ',
          },
        })),
      );
      expect(_said, contains('Radar is on'));
      await _frames(tester, const Duration(milliseconds: 2600));
      final card = find.byKey(_closeOffer);
      // Accept is the grey orb on the Exclusive sheet.
      final radar = find.byKey(const ValueKey<String>('home-radar-exclusive'));
      expect(find.descendant(of: radar, matching: find.text('Take ride')),
          findsOneWidget);
      expect(card, findsOneWidget);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the main trip button reads admin\'s text', (tester) async {
      DriverAppTexts.overrides = const DriverAppTextOverrides({
        'en': {'trip.arrived': 'At pickup'},
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AcceptRide()));
      await tester.pump(const Duration(milliseconds: 400));
      tester
          .widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last)
          .controller!
          .animatePanelToSnapPoint();
      await _frames(tester, const Duration(milliseconds: 700));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('active-ride-arrived-button')),
          matching: find.text('At pickup'),
        ),
        findsOneWidget,
      );
      expect(find.text("I've arrived"), findsNothing);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Q31: notifications', () {
    testWidgets('a demand message pops up on the island, offline too', (
      tester,
    ) async {
      final feed = DriverNotificationFeed.instance;
      feed.arrivals = [(const Duration(seconds: 2), DriverNotices.highDemand)];
      await _pumpHome(tester, online: false);
      await _frames(tester, const Duration(milliseconds: 2400));
      expect(_said, contains('High demand · City'));
      expect(feed.items.first.title, 'High demand in Stockholm City');
      expect(feed.unread, 1);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an Exclusive offer is in the list without a second popup', (
      tester,
    ) async {
      await _pumpHome(tester);
      await _frames(tester, const Duration(milliseconds: 2600));
      expect(find.byKey(_closeOffer), findsOneWidget);
      final notice = DriverNotificationFeed.instance.items.first;
      expect(notice.kind, DriverNoticeKind.exclusiveOffer);
      expect(notice.body, endsWith('s to accept'));
      expect(_said.where((t) => t == 'Exclusive ride'), hasLength(1));
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('R10-12: the Radar deck keeps its drags', () {
    testWidgets('touches on the deck never reach the map', (tester) async {
      final dispatch = _Dispatch()
        ..publish([
          _trip('premium-trip', 'Premium'),
          _trip('premium-two', 'Premium'),
          _trip('premium-three', 'Premium'),
        ]);
      await _pumpHome(tester, dispatch: dispatch);
      await _frames(
        tester,
        DriverOfferRules.current.exclusiveAcceptTime +
            const Duration(seconds: 4),
      );
      final deck = find.byKey(const ValueKey<String>('radar-home-deck'));
      expect(deck, findsOneWidget);
      // The map's own pointer listener (its pan, pinch and gesture report).
      final mapTarget = tester.renderObject(find
          .descendant(
            of: find.byType(CustomGoogleMap),
            matching: find.byType(Listener),
          )
          .first);
      bool reachesMap(Offset at) => tester
          .hitTestOnBinding(at)
          .path
          .any((entry) => entry.target == mapTarget);

      final box = tester.getRect(deck);
      // Anywhere on the deck: the cards, the cards peeking above, the
      // gaps beside them and beside the ALL OFFERS badge.
      final leaks = <Offset>[
        for (var y = box.top + 2; y < box.bottom; y += 8)
          for (var x = box.left + 2; x < box.right; x += 8)
            if (reachesMap(Offset(x, y))) Offset(x, y),
      ];
      expect(leaks, isEmpty);
      // Outside the deck the map still pans.
      expect(reachesMap(Offset(box.center.dx, box.top - 140)), isTrue);

      // A vertical drag on the deck is the deck's; the cards stay.
      await tester.dragFrom(box.center, const Offset(0, -120));
      await _frames(tester, const Duration(milliseconds: 400));
      expect(deck, findsOneWidget);
      tester.takeException();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
