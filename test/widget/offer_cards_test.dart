import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/widgets/exclusive_offer_card.dart';
import 'package:movera/widgets/radar_offer_card.dart';

RadarOfferView _offer({String payment = 'Card', int bags = 0}) =>
    RadarOfferView(
      id: 'o1',
      category: 'Comfort',
      payment: payment,
      rating: '4.96',
      fare: '104,80 kr',
      pickupMinutes: 3,
      pickupKm: 0.9,
      tripMinutes: 14,
      tripKm: 7.6,
      pickup: 'Kungsgatan 42, Stockholm',
      dropoff: 'Hornstull, Stockholm',
      bags: bags,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double width = 375,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: card,
          ),
        ),
      ),
    ),
  );
}

ExclusiveOfferCard _exclusive({
  RadarOfferView? offer,
  bool reservation = false,
  String? reservationTime,
  VoidCallback? onAccept,
  VoidCallback? onRoute,
  VoidCallback? onDismiss,
}) => ExclusiveOfferCard(
  offer: offer ?? _offer(),
  lifetime: const Duration(milliseconds: 8500),
  reservation: reservation,
  reservationTime: reservationTime,
  onAccept: onAccept ?? () {},
  onRoute: onRoute ?? () {},
  onDismiss: onDismiss ?? () {},
);

const _cashKey = ValueKey<String>('exclusive-offer-cash-o1');
const _reservationKey = ValueKey<String>('exclusive-offer-reservation-o1');

