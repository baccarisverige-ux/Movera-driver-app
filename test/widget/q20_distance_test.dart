import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/presentation/driver/home/components/home_offer_sheet.dart';
import 'package:movera/widgets/radar_offer_card.dart';

RadarOfferView _offer({double pickupKm = 0.65, double tripKm = 4.2}) =>
    RadarOfferView(
      id: 'o1',
      category: 'Comfort',
      payment: 'Card',
      rating: '4.96',
      fare: '104,80 kr',
      pickupMinutes: 2,
      pickupKm: pickupKm,
      tripMinutes: 9,
      tripKm: tripKm,
      pickup: 'Kungsgatan 42, Stockholm',
      dropoff: 'Hornstull, Stockholm',
    );

Future<void> _pump(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: card)),
    ),
  );
}

// Q20: under 1 km in metres ("650 m · 2 min"), above in km ("4.2 km · 9 min").
void main() {
  test('the one rule', () {
    expect(driverDistanceMeters(650), '650 m');
    expect(driverDistanceMeters(648), '650 m');
    expect(driverDistanceMeters(40), '40 m');
    expect(driverDistanceMeters(994), '990 m');
    expect(driverDistanceMeters(996), '1.0 km');
    expect(driverDistanceMeters(4200), '4.2 km');
    expect(driverDistanceMeters(9960), '10 km');
    expect(driverDistanceMeters(12400), '12 km');
    expect(driverDistanceKm(0.65), '650 m');
    expect(driverDistanceAndMinutes(0.65, 2), '650 m · 2 min');
    expect(driverDistanceAndMinutes(4.2, 9), '4.2 km · 9 min');
  });

  test('pickup leg and the offer sheets', () {
    expect(const PickupLeg(km: 0.65, minutes: 2).label, '650 m · 2 min');
    expect(const PickupLeg(km: 4.2, minutes: 9).label, '4.2 km · 9 min');
    expect(OfferSheetBody.km(0.8), '800 m');
    expect(OfferSheetBody.km(8.5), '8.5 km');
  });

  testWidgets('the Radar card: pickup in metres, trip in km', (tester) async {
    await _pump(tester, RadarOfferCard(offer: _offer(), onMatch: () {}));
    expect(find.text('650 m away'), findsOneWidget);
    expect(find.text('9 min trip · 4.2 km'), findsOneWidget);
    expect(find.textContaining('0.7 km'), findsNothing);
  });

  testWidgets('an admin text with {km} alone keeps the number', (tester) async {
    DriverAppTexts.overrides = const DriverAppTextOverrides({
      'en': {'offer.kmAway': 'Pickup {km}'},
    });
    addTearDown(DriverAppTexts.reset);
    await _pump(
      tester,
      RadarOfferCard(offer: _offer(pickupKm: 2.3), onMatch: () {}),
    );
    expect(find.text('Pickup 2.3'), findsOneWidget);
  });
}
