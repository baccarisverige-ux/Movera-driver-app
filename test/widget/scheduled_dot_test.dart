import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';

void main() {
  setUp(ScheduledRideStore.reset);

  test('The dot stays until every request is answered', () {
    expect(ScheduledRideStore.openRequests.value, 2);
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: true);
    expect(ScheduledRideStore.openRequests.value, 1);
    // Answering the same request twice changes nothing.
    ScheduledRideStore.answer('Gamla vägen, Stockholm', accepted: false);
    expect(ScheduledRideStore.openRequests.value, 1);
    ScheduledRideStore.answer('Högsätravägen, Lidingö', accepted: false);
    expect(ScheduledRideStore.openRequests.value, 0);
  });

  testWidgets('Opening Scheduled rides keeps the requests open', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScheduledRidesScreen()));
    expect(find.text('02'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(ScheduledRideStore.openRequests.value, 2);
  });
}