void main() {
  group('Radar offer card: payment only when it is cash (R2)', () {
    testWidgets('cash shows a Cash badge next to the category', (tester) async {
      await _pump(
        tester,
        RadarOfferCard(
          offer: _offer(payment: 'Cash'),
          onMatch: () {},
        ),
      );

      final cash = find.byKey(const ValueKey<String>('radar-offer-cash-o1'));
      expect(cash, findsOneWidget);
      expect(
        find.descendant(of: cash, matching: find.text('Cash')),
        findsOneWidget,
      );
      // No grey caps any more.
      expect(find.text('CASH'), findsNothing);

      final category = tester.getRect(
        find.byKey(const ValueKey<String>('radar-offer-category-o1')),
      );
      final badge = tester.getRect(cash);
      expect(badge.left, greaterThan(category.right));
      expect(badge.center.dy, closeTo(category.center.dy, 1));
      expect(tester.takeException(), isNull);
    });

    for (final payment in ['Card', 'Apple Pay', 'Wallet', 'Swish']) {
      testWidgets('$payment shows no payment at all', (tester) async {
        await _pump(
          tester,
          RadarOfferCard(
            offer: _offer(payment: payment),
            onMatch: () {},
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('radar-offer-cash-o1')),
          findsNothing,
        );
        expect(find.text('Cash'), findsNothing);
        expect(find.text(payment), findsNothing);
        expect(find.text(payment.toUpperCase()), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('cash and bags fit on a narrow phone in the Live list', (
      tester,
    ) async {
      await _pump(
        tester,
        RadarOfferCard(
          offer: _offer(payment: 'Cash', bags: 2),
          onMatch: () {},
          onDismiss: () {},
        ),
        width: 320,
      );
      expect(
        find.byKey(const ValueKey<String>('radar-offer-cash-o1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('radar-offer-bags-o1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    test('only "cash" counts as cash', () {
      expect(RadarOfferView.isCash('Cash'), isTrue);
      expect(RadarOfferView.isCash(' cash '), isTrue);
      for (final payment in ['Card', 'Apple Pay', 'Wallet', 'Swish', '']) {
        expect(RadarOfferView.isCash(payment), isFalse, reason: payment);
      }
    });
  });

  group('Exclusive offer card (E1/E2)', () {
    testWidgets('plain exclusive: mark, reason, price, timeline, Accept', (
      tester,
    ) async {
      await _pump(tester, _exclusive());

      expect(find.text('Comfort'), findsOneWidget);
      expect(find.text('Exclusive'), findsOneWidget);
      expect(find.text('Only for you · nearby'), findsOneWidget);
      expect(find.byKey(_reservationKey), findsNothing);
      expect(find.byKey(_cashKey), findsNothing);
      expect(find.textContaining('Reservation'), findsNothing);

      // Big whole kronor with grey decimals, pickup time on the right.
      expect(find.text('104,80 kr'), findsOneWidget);
      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('4.96'), findsOneWidget);

      // Street in bold, area under it; times and distances on the right.
      expect(find.text('Kungsgatan 42'), findsOneWidget);
      expect(find.text('Hornstull'), findsOneWidget);
      expect(find.text('Stockholm'), findsNWidgets(2));
      expect(find.text('3 min'), findsNWidgets(2));
      expect(find.text('0.9 km away'), findsOneWidget);
      expect(find.text('14 min'), findsOneWidget);
      expect(find.text('7.6 km ride'), findsOneWidget);

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('9s'), findsOneWidget);
      expect(find.byTooltip('Hide offer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reservation: "Reservation · 07:40" badge and its reason', (
      tester,
    ) async {
      await _pump(
        tester,
        _exclusive(reservation: true, reservationTime: '07:40'),
      );

      expect(find.byKey(_reservationKey), findsOneWidget);
      expect(find.text('Reservation · 07:40'), findsOneWidget);
      expect(find.text('Exclusive'), findsOneWidget);
      expect(find.text('Pickup soon'), findsOneWidget);
      expect(find.text('Only for you · nearby'), findsNothing);
      expect(find.byKey(_cashKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cash and bags: Cash badge, bags count under the price', (
      tester,
    ) async {
      await _pump(tester, _exclusive(offer: _offer(payment: 'Cash', bags: 2)));

      expect(find.byKey(_cashKey), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(_cashKey), matching: find.text('Cash')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('exclusive-offer-bags-o1')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_reservationKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('everything at once still fits a narrow phone', (tester) async {
      await _pump(
        tester,
        _exclusive(
          offer: _offer(payment: 'Cash', bags: 3),
          reservation: true,
          reservationTime: '07:40',
        ),
        width: 320,
      );
      expect(find.byKey(_reservationKey), findsOneWidget);
      expect(find.byKey(_cashKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Accept counts down as a shrinking darker part', (
      tester,
    ) async {
      var accepted = 0, routed = 0, dismissed = 0;
      await _pump(
        tester,
        _exclusive(
          onAccept: () => accepted++,
          onRoute: () => routed++,
          onDismiss: () => dismissed++,
        ),
      );

      final dark = find.descendant(
        of: find.byKey(const ValueKey<String>('direct-offer-countdown-fill')),
        matching: find.byType(ColoredBox),
      );
      final button = tester.getSize(
        find.ancestor(
          of: find.text('Accept'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(tester.getSize(dark).width, closeTo(button.width, 1));

      await tester.pump(const Duration(milliseconds: 4250));
      expect(tester.getSize(dark).width, closeTo(button.width / 2, 2));
      expect(find.text('5s'), findsOneWidget);
      expect(
        tester.getTopLeft(dark).dx,
        closeTo(tester.getTopLeft(find.byType(FilledButton)).dx, 1),
      );

      await tester.tap(find.text('Accept'));
      await tester.tap(
        find.byKey(const ValueKey<String>('direct-offer-route')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('direct-offer-dismiss')),
      );
      await tester.pump();
      expect((accepted, routed, dismissed), (1, 1, 1));

      await tester.pump(const Duration(milliseconds: 4300));
      expect(tester.getSize(dark).width, closeTo(0, 0.5));
      expect(find.text('0s'), findsOneWidget);
    });
  });

  group('Round 3: fare boost (Q13) and one reason source', () {
    RadarOfferView boosted() => const RadarOfferView(
      id: 'o1',
      category: 'Premium',
      payment: 'Card',
      rating: '4.97',
      fare: '249,25 kr',
      pickupMinutes: 6,
      pickupKm: 2.4,
      tripMinutes: 21,
      tripKm: 12,
      pickup: 'Högsätravägen, Lidingö',
      dropoff: 'Central Station, Stockholm',
      fareBoost: '+40 kr',
    );

    testWidgets('the Radar card shows the boost and only the new fare', (
      tester,
    ) async {
      await _pump(tester, RadarOfferCard(offer: boosted(), onMatch: () {}));
      final badge = find.byKey(const ValueKey<String>('radar-offer-boost-o1'));
      expect(badge, findsOneWidget);
      expect(find.descendant(of: badge, matching: find.text('+40 kr')),
          findsOneWidget);
      expect(find.text('249,25 kr', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Exclusive card shows it too, at 320 wide', (tester) async {
      await _pump(
        tester,
        _exclusive(offer: boosted(), reservation: true, reservationTime: '08:05'),
        width: 320,
      );
      expect(
        find.byKey(const ValueKey<String>('exclusive-offer-boost-o1')),
        findsOneWidget,
      );
      expect(find.text('+40 kr'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no boost, no badge', (tester) async {
      await _pump(tester, RadarOfferCard(offer: _offer(), onMatch: () {}));
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('the card shows the reason the offer brings', (tester) async {
      await _pump(
        tester,
        ExclusiveOfferCard(
          offer: _offer(),
          lifetime: const Duration(seconds: 30),
          reservation: true,
          reservationTime: '09:30',
          reason: ExclusiveReasons.text(ExclusiveReasons.assigned),
          onAccept: () {},
        ),
      );
      expect(find.text('Assigned by Movera'), findsOneWidget);
      expect(find.text('Pickup soon'), findsNothing);
      expect(find.text('30s'), findsOneWidget);
      // Without one, the default from the same place.
      expect(
        ExclusiveReasons.defaultFor(reservation: false),
        'Only for you · nearby',
      );
      expect(
        ExclusiveReasons.defaultFor(reservation: true),
        'Pickup soon',
      );
    });
  });

  group('Island says Exclusive (E3/E4)', () {
    test('info blue with a bolt instead of the "i"', () {
      for (final (notice, title) in [
        (HomeIslandNotices.exclusiveRide, 'Exclusive ride'),
        (HomeIslandNotices.exclusiveReservation, 'Exclusive reservation'),
      ]) {
        expect(notice.title, title);
        expect(notice.tone, IslandTone.info);
        expect(notice.icon, Icons.bolt_rounded);
      }
      // Other messages keep their tone's icon.
      expect(HomeIslandNotices.newReservation.icon, isNull);
    });
  });
}
