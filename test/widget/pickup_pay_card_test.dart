import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/widgets/radar_offer_card.dart';

const _lineKey = ValueKey<String>('offer-pickup-pay-line');

RadarOfferView _offer(PickupPayDisplay display) => RadarOfferView(
  id: 'pp1',
  category: 'Comfort',
  payment: 'Card',
  rating: '4.96',
  fare: '120,70 kr',
  pickupMinutes: 9,
  pickupKm: 4.2,
  tripMinutes: 21,
  tripKm: 13.8,
  pickup: 'Odengatan 63, Stockholm',
  dropoff: 'Solna centrum, Solna',
  pickupPay: PickupPayCalculator.quote(
    category: 'Comfort',
    kind: PickupPayOfferKind.exclusive,
    leg: const PickupLeg(km: 4.2, minutes: 9),
    config: PickupPayConfig(
      categories: const <String, PickupPayRate>{
        'Comfort': PickupPayRate(krPerKm: 3, krPerMinute: 1),
      },
      display: display,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
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

Widget _radar(PickupPayDisplay display) =>
    RadarOfferCard(offer: _offer(display), onMatch: () {});

Widget _exclusive(PickupPayDisplay display) =>
    ExclusiveRequestSheet(offer: _offer(display), secondsLeft: 12);

void main() {
  for (final (name, card) in [
    ('Radar card', _radar),
    ('Exclusive sheet', _exclusive),
  ]) {
    testWidgets('$name: one total by default, no pickup line', (tester) async {
      await _pump(tester, card(PickupPayDisplay.totalOnly));
      // The driver's 90,52 kr share of the 120,70 kr fare + 21,60 kr
      // pickup pay; the fare itself never shows (owner decision 2026-10-26).
      expect(find.text('112,12 kr'), findsOneWidget);
      expect(find.text('120,70 kr'), findsNothing);
      expect(find.text('142,30 kr'), findsNothing);
      expect(find.byKey(_lineKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$name: one total also with the pickup line setting (owner 2026-10-27)',
      (tester) async {
        await _pump(tester, card(PickupPayDisplay.fareWithPickupLine));
        expect(find.text('112,12 kr'), findsOneWidget);
        expect(find.byKey(_lineKey), findsNothing);
        expect(find.textContaining('pickup ·'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the driver share gets the pickup pay on top', (tester) async {
    const details = OfferCardDetails(netFare: true);
    final share = details.fare('120,70 kr');
    final offer = _offer(PickupPayDisplay.totalOnly);
    await _pump(
      tester,
      RadarOfferCard(offer: offer, details: details, onMatch: () {}),
    );
    expect(find.text(offer.pickupPay!.totalOf(share)), findsOneWidget);
    expect(offer.shownFare(details), isNot(share));
  });
}
