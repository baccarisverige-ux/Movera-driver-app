import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AcceptRide trip orchestration is outside the widget file', () {
    final ride = File('lib/presentation/driver/accept ride/accept_ride.dart')
        .readAsStringSync();
    final trip = File(
      'lib/presentation/driver/accept ride/accept_ride_trip.dart',
    ).readAsStringSync();

    expect(ride, contains("part 'accept_ride_trip.dart';"));
    expect(ride, contains('class AcceptRide'));
    expect(ride, isNot(contains('Future<void> _advanceRide')));
    expect(ride, contains('_onNavigationChangedListener'));
    expect(ride, contains('_syncNavigationStageListener'));
    expect(trip, contains("part of 'accept_ride.dart';"));
    expect(trip, contains('extension _AcceptRideTrip on _AcceptRideState'));
    expect(trip, contains('Future<void> _advanceRide'));
    expect(trip, contains('void _onRealtimeEvent'));
    expect(trip, contains('Future<void> _completeCurrentTrip'));
    expect(ride, contains('void _rebuild('));
    expect(trip, isNot(contains('setState(')));
  });
}
