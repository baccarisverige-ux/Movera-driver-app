import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

import 'live_fixture.dart';

/// Audit Phase 1 R1 (S2): a live build listed the demo's sample
/// reservations (Lars, Södermalm → Bromma, 184 kr) as if they were real.
void main() {
  tearDown(() {
    LiveDriverServices.instance = null;
    ScheduledRideStore.reset();
  });

  testWidgets('live build: no sample rides, an honest empty state', (
    tester,
  ) async {
    installLive();
    ScheduledRideStore.reset();
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    expect(find.text(tr.schedNoneYet), findsOneWidget);
    expect(find.textContaining('Preview — not binding'), findsNothing);
    expect(ScheduledRideStore.upcoming, isEmpty);
    await tester.tap(find.text(tr.schedAcceptedTab));
    await tester.pump();
    expect(find.textContaining('Bromma'), findsNothing);
    expect(find.text(tr.schedNoneYet), findsOneWidget);
  });

  testWidgets('demo build keeps its labelled samples', (tester) async {
    ScheduledRideStore.reset();
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    expect(find.text(tr.schedNoneYet), findsNothing);
  });
}
