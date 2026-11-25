import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/realtime/driver_realtime.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_runtime_config.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/accept%20ride/meter_change_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../integration_test/headless_map_platform.dart';

/// Owner 2026-11-21 14:40 ("Don't make philosophy"): when the server's
/// trip price changes after the accept (the rider changes the destination
/// or a stop before pickup or during the trip, or waiting adds to it), the
/// driver sees ONLY "Nytt pris: 240,00 kr" (the server's new `fare`, never
/// worked out on the phone) for 5 s; it goes by itself, never blocks the
/// map, and the waybill gets the new price. No taximeter wording.

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void _view(WidgetTester tester, {Map<String, Object> prefs = const {}}) {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Map<String, dynamic> _trip(
  int fareMinor, {
  String status = 'in_trip',
  int version = 5,
}) => {
  'tripId': 'meter-1',
  'version': version,
  'status': status,
  'fare': {'amountMinor': fareMinor, 'currency': 'SEK'},
};

Future<MemoryDriverRealtime> _open(
  WidgetTester tester, {
  ActiveRideStage stage = ActiveRideStage.onTrip,
  Map<String, Object> prefs = const {},
}) async {
  _view(tester, prefs: prefs);
  final realtime = MemoryDriverRealtime();
  addTearDown(realtime.dispose);
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp(
        home: AcceptRide(
          tripId: 'meter-1',
          initialStage: stage,
          activeRideRepository: MemoryActiveRideRepository(),
          waybillRepository: InMemoryWaybillRepository.instance,
          realtime: realtime,
        ),
      ),
    ),
  );
  await _frames(tester);
  return realtime;
}

void _send(MemoryDriverRealtime realtime, Map<String, dynamic> trip) =>
    realtime.emit(
      tripId: 'meter-1',
      kind: DriverRealtimeKind.tripProjection,
      status: switch (trip['status']) {
        'in_trip' => TripStatus.inTrip,
        'cancelled_by_rider' => TripStatus.cancelledByRider,
        _ => TripStatus.driverToPickup,
      },
      projection: trip,
    );

String _sek(int minor) => Money(minorUnits: minor, currency: 'SEK').formatted;

final _notice = find.byKey(const ValueKey('meter-change-notice'));

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _frames(tester, 2);
}

