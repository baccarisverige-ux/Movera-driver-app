import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// driver-u64: a screen reader's scroll action on the trip slide must not
/// run the trip step. The only assistive path is the tap, which asks first
/// (accessible_confirmation_test.dart).
void main() {
  for (final action in [SemanticsAction.scrollRight, SemanticsAction.scrollLeft]) {
    testWidgets('$action on the slide does not start the trip', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final semantics = tester.ensureSemantics();
      final repo = MemoryActiveRideRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: AcceptRide(
              tripId: 'accessible-scroll-trip',
              initialStage: ActiveRideStage.waitingForRider,
              activeRideRepository: repo,
            ),
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel).last).controller!.animatePanelToSnapPoint();
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final finder = find.bySemanticsLabel(RegExp('start trip', caseSensitive: false)).first;
      final node = tester.getSemantics(finder);
      final offered = node.getSemanticsData().hasAction(action);
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(viewId: tester.view.viewId, nodeId: node.id, type: action),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(find.text('Confirm this trip action?'), findsNothing);
      expect((await repo.read())!.stage, ActiveRideStage.waitingForRider);
      // The slide does not offer a scroll action at all.
      expect(offered, isFalse);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
