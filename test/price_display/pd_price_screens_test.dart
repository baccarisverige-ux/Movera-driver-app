import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/pickup_pay.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/presentation/driver/accept ride/cash_collect_sheet.dart';
import 'package:movera/widgets/radar_offer_card.dart';

/// Price audit 2026-11-14: widget renders of the offer card (EUR, TND) and
/// the cash collect sheet, for the before / after screenshots. With
/// `--dart-define=PD_SHOTS=<dir>` the PNGs are written there.
const _shots = String.fromEnvironment('PD_SHOTS');

void main() {
  testWidgets('offer card and collect sheet renders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? font;
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final file = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (file.existsSync()) {
        await (FontLoader('PdProof')..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
        font = 'PdProof';
      }
    }

    Future<void> shot(String name, Widget child) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            theme: ThemeData(fontFamily: font),
            home: RepaintBoundary(
              key: const ValueKey('pd-proof'),
              child: Scaffold(
                backgroundColor: const Color(0xFFEFF2F1),
                body: SafeArea(child: child),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: name);
      if (_shots.isEmpty) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('pd-proof')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$_shots/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    RadarOfferView offer(String earnings, Money pickup) => RadarOfferView(
      id: 'pd-${pickup.currency}',
      category: 'Movera',
      payment: 'Card',
      rating: '4.90',
      fare: earnings,
      driverEarnings: earnings,
      pickupMinutes: 6,
      pickupKm: 2.4,
      tripMinutes: 14,
      tripKm: 7.8,
      pickup: 'Rue de Rivoli 12, Paris',
      dropoff: 'Avenue Habib Bourguiba 5, Tunis',
      pickupPay: PickupPayQuote(
        pay: pickup,
        leg: const PickupLeg(km: 2.4, minutes: 6),
      ),
    );

    Widget card(RadarOfferView view) => Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: RadarOfferCard(offer: view, onMatch: () {}),
      ),
    );

    // EUR: earnings 10,00 € + the server's pickup pay 2,50 € = 12,50 €.
    await shot(
      'offer-card-EUR',
      card(offer('10,00 €', const Money(minorUnits: 250, currency: 'EUR'))),
    );
    // TND: 12.500 DT + 1.250 DT = 13.750 DT.
    await shot(
      'offer-card-TND',
      card(offer('12.500 DT', const Money(minorUnits: 1250, currency: 'TND'))),
    );
    await shot(
      'collect-sheet-SEK',
      const CashCollectSheet(
        fare: '150,00 kr',
        cash: '250,00 kr',
        riderName: 'Anna',
        category: 'Movera',
      ),
    );
    await shot(
      'collect-sheet-TND',
      const CashCollectSheet(
        fare: '4.000 DT',
        cash: '5.000 DT',
        riderName: 'Anna',
        category: 'Movera',
      ),
    );
  });
}