void main() {
  final previous = DriverRuntimeConfig.current;
  setUp(() {
    InMemoryWaybillRepository.instance.reset();
    DriverRuntimeConfig.current = const DriverRuntimeConfig(
      simulatedArrival: false,
      externalRouting: false,
      skipAccountActivation: false,
      liveMapTicker: false,
      reservationPopup: false,
      islandHint: false,
    );
  });
  tearDown(() {
    InMemoryWaybillRepository.instance.reset();
    DriverRuntimeConfig.current = previous;
    DriverAppTexts.reset();
  });

  for (final language in ['sv', 'fr', 'en']) {
    testWidgets('during the trip: a new server price shows only the new '
        'price, then goes by itself after ~5 s ($language)', (tester) async {
      DriverAppTexts.language = language;
      final realtime = await _open(tester);
      _send(realtime, _trip(21500));
      await _frames(tester);
      expect(_notice, findsNothing, reason: 'the first price seen');
      _send(realtime, _trip(24000, version: 6));
      await _frames(tester);
      expect(_notice, findsOneWidget);
      final text = tr.tripNewPrice(_sek(24000));
      expect(find.text(text), findsOneWidget);
      expect(text, switch (language) {
        'sv' => 'Nytt pris: ${_sek(24000)}',
        'fr' => 'Nouveau prix : ${_sek(24000)}',
        _ => 'New price: ${_sek(24000)}',
      });
      // Never blocks the map or the navigation: taps go through it.
      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: _notice, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);
      // Still there at 4 s, gone by itself at 5 s (no tap).
      await tester.pump(const Duration(seconds: 4));
      expect(_notice, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(_notice, findsNothing);
      await _close(tester);
    });
  }

  testWidgets('before pickup (driving to the rider): a new price shows the '
      'notice', (tester) async {
    final realtime = await _open(
      tester,
      stage: ActiveRideStage.headingToPickup,
    );
    _send(realtime, _trip(21500, status: 'driver_to_pickup'));
    await _frames(tester);
    expect(_notice, findsNothing);
    _send(realtime, _trip(24000, status: 'driver_to_pickup', version: 6));
    await _frames(tester);
    expect(_notice, findsOneWidget);
    expect(find.text(tr.tripNewPrice(_sek(24000))), findsOneWidget);
    await tester.pump(MeterChangeNotice.visibleFor);
    await tester.pump();
    expect(_notice, findsNothing);
    await _close(tester);
  });

  testWidgets('the same price again: no notice; each change once', (
    tester,
  ) async {
    final realtime = await _open(tester);
    _send(realtime, _trip(21500));
    await _frames(tester);
    _send(realtime, _trip(21500, version: 6));
    await _frames(tester);
    expect(_notice, findsNothing, reason: 'unchanged price');
    _send(realtime, _trip(24000, version: 7));
    await _frames(tester);
    expect(_notice, findsOneWidget);
    await tester.pump(MeterChangeNotice.visibleFor);
    await tester.pump();
    expect(_notice, findsNothing);
    _send(realtime, _trip(24000, version: 8));
    await _frames(tester);
    expect(_notice, findsNothing, reason: 'the same change is not said twice');
    // A newer price while one shows: the newest amount, time starts again.
    _send(realtime, _trip(26000, version: 9));
    await _frames(tester);
    _send(realtime, _trip(26500, version: 10));
    await _frames(tester);
    expect(_notice, findsOneWidget);
    expect(find.text(tr.tripNewPrice(_sek(26500))), findsOneWidget);
    await _close(tester);
  });

  testWidgets('the waybill shows the new price', (tester) async {
    final realtime = await _open(tester);
    _send(realtime, _trip(21500));
    await _frames(tester);
    _send(realtime, _trip(24000, version: 6));
    await _frames(tester);
    final record = InMemoryWaybillRepository.instance.current;
    expect(record?.tripId, 'meter-1');
    expect(record?.riderFare, _sek(24000));
    await _close(tester);
  });

  const stored = '{"amountMinor":21500,"currency":"SEK"}';

  testWidgets('restore: a price changed while the app was closed shows '
      'the notice and is stored', (tester) async {
    final realtime = await _open(
      tester,
      prefs: {'movera.meter_fare.meter-1': stored},
    );
    _send(realtime, _trip(24000));
    await _frames(tester);
    expect(_notice, findsOneWidget, reason: 'stored 215, server 240');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('movera.meter_fare.meter-1'), contains('24000'));
    await _close(tester);
  });

  testWidgets('restore: the stored price equal to the server shows nothing', (
    tester,
  ) async {
    final realtime = await _open(
      tester,
      prefs: {'movera.meter_fare.meter-1': stored},
    );
    _send(realtime, _trip(21500));
    await _frames(tester);
    expect(_notice, findsNothing);
    await _close(tester);
  });

  testWidgets('the trip ends while the notice shows: it closes', (
    tester,
  ) async {
    final realtime = await _open(tester);
    _send(realtime, _trip(21500));
    await _frames(tester);
    _send(realtime, _trip(24000, version: 6));
    await _frames(tester);
    expect(_notice, findsOneWidget);
    _send(realtime, _trip(24000, status: 'cancelled_by_rider', version: 7));
    await _frames(tester);
    expect(_notice, findsNothing);
    await _close(tester);
  });

  test('no taximeter text in the new notice, the old key is gone', () {
    for (final language in ['en', 'sv', 'fr']) {
      final arb = File('lib/l10n/app_$language.arb').readAsStringSync();
      expect(arb, isNot(contains('meterChangeToAppPrice')), reason: language);
      final line = arb
          .split('\n')
          .firstWhere((l) => l.contains('"tripNewPrice"'));
      expect(line.toLowerCase(), isNot(contains('taxi')), reason: language);
      expect(line.toLowerCase(), isNot(contains('taxa')), reason: language);
    }
    final notice = File(
      'lib/presentation/driver/accept ride/meter_change_notice.dart',
    ).readAsStringSync();
    expect(notice.toLowerCase(), isNot(contains('taxamet')));
    expect(notice.toLowerCase(), isNot(contains('taximet')));
  });

  // Bug 2026-11-25: show() and close()/dispose() in the same frame left
  // the banner stuck on the root overlay (the entry was not mounted yet,
  // so it was never removed).
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return ctx;
  }

  testWidgets('show then close in the same frame leaves nothing', (
    tester,
  ) async {
    final context = await host(tester);
    final notice = MeterChangeNotice();
    notice.show(context, '240,00 kr');
    notice.close();
    expect(notice.isOpen, isFalse);
    await tester.pump();
    expect(_notice, findsNothing);
    await tester.pump(MeterChangeNotice.visibleFor * 2);
    expect(_notice, findsNothing);
    notice.dispose();
  });

  testWidgets('show then dispose in the same frame leaves nothing', (
    tester,
  ) async {
    final context = await host(tester);
    final notice = MeterChangeNotice();
    notice.show(context, '240,00 kr');
    notice.dispose();
    await tester.pump();
    expect(_notice, findsNothing);
    await tester.pump(MeterChangeNotice.visibleFor * 2);
    expect(_notice, findsNothing);
  });
}
