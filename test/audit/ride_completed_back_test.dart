import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride completed/ride_completed.dart';
import 'package:movera/widgets/navigation_transition.dart';

/// driver-u149 / driver-u150: system or browser Back on Ride completed must
/// take the same exit as Done. Before, Back popped straight to Home: the
/// session stayed on trip (Home could never go online again) and a secured
/// next trip was never opened.
class _Session extends DriverSessionController {
  _Session() : super(initialOnline: true);
  int stays = 0;

  @override
  void stayOnlineAfterTrip() {
    stays++;
    super.stayOnlineAfterTrip();
  }
}

WaybillRecord _record(String id) => WaybillRecord(
  tripId: id,
  statusLabel: WaybillRecord.nextTripSecured,
  issuedAt: DateTime(2026, 10, 9),
  fare: '128,40 kr',
  service: 'Comfort',
  riderName: 'Demo rider',
  pickup: 'Stockholm',
  dropoff: 'Solna',
  source: WaybillRecord.demoRadarSource,
  driverName: 'Demo driver',
  vehicle: 'Demo vehicle',
  licensePlate: 'ABC 123',
  passengerCapacity: 4,
);

/// Ride completed over Home, as _completeCurrentTrip puts it there.
Future<void> _open(
  WidgetTester tester,
  _Session session, {
  Widget? nextRide,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: const Scaffold(body: Text('Home owner')),
    ),
  );
  navigator.currentState!.push(
    BottomToTopTransition(
      DriverRideCompleted(
        sessionController: session,
        waybillRepository: InMemoryWaybillRepository.instance,
        nextRide: nextRide,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(DriverRideCompleted), findsOneWidget);
}

void main() {
  setUp(InMemoryWaybillRepository.instance.reset);
  tearDown(InMemoryWaybillRepository.instance.reset);

  testWidgets('Back ends the trip: Home is online and takes offers', (
    tester,
  ) async {
    final session = _Session();
    addTearDown(session.dispose);
    session.beginTrip('trip-A');
    await _open(tester, session);
    await tester.binding.handlePopRoute();
    // A second Back while it leaves does not run the exit twice.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home owner'), findsOneWidget);
    expect(find.byType(DriverRideCompleted), findsNothing);
    expect(session.activeTripId, isNull);
    expect(session.status, isNot(DriverOnlineStatus.onTrip));
    expect(session.availableForOffers, isTrue);
    expect(session.stays, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back opens the secured next trip', (tester) async {
    final session = _Session();
    addTearDown(session.dispose);
    session.beginTrip('trip-A');
    final repository = InMemoryWaybillRepository.instance;
    repository.secureNext(_record('trip-B'));
    await _open(
      tester,
      session,
      nextRide: const Scaffold(body: Text('Next trip owner')),
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Next trip owner'), findsOneWidget);
    expect(find.byType(DriverRideCompleted), findsNothing);
    expect(repository.current?.tripId, 'trip-B');
    expect(repository.next, isNull);
    expect(session.stays, 1);
    expect(tester.takeException(), isNull);
  });
}
