import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/core/island/trip_island_controller.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/common/chat/chat.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/cash_collect_sheet.dart';
import 'package:movera/presentation/driver/accept%20ride/ride_check_card.dart';
import 'package:movera/presentation/driver/analytics/analytics.dart';
import 'package:movera/presentation/driver/analytics/cancelation%20rate/cancelation_rate.dart';
import 'package:movera/presentation/driver/documents/documents.dart';
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

/// Wave 5 D5.1 (parts a and b): texts that stayed in English, or in the
/// language a trip opened in, now follow the driver's language.
void speak(String code) => DriverAppTexts.language = code;

/// [home] in [code] on a roomy phone.
Future<void> show(WidgetTester tester, String code, Widget home) async {
  speak(code);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (_, __) => MaterialApp(
      locale: Locale(code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  ));
  await tester.pump();
}

/// [text] on screen, also inside rich text.
Finder words(String text) => find.textContaining(text, findRichText: true);

/// A phone in Paris, far from the demo pickup.
class FarAway implements DriverLocationRepository {
  DriverLocation get _fix => DriverLocation(
    point: const GeoPoint(48.8566, 2.3522),
    measuredAt: DateTime.now(),
    accuracyMeters: 5,
  );

  @override
  Future<DriverLocation> getCurrentPosition() async => _fix;

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      Stream<DriverLocation>.value(_fix);
}

Future<void> frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A microphone that never finishes starting.
class SlowRecorder implements RideCheckRecorder {
  final _never = Completer<void>();
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(String recordingId) => _never.future;
  @override
  Future<String?> stop() async => null;
  @override
  Future<void> cancel() async {}
}

/// A Ride check on a demo trip, with what it saves and sends.
class RideCheckKit {
  RideCheckKit() {
    controller = RideCheckController(
      services: RideCheckServices(
        alerts: alerts,
        log: log,
        now: () => now,
        recorder: SlowRecorder.new,
        launch: (_) async => true,
      ),
      tripId: 'trip-1',
      tripDetails: () => const SafetyAlertTrip(
        tripId: 'trip-1',
        riderName: 'Angelica',
        riderRating: 4.9,
        pickup: 'Odlarvägen 22',
        dropoff: 'T-Centralen, Stockholm',
        fare: '126 kr',
        category: 'Comfort',
        driverName: 'Movera Driver',
        vehicle: 'Volvo XC60',
        plate: 'ABC 123',
      ),
    );
  }

  final now = DateTime(2026, 10, 15, 14, 30);
  final alerts = DemoSafetyAlertRepository();
  final log = MemoryRideCheckLog();
  late final RideCheckController controller;

  void open([RideCheckTrigger trigger = RideCheckTrigger.longStop]) =>
      unawaited(controller.open(
        RideCheckDetector().demo(trigger, now, destination: 'T-Centralen'),
        instant: true,
      ));

  void dispose() {
    controller.dispose();
    alerts.dispose();
  }
}

/// What the island strip says for [inputs], in order.
Future<List<String>> stripSays(
  WidgetTester tester,
  List<TripStripInput> inputs,
) async {
  final strip = TripStripController(clock: () => DateTime(2026, 1, 1, 6));
  addTearDown(strip.dispose);
  final seen = <String>[];
  strip.addListener(() {
    if (strip.current.kind == TripStripKind.message) {
      seen.add(strip.current.text);
    }
  });
  for (final input in inputs) {
    strip.update(input);
    await tester.pump(TripStripController.messageTime);
  }
  return seen;
}

/// The languages each screen is checked in.
const languages = ['fr', 'sv'];

