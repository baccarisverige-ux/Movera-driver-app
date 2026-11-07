import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/ride/waiting_rules.dart';
import 'package:movera/presentation/driver/accept%20ride/waiting_time_sheet.dart';

/// Supervisor finding B (2026-11-07): the pickup-wait sheet decided "Rider
/// didn't show" from the global [WaitingTerms.active], not from the terms
/// the trip screen hands it (`terms:`, anchored on the server's
/// `waiting.noShowAt`). With the zone's 5 min, a server noShowAt at 30 min
/// and 400 s waited, the button was shown, and the trip screen's own check
/// (the anchored terms) then ignored the tap. The sheet now follows its
/// `terms`: the button only from noShowAt.
void main() {
  final zone = WaitingTerms(
    freeMinutes: 5,
    perMinute: Money.zone(500),
    noShowAfterMinutes: 5,
    noShowFee: Money.zone(6500),
    driverShareNoShowPercent: 80,
  );
  // The server's moments: free and no-show 30 min after Arrived.
  final anchored = zone.anchored(freeSeconds: 30 * 60, noShowSeconds: 30 * 60);

  setUp(() => WaitingTerms.active = zone);
  tearDown(() => WaitingTerms.active = WaitingRules.current.base);

  Future<int> pumpSheet(WidgetTester tester, int seconds) async {
    var taps = 0;
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaitingTimeSheet(
            readSeconds: () => seconds,
            terms: anchored,
            onNoShow: () => taps++,
          ),
        ),
      ),
    );
    await tester.pump();
    return taps;
  }

  final button = find.byKey(const ValueKey('waiting-no-show-cancel'));

  testWidgets('400 s waited, noShowAt at 30 min: no "Rider didn\'t show"', (
    tester,
  ) async {
    await pumpSheet(tester, 400);
    expect(button, findsNothing);
    // Still the free minutes, by the trip's terms.
    expect(find.text('Included minutes'), findsOneWidget);
    expect(find.byKey(const ValueKey('waiting-fee-counter')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('at noShowAt (30 min) the button is there', (tester) async {
    await pumpSheet(tester, 30 * 60);
    expect(button, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
