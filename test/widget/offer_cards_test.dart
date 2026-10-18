import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/exclusive_reasons.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
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

ExclusiveRequestSheet _exclusive({
  RadarOfferView? offer,
  bool reservation = false,
  String? reservationTime,
  int secondsLeft = 12,
}) => ExclusiveRequestSheet(
  offer: offer ?? _offer(),
  reservation: reservation,
  reservationTime: reservationTime,
  secondsLeft: secondsLeft,
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

  group('Exclusive offer sheet (same as the reservation sheet)', () {
    testWidgets('chips, fare, trip, stops with their values, the pill', (
      tester,
    ) async {
      await _pump(tester, _exclusive());

      expect(find.text('Comfort'), findsOneWidget);
      expect(find.byKey(_reservationKey), findsNothing);
      expect(find.byKey(_cashKey), findsNothing);
      expect(find.textContaining('Reservation'), findsNothing);
      // Only one waits: no "1 of 1".
      expect(find.byKey(const ValueKey<String>('exclusive-count')),
          findsNothing);

      // Big whole kronor with grey decimals, the trip minutes under it.
      expect(find.text('104,80 kr', findRichText: true), findsOneWidget);
      expect(find.text('14 min trip'), findsOneWidget);

      // Pickup with its minutes, drop-off with the trip distance.
      Finder value(String row) =>
          find.byKey(ValueKey<String>('exclusive-$row-trailing'));
      expect(find.text('Kungsgatan 42'), findsOneWidget);
      expect(find.text('Hornstull'), findsOneWidget);
      expect(tester.widget<Text>(value('pickup')).data, '3 min');
      expect(tester.widget<Text>(value('dropoff')).data, '7.6 km');
      expect(
        tester.widget<Text>(value('pickup')).style!.fontWeight,
        FontWeight.w700,
      );

      // The grey pill counts down; no picture, no Accept, no blue.
      expect(find.text('Exclusive for you · 12 s'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('exclusive-timer-icon')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('reservation-picture')),
          findsNothing);
      expect(find.text('Accept'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      final pill = tester.widget<Container>(
        find.byKey(const ValueKey<String>('exclusive-timer')),
      );
      expect(
        (pill.decoration! as BoxDecoration).color,
        const Color(0xFFF1F2F4),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pill says the seconds it is given, never below 0', (
      tester,
    ) async {
      await _pump(tester, _exclusive(secondsLeft: 3));
      expect(find.text('Exclusive for you · 3 s'), findsOneWidget);
      expect(ExclusiveRequestSheet.pillLabel(-1), 'Exclusive for you · 0 s');
    });

    testWidgets('reservation: "Reservation · 07:40" badge', (tester) async {
      await _pump(
        tester,
        _exclusive(reservation: true, reservationTime: '07:40'),
      );
      expect(find.byKey(_reservationKey), findsOneWidget);
      expect(find.text('Reservation · 07:40'), findsOneWidget);
      expect(find.byKey(_cashKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cash: a Cash chip next to the category', (tester) async {
      await _pump(tester, _exclusive(offer: _offer(payment: 'Cash', bags: 2)));
      expect(
        find.descendant(of: find.byKey(_cashKey), matching: find.text('Cash')),
        findsOneWidget,
      );
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

    testWidgets('the Exclusive sheet shows it too, at 320 wide', (tester) async {
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

    test('the reasons keep one source', () {
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