void main() {
  test('driver-33: French plurals take the singular for 0 and 1', () {
    speak('fr');
    expect(tr.tripsCount(0), '0 course');
    expect(tr.tripsCount(1), '1 course');
    expect(tr.tripsCount(2), '2 courses');
    expect(tr.stopsCount(0), '0 arrêt');
    expect(tr.riderBags(0), 'Le passager a 0 bagage');
    expect(tr.inDaysCount(0), 'dans 0 jour');
    expect(tr.schedRidesHidden(0), '0 course masquée');
    expect(tr.ratingAndRides('4,9', 0), '4,9 ★ · 0 course');
    speak('sv');
    expect(tr.tripsCount(0), '0 resor');
    expect(tr.tripsCount(1), '1 resa');
  });

  for (final code in languages) {
    testWidgets('driver-14: cash direction in $code', (tester) async {
      await show(tester, code, const Scaffold(
        body: CashCollectSheet(
          fare: '248,40 kr', cash: '300,00 kr', riderName: 'Nils'),
      ));
      expect(words(tr.cashYouOweMovera), findsWidgets);
      expect(words('You owe Movera'), findsNothing);
    });
  }

  for (final code in languages) {
    testWidgets('driver-15: decimals take the comma in $code', (tester) async {
      await show(tester, code, const CancelationRate());
      expect(words('2,4%'), findsWidgets);
      expect(words('2.4%'), findsNothing);
      expect(driverDistanceMeters(4200), '4,2 km');
      expect(driverDistanceAndMinutes(4.2, 9), '4,2 km · 9 min');
    });
  }

  for (final (code, said) in [('fr', 'Ensuite : Arrêt 1'), ('sv', 'Härnäst: Stopp 1')]) {
    testWidgets('driver-17: the next stop in $code', (tester) async {
      speak(code);
      final seen = await stripSays(tester, [
        TripStripInput(leg: TripLeg.stop, stopLabel: tr.stopNumber(1)),
      ]);
      expect(seen, [said]);
    });
  }

  for (final (code, said) in [
    ('fr', 'Prise en charge côté gauche'),
    ('sv', 'Upphämtning på vänster sida'),
  ]) {
    testWidgets('driver-u87: the pickup side in $code', (tester) async {
      speak(code);
      final seen = await stripSays(tester, [
        const TripStripInput(leg: TripLeg.pickup, pickupSide: 'left'),
      ]);
      expect(seen, [said]);
    });
  }

  for (final code in languages) {
    testWidgets('driver-41: arriving too far from the pickup in $code',
        (tester) async {
      final previous = DriverRuntimeConfig.current;
      addTearDown(() => DriverRuntimeConfig.current = previous);
      DriverRuntimeConfig.current = const DriverRuntimeConfig(
        simulatedArrival: false,
        externalRouting: false,
        skipAccountActivation: false,
        liveMapTicker: false,
      );
      await show(tester, code, AcceptRide(locationRepository: FarAway()));
      await frames(tester, 10);
      tester.widget<SlidingUpPanel>(find.byType(SlidingUpPanel))
          .controller!.animatePanelToSnapPoint();
      await frames(tester, 14);
      final button = find.byKey(const ValueKey('active-ride-arrived-button'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await frames(tester, 6);
      expect(find.text(tr.moveWithin100MOfPickup), findsOneWidget);
      expect(words('(pickup)'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final code in languages) {
    testWidgets('driver-u48: rider phone not connected in $code',
        (tester) async {
      await show(tester, code, const Chat(riderDisplayName: 'Maya'));
      await tester.tap(find.byTooltip(tr.riderPhoneNotConnected));
      await tester.pump();
      expect(find.text(tr.riderPhoneNotConnected), findsOneWidget);
      expect(words('not connected in this demo'), findsNothing);
    });
  }

  for (final code in languages) {
    testWidgets('driver-u93: the microphone starting in $code',
        (tester) async {
      speak(code);
      final kit = RideCheckKit();
      addTearDown(kit.dispose);
      kit.open();
      unawaited(kit.controller.toggleRecording());
      await tester.pump();
      expect(kit.controller.audio, RideCheckAudio.starting);
      final note = TextEditingController();
      addTearDown(note.dispose);
      await show(tester, code, Scaffold(
        backgroundColor: Colors.black,
        body: RideCheckCard(controller: kit.controller, note: note),
      ));
      expect(words(tr.recordAudioStarting), findsOneWidget);
      expect(words('starting…'), findsNothing);
    });
  }

  for (final code in languages) {
    test('driver-51: the photo limits in $code', () async {
      SharedPreferences.setMockInitialValues({});
      speak(code);
      String photo(int bytes) => base64Encode(Uint8List(bytes));
      Map<String, dynamic> vehicle(String id, List<int> photos) => {
        'id': id, 'make': 'Volvo', 'model': 'XC60', 'year': '2024',
        'plate': 'ABC 123',
        for (final (i, bytes) in photos.indexed)
          ['registrationPhoto', 'insurancePhoto'][i]: photo(bytes),
      };
      final store = LocalVehicleStore();
      Future<String> refusal(Map<String, dynamic> row) async {
        try {
          await store.upsert(row);
        } on VehiclePhotoBudgetExceeded catch (error) {
          return error.message;
        }
        return 'saved';
      }

      expect(
        await refusal(vehicle('v1', [LocalVehicleStore.maxPhotoBytes + 1024])),
        tr.photoTooLargeForDevice,
      );
      const each = 600 * 1024;
      await store.upsert(vehicle('v1', [each, each]));
      await store.upsert(vehicle('v2', [each]));
      expect(await refusal(vehicle('v2', [each, each])), tr.photoStorageFull);
      expect(tr.photoStorageFull, isNot(contains('Photo storage')));
    });
  }

  for (final code in languages) {
    testWidgets('driver-52: demo badges and the zone header in $code',
        (tester) async {
      await show(tester, code, const Analytics());
      expect(words(tr.demoDataBadge), findsOneWidget);
      expect(words(tr.anaSampleTripRoute), findsOneWidget);
      expect(words('DEMO DATA'), findsNothing);
      await show(tester, code, const DrivingLogs());
      expect(words(tr.demoDataBadge), findsOneWidget);
      await show(tester, code, const DriverDocuments());
      expect(words(tr.drivingInHeader), findsOneWidget);
      expect(words('DRIVING IN'), findsNothing);
    });
  }
}
