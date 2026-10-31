import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/widgets/offer_badges.dart';
import 'package:movera/widgets/radar_offer_card.dart';

const _fee = ValueKey<String>('waiting-fee-counter');
const _feeAmount = ValueKey<String>('waiting-fee-amount');
const _noShow = ValueKey<String>('waiting-no-show-cancel');

Future<void> _sheet(
  WidgetTester tester,
  int Function() seconds,
  WaitingTerms terms, {
  bool fullyPaid = false,
}) async {
  WaitingTerms.active = terms;
  await tester.binding.setSurfaceSize(const Size(390, 1300));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WaitingTimeSheet(
          readSeconds: seconds,
          terms: terms,
          fullyPaid: fullyPaid,
          onNoShow: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

String _amount(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_feeAmount)).data!;

RadarOfferView _offer({bool priority = false}) => RadarOfferView(
  id: 'p1',
  category: 'Comfort',
  payment: 'Card',
  rating: '4.92',
  // The fare already has the Movera bonus in it.
  fare: '152,40 kr',
  pickupMinutes: 4,
  pickupKm: 1.3,
  tripMinutes: 16,
  tripKm: 9.4,
  pickup: 'Birger Jarlsgatan 12, Stockholm',
  dropoff: 'Liljeholmstorget, Stockholm',
  priority: priority,
);

Future<void> _card(WidgetTester tester, Widget card) async {
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

void _expectRedBadge(WidgetTester tester, String key) {
  final badge = find.byKey(ValueKey<String>(key));
  expect(badge, findsOneWidget);
  expect(
    find.descendant(of: badge, matching: find.text('Priority')),
    findsOneWidget,
  );
  final box = tester.widget<Container>(
    find.descendant(of: badge, matching: find.byType(Container)).first,
  );
  expect((box.decoration! as BoxDecoration).color, OfferBadge.priorityRed);
  final label = tester.widget<Text>(
    find.descendant(of: badge, matching: find.text('Priority')),
  );
  expect(label.style!.color, Colors.white);
}

void main() {
  group('pickup wait screen (Q41–Q43)', () {
    testWidgets('free wait: no fee, no "Rider didn’t show" yet', (
      tester,
    ) async {
      await _sheet(tester, () => 4 * 60 + 59, const WaitingRules().termsFor());
      expect(find.byKey(_fee), findsNothing);
      expect(find.byKey(_noShow), findsNothing);
      expect(find.text('Rider didn’t show'), findsNothing);
    });

    testWidgets('after the free wait the fee counts up live', (tester) async {
      var seconds = 5 * 60 + 30;
      await _sheet(tester, () => seconds, const WaitingRules().termsFor());
      // 30 s at 12,26 kr / min, all the driver's.
      expect(_amount(tester), '+6,13 kr');
      expect(find.text('waiting fee · 12,26 kr / min'), findsOneWidget);
      seconds = 6 * 60 + 30;
      await tester.pump(const Duration(seconds: 1));
      expect(_amount(tester), '+18,39 kr');
      // The no-show comes when the free wait ends (same 5 min).
      expect(find.byKey(_noShow), findsOneWidget);
      expect(find.text('Rider didn’t show'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('XL: 3 min free, then the fee and the no-show', (tester) async {
      // G5: the XL terms come from the served zone document.
      final xl = DriverAppConfig.fromJson({
        'currency': 'SEK',
        'waiting': {
          'freeWaitMin': 5,
          'perMin': {'amountMinor': 1226, 'currency': 'SEK'},
          'noShowAfterMin': 5,
          'noShowFee': {'amountMinor': 6500, 'currency': 'SEK'},
          'driverSharePct': 80,
          'byCategory': {
            'xl': {'freeWaitMin': 3, 'noShowAfterMin': 3},
            'premium': {
              'perMin': {'amountMinor': 1690, 'currency': 'SEK'},
            },
          },
        },
      }).waiting.termsFor(category: 'Movera XL');
      var seconds = 2 * 60 + 59;
      await _sheet(tester, () => seconds, xl);
      expect(find.byKey(_noShow), findsNothing);
      expect(find.byKey(_fee), findsNothing);
      seconds = 3 * 60;
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(_noShow), findsOneWidget);
      seconds = 3 * 60 + 60;
      await tester.pump(const Duration(seconds: 1));
      expect(_amount(tester), '+12,26 kr');
    });

    testWidgets('the rate comes from the zone config', (tester) async {
      const terms = WaitingTerms(
        freeMinutes: 5,
        perMinute: Money(minorUnits: 300, currency: 'TND'),
        noShowAfterMinutes: 5,
        noShowFee: Money(minorUnits: 5000, currency: 'TND'),
        driverShareNoShowPercent: 80,
      );
      await _sheet(tester, () => 7 * 60, terms);
      expect(_amount(tester), '+0,600 DT');
      expect(
        find.byKey(const ValueKey('waiting-driver-share')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('waiting-driver-share')))
            .data,
        contains('80% of the no-show fee (4,000 DT)'),
      );
    });

    testWidgets('a stop wait is paid from its first second', (tester) async {
      await _sheet(
        tester,
        () => 60,
        const WaitingRules().termsFor(),
        fullyPaid: true,
      );
      expect(_amount(tester), '+12,26 kr');
      expect(find.byKey(_noShow), findsNothing);
    });
  });

  group('admin offers (Q18)', () {
    testWidgets('Radar card: total fare and a red Priority badge', (
      tester,
    ) async {
      await _card(tester, RadarOfferCard(offer: _offer(priority: true)));
      _expectRedBadge(tester, 'radar-offer-priority-p1');
      // The driver's share of the 152,40 kr total (owner decision
      // 2026-10-26; no bonus label given here, so the demo's 25 % on all).
      expect(find.text('114,30 kr', findRichText: true), findsOneWidget);
      expect(find.text('152,40 kr', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Exclusive sheet: total fare and a red Priority badge', (
      tester,
    ) async {
      await _card(
        tester,
        ExclusiveRequestSheet(offer: _offer(priority: true), secondsLeft: 12),
      );
      _expectRedBadge(tester, 'exclusive-offer-priority-p1');
      expect(find.textContaining('114'), findsWidgets);
      expect(find.textContaining('152'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no badge on a normal offer', (tester) async {
      await _card(tester, RadarOfferCard(offer: _offer()));
      expect(find.text('Priority'), findsNothing);
      await _card(
        tester,
        ExclusiveRequestSheet(offer: _offer(), secondsLeft: 12),
      );
      expect(find.text('Priority'), findsNothing);
    });
  });
}
