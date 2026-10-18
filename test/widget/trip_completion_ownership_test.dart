import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/ride completed/ride_completed.dart';

class _Session extends DriverSessionController {
  int stays = 0;
  int offlineCommands = 0;

  @override
  void stayOnlineAfterTrip() {
    stays++;
    super.stayOnlineAfterTrip();
  }

  @override
  void setOnline(bool value) {
    if (!value) offlineCommands++;
    super.setOnline(value);
  }
}

class _Navigation extends NavigatorObserver {
  int replacements = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements++;
  }
}

WaybillRecord _record(String id) => WaybillRecord(
  tripId: id,
  statusLabel: 'Queued trip',
  issuedAt: DateTime(2026, 10, 9),
  fare: '128,40 kr',
  service: 'Comfort',
  riderName: 'Demo rider',
  pickup: 'Stockholm',
  dropoff: 'Solna',
  source: 'Demo',
  driverName: 'Demo driver',
  vehicle: 'Demo vehicle',
  licensePlate: 'ABC 123',
  passengerCapacity: 4,
);

Future<GlobalKey<NavigatorState>> _open(
  WidgetTester tester,
  _Session session, {
  Widget? nextRide,
  _Navigation? observer,
}) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [if (observer != null) observer],
      home: const Scaffold(body: Text('Home owner')),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => DriverRideCompleted(
        sessionController: session,
        waybillRepository: InMemoryWaybillRepository.instance,
        nextRide: nextRide,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigator;
}

VoidCallback _done(WidgetTester tester) => tester
    .widget<FilledButton>(find.byKey(const ValueKey('ride-completed-done')))
    .onPressed!;

void main() {
  setUp(InMemoryWaybillRepository.instance.reset);
  tearDown(InMemoryWaybillRepository.instance.reset);

  testWidgets('repeated Done hands off the queued trip once', (tester) async {
    final session = _Session();
    addTearDown(session.dispose);
    final observer = _Navigation();
    final repository = InMemoryWaybillRepository.instance;
    repository.secureNext(_record('next-trip'));
    await _open(
      tester,
      session,
      observer: observer,
      nextRide: const Scaffold(body: Text('Next trip owner')),
    );
    final done = _done(tester);
    done();
    done();
    await tester.pumpAndSettle();
    expect(observer.replacements, 1);
    expect(session.stays, 1);
    expect(session.offlineCommands, 0);
    expect(repository.current?.tripId, 'next-trip');
    expect(repository.next, isNull);
    expect(find.text('Next trip owner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated Done returns Home online, never offline', (
    tester,
  ) async {
    final session = _Session()..setOnline(true);
    addTearDown(session.dispose);
    session.beginTrip('done-trip');
    await _open(tester, session);
    final done = _done(tester);
    done();
    done();
    await tester.pumpAndSettle();
    // R13-5: the driver always stays online after a trip.
    expect(session.stays, 1);
    expect(session.offlineCommands, 0);
    expect(session.isOnline, isTrue);
    expect(find.text('Home owner'), findsOneWidget);
    expect(find.byType(DriverRideCompleted), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covered completion cannot finish or clear its queued trip', (
    tester,
  ) async {
    final session = _Session()..setOnline(true);
    addTearDown(session.dispose);
    final navigator = await _open(tester, session);
    final done = _done(tester);
    InMemoryWaybillRepository.instance.secureNext(_record('preserved-next'));
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Waybill owner')),
      ),
    );
    await tester.pumpAndSettle();
    done();
    await tester.pumpAndSettle();
    expect(find.text('Waybill owner'), findsOneWidget);
    expect(session.offlineCommands, 0);
    expect(session.isOnline, isTrue);
    expect(InMemoryWaybillRepository.instance.next?.tripId, 'preserved-next');
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_done(tester), isNotNull);
    await tester.tap(find.byKey(const ValueKey('ride-completed-done')));
    await tester.pumpAndSettle();
    expect(find.text('Home owner'), findsOneWidget);
    expect(session.offlineCommands, 0);
    expect(session.isOnline, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed completion callback cannot mutate the session', (
    tester,
  ) async {
    final session = _Session()..setOnline(true);
    addTearDown(session.dispose);
    await _open(tester, session);
    final done = _done(tester);
    await tester.pumpWidget(const SizedBox());
    done();
    await tester.pump();
    expect(session.offlineCommands, 0);
    expect(session.isOnline, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missed-offers offline during the trip still wins after Done', (
    tester,
  ) async {
    final session = _Session()..setOnline(true);
    addTearDown(session.dispose);
    session.beginTrip('missed-trip');
    // The admin's missed-Exclusive rule fires on the trip.
    session.setOnline(false);
    await _open(tester, session);
    await tester.tap(find.byKey(const ValueKey('ride-completed-done')));
    await tester.pumpAndSettle();
    expect(find.text('Home owner'), findsOneWidget);
    expect(session.isOnline, isFalse);
  });

  testWidgets('Ride completed is plain: no rider photo, rows and Done', (
    tester,
  ) async {
    final session = _Session()..setOnline(true);
    addTearDown(session.dispose);
    final repository = InMemoryWaybillRepository.instance;
    repository.beginCurrent(_record('trip-1234567890123'));
    repository.completeCurrent();
    await _open(tester, session);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('Ride completed'), findsOneWidget);
    expect(find.text('Rate Demo rider'), findsOneWidget);
    expect(find.text('Comfort · Demo'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('…567890123'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
