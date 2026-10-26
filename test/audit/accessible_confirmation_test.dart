import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('assistive confirmation asks before starting a trip', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final semantics = tester.ensureSemantics();
    final repo = MemoryActiveRideRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: AcceptRide(
            tripId: 'accessible-trip',
            initialStage: ActiveRideStage.waitingForRider,
            activeRideRepository: repo,
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    tester
        .widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last)
        .controller!
        .animatePanelToSnapPoint();
    for (var i = 0; i < 14; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('start trip', caseSensitive: false)).first,
    );
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        viewId: tester.view.viewId,
        nodeId: node.id,
        type: SemanticsAction.tap,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Confirm this trip action?'), findsOneWidget);
    expect((await repo.read())!.stage, ActiveRideStage.waitingForRider);
    await tester.tap(find.text('Confirm'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect((await repo.read())!.stage, ActiveRideStage.onTrip);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
