import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AcceptRide panel and contact presentation sit outside the widget file',
    () {
      final ride = File(
        'lib/presentation/driver/accept ride/accept_ride.dart',
      ).readAsStringSync();
      final panel = File(
        'lib/presentation/driver/accept ride/accept_ride_panel.dart',
      ).readAsStringSync();

      expect(ride, contains("part 'accept_ride_panel.dart';"));
      expect(ride, contains('class AcceptRide'));
      expect(ride, contains('Widget build(BuildContext context)'));
      expect(ride, isNot(contains('Widget _buildRidePanel')));
      expect(ride, isNot(contains('Widget _buildRiderRow')));
      expect(panel, contains("part of 'accept_ride.dart';"));
      expect(panel, contains('extension _AcceptRidePanel on _AcceptRideState'));
      expect(panel, contains('Widget _buildRidePanel'));
      expect(panel, contains('Widget _buildRiderRow'));
      expect(
        panel,
        contains(
          'Chat(riderDisplayName: widget.riderName, tripId: widget.tripId)',
        ),
      );
      expect(panel, isNot(contains('setState(')));
      // Phase 2: was < 1800 before `dart format` (tall style); same code
      // measured 1798 → 2146 lines, so the limit scales by the same factor.
      expect(ride.split('\n').length, lessThan(2150));
    },
  );
}
