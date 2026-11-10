// v0.18.57 §79: the driver's emergency numbers come from the country's
// settings (DriverAppConfig.emergencyNumbers), never a fixed 112; 112 only
// when no list was ever received. The config cache keeps the last list.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/emergency_numbers.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/safety toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';

/// `contract.json#configDefaults.emergencyNumbers.TN`.
const tunisia = [
  {
    'kind': 'police',
    'number': '197',
    'label': {'sv': 'Polis', 'fr': 'Police', 'en': 'Police'},
  },
  {
    'kind': 'ambulance',
    'number': '190',
    'label': {
      'sv': 'Ambulans (SAMU)',
      'fr': 'SAMU (ambulance)',
      'en': 'Ambulance (SAMU)',
    },
  },
];

class _NoContacts extends SettingsRepository {
  @override
  Future<Map<String, dynamic>> read(String section) async => {'rows': []};
}

void main() {
  setUp(EmergencyNumbers.reset);
  tearDown(EmergencyNumbers.reset);

  Future<List<String>> pumpKit(
    WidgetTester tester, {
    bool duringTrip = false,
  }) async {
    final dialed = <String>[];
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafetyToolKits(
            duringTrip: duringTrip,
            dialNumber: (number) async {
              dialed.add(number);
              return true;
            },
            sendSos: () async => DriverSosOutcome.sent,
            web: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dialed;
  }

  test('a bad list keeps the last one; 112 only if never received', () {
    expect(EmergencyNumbers.main.number, '112');
    EmergencyNumbers.accept(tunisia);
    EmergencyNumbers.accept(null);
    EmergencyNumbers.accept([
      {'kind': 'x', 'number': '1', 'label': {}},
    ]);
    expect(EmergencyNumbers.current.map((r) => r.number), ['197', '190']);
  });

  testWidgets('no trip, no config: one Call 112 button', (tester) async {
    final dialed = await pumpKit(tester);
    expect(find.text('Call 112'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-call-112')));
    await tester.pumpAndSettle();
    expect(dialed, ['112']);
  });

  testWidgets('no trip, TN: Call 197 and Call 190 buttons', (tester) async {
    EmergencyNumbers.accept(tunisia);
    final dialed = await pumpKit(tester);
    expect(find.text('Call 112'), findsNothing);
    expect(find.text('Call Police 197'), findsOneWidget);
    expect(find.text('Call Ambulance (SAMU) 190'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('safety-call-197')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-call-190')));
    await tester.pumpAndSettle();
    expect(dialed, ['197', '190']);
  });

  testWidgets('TN SOS dials 197, then "SOS sent" offers 190', (tester) async {
    EmergencyNumbers.accept(tunisia);
    final dialed = await pumpKit(tester, duringTrip: true);
    expect(find.byKey(const ValueKey('sos-call-190')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('safety-sos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-sos-send')));
    await tester.pumpAndSettle();
    expect(dialed, ['197']);
    await tester.tap(find.byKey(const ValueKey('sos-call-190')));
    await tester.pumpAndSettle();
    expect(dialed, ['197', '190']);
  });

  test('ride check "Need help" dials the country number', () async {
    EmergencyNumbers.accept(tunisia);
    final launched = <Uri>[];
    final alerts = DemoSafetyAlertRepository();
    final controller = RideCheckController(
      services: RideCheckServices(
        alerts: alerts,
        log: MemoryRideCheckLog(),
        now: () => DateTime(2026, 11, 10, 12),
        launch: (uri) async {
          launched.add(uri);
          return true;
        },
      ),
      tripId: 'trip-1',
      tripDetails: () => const SafetyAlertTrip(
        tripId: 'trip-1',
        riderName: 'R',
        riderRating: 5,
        pickup: 'A',
        dropoff: 'B',
        fare: '10 TND',
        category: 'Comfort',
        driverName: 'D',
        vehicle: 'V',
        plate: 'P',
      ),
    );
    addTearDown(() {
      controller.dispose();
      alerts.dispose();
    });
    controller.open(
      RideCheckDetector().demo(
        RideCheckTrigger.longStop,
        DateTime(2026, 11, 10, 12),
        destination: 'B',
      ),
      instant: true,
    );
    await controller.callEmergency();
    await controller.callEmergency(number: '190');
    expect(launched.map((u) => u.toString()), ['tel:197', 'tel:190']);
  });

  testWidgets('emergency contacts: the built-in rows are the TN numbers', (
    tester,
  ) async {
    EmergencyNumbers.accept(tunisia);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, child) => MaterialApp(home: child),
        child: EmergencyContactsScreen(repository: _NoContacts()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('197'), findsWidgets);
    expect(find.textContaining('190'), findsWidgets);
    expect(find.textContaining('112'), findsNothing);
  });
}
