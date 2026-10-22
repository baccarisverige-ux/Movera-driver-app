import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/adaptive_trip_island.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

// Wave 5 D5.4 (parts a + b): state and time. Time cases also run under
// TZ=Europe/Stockholm and TZ=America/New_York.

/// Holds each save until the test lets it finish.
class _SlowRides extends MemoryActiveRideRepository {
  final List<Completer<void>> held = [];
  final List<int> saved = [];

  @override
  Future<void> save(PersistedActiveRide ride) async {
    final gate = Completer<void>();
    held.add(gate);
    await gate.future;
    saved.add(ride.stopIndex);
    await super.save(ride);
  }
}

void main() {
  group('driver-8: a demo reservation after midnight on a clock-change day', () {
    final previousNow = ScheduledClock.realNow;
    final previousPlan = DemoReservations.plan;
    tearDown(() {
      ScheduledClock.realNow = previousNow;
      ScheduledClock.instance = ScheduledClock.fastDay();
      DemoReservations.plan = previousPlan;
      DemoReservations.reset();
    });

    // Spring forward: 29 Mar 2026 in Europe, 8 Mar 2026 in the US. Booked
    // at 22:30 on that day, a ride 2 h later is the next day.
    for (final day in [DateTime(2026, 3, 29, 22, 30), DateTime(2026, 3, 8, 22, 30)]) {
      test('booked ${day.month}/${day.day} 22:30, +2 h is "Tomorrow"', () {
        ScheduledClock.realNow = () => day;
        ScheduledClock.instance = ScheduledClock();
        DemoReservations.plan = const DemoReservationPlan(
          main: Duration(hours: 2),
          clashing: Duration(hours: 2, minutes: 25),
          assigned: Duration(hours: 8),
        );
        DemoReservations.reset();
        final main = DemoReservations.main;
        final at = day.add(const Duration(hours: 2));
        expect(main.pickupTime, '${at.hour.toString().padLeft(2, '0')}:30');
        expect(main.pickupDay, 'Tomorrow');
        expect(main.pickupDayAt(day), 'Tomorrow');
      });
    }
  });

  test('driver-u9: every text admin can change is shown by a screen', () {
    const source = 'lib/core/content/driver_app_texts.dart';
    final names = {
      for (final m in RegExp(r"static const (\w+) =\s*DriverTextKey\(\s*'([^']+)'")
          .allMatches(File(source).readAsStringSync()))
        m.group(2)!: m.group(1)!,
    };
    final used = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith(source))
        .map((f) => f.readAsStringSync())
        .join('\n');
    final dead = [
      for (final key in DriverTexts.all)
        if (!RegExp('DriverTexts\\.${names[key.id]}\\b').hasMatch(used)) key.id,
    ];
    expect(dead, isEmpty);
  });

  test('driver-u18: history keeps every row the Month and Week views count', () async {
    final now = DateTime(2026, 10, 22, 12);
    Map<String, Object> row(String id, DateTime at) => {
      'tripId': id, 'riderName': 'R', 'whenLabel': 'x', 'pickup': 'P',
      'dropoff': 'D', 'fare': '10 kr', 'category': 'Comfort',
      'status': 'completed', 'completedAt': at.toUtc().toIso8601String(),
    };
    // 600 October trips (every 30 min back from now) and 50 September ones.
    SharedPreferences.setMockInitialValues({
      PrefsTripHistoryRepository.key: jsonEncode({
        'schemaVersion': 1,
        'rows': [
          for (var i = 0; i < 600; i++)
            row('oct-$i', now.subtract(Duration(minutes: 30 * i))),
          for (var i = 0; i < 50; i++)
            row('sep-$i', DateTime(2026, 9, 20).add(Duration(hours: i))),
        ],
      }),
    });
    final repo = PrefsTripHistoryRepository(now: () => now);
    var rows = await repo.list();
    expect(rows.where((r) => r.tripId.startsWith('oct-')), hasLength(600));
    expect(rows.where((r) => r.tripId.startsWith('sep-')), isEmpty);
    await repo.archive(
      WaybillRecord(tripId: 'new', statusLabel: 'Completed', issuedAt: now,
        fare: '10 kr', service: 'Comfort', riderName: 'R', pickup: 'P',
        dropoff: 'D', source: 'Demo', driverName: 'D', vehicle: 'V',
        licensePlate: 'L', passengerCapacity: 4),
      completedAt: now,
    );
    rows = await repo.list();
    expect(rows, hasLength(601));
    expect(rows.last.tripId, 'oct-599');
  });

  testWidgets('driver-u21: the side menu opens from the tools during a GPS fault',
      (tester) async {
    var menu = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 220,
          child: AdaptiveTripIsland(
            status: 'To pickup', address: 'Sveavägen 20',
            detail: 'Picking up Angelica', eta: '2 min', progress: .4,
            navigationStatus: 'Location updating…',
            waitingMessage: 'Waiting', lastTripLabel: '120 kr',
            onRadar: () {}, onMenu: () => menu++, onSearch: () {},
            onHistory: () {}, onRoute: () {}, onSafety: () {}, onWait: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
    // The fault stays on the island (S03); a tap does not reveal the menu.
    expect(find.text('Location updating…'), findsOneWidget);
    await tester.longPress(find.byKey(const ValueKey('island-morph-shell')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(menu, 1);
    await tester.pumpWidget(const SizedBox());
  });

  test('driver-u32/u33: a save asked for during a background save still runs',
      () async {
    final repo = _SlowRides();
    var stop = 0;
    final ride = ActiveRideController(
      tripId: 'trip-u33',
      repository: repo,
      initialStage: ActiveRideStage.onTrip,
      snapshotBuilder: (stage) => PersistedActiveRide(
          tripId: 'trip-u33', stage: stage, stopIndex: stop),
    );
    addTearDown(ride.dispose);
    final gps = ride.persistNow(); // the 2-minute GPS snapshot
    await pumpEventQueue();
    stop = 1; // the driver leaves stop 1
    final departure = ride.persistNow();
    repo.held.first.complete();
    expect(await gps, isTrue);
    await pumpEventQueue();
    expect(repo.held, hasLength(2), reason: 'the departure is saved too');
    repo.held.last.complete();
    expect(await departure, isTrue);
    expect(repo.saved, [0, 1]);
    expect((await repo.read())!.stopIndex, 1);
  });

  test('driver-u34: snapshot times survive the repeated autumn hour', () {
    // The second 02:20 in Stockholm (25 Oct) and 01:20 in New York (1 Nov).
    for (final instant in [
      DateTime.utc(2026, 10, 25, 1, 20),
      DateTime.utc(2026, 11, 1, 6, 20),
    ]) {
      final at = instant.toLocal();
      final json = PersistedActiveRide(
        tripId: 'trip-u34', stage: ActiveRideStage.onTrip, savedAt: at,
        arrivedAt: at, acceptedAt: at, startedAt: at, scheduledPickupAt: at,
      ).toJson();
      final back = PersistedActiveRide.fromJson(json)!;
      for (final t in [back.savedAt, back.arrivedAt, back.acceptedAt,
          back.startedAt, back.scheduledPickupAt]) {
        expect(t!.toUtc(), instant, reason: '$json');
        expect(t.isUtc, isFalse);
      }
    }
    // An older save in local time reads as before.
    final old = PersistedActiveRide.fromJson({
      ...PersistedActiveRide(tripId: 'old', stage: ActiveRideStage.onTrip)
          .toJson(),
      'savedAt': '2026-10-21T10:00:00.000',
    })!;
    expect(old.savedAt, DateTime(2026, 10, 21, 10));
  });

  test('driver-u37: a journal replayed days later keeps the queued trip stale',
      () async {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
    final active = PrefsActiveRideRepository();
    await active.save(
        const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip));
    final journal = CompletionJournal(active: active, afterWrite: (step) {
      if (step == 'journal') throw StateError('app killed');
    });
    await expectLater(
      journal.finish(
        WaybillRecord(tripId: 'A', statusLabel: 'Completed',
          issuedAt: DateTime(2026), fare: '10 kr', service: 'Comfort',
          riderName: 'R', pickup: 'P', dropoff: 'D', source: 'Demo',
          driverName: 'D', vehicle: 'V', licensePlate: 'L',
          passengerCapacity: 4),
        next: const PersistedActiveRide(
            tripId: 'B', stage: ActiveRideStage.headingToPickup),
      ),
      throwsStateError,
    );
    // The app opens again two days later.
    final prefs = await SharedPreferences.getInstance();
    final entry = jsonDecode(prefs.getString(CompletionJournal.key)!) as Map;
    final completed = DateTime.now().subtract(const Duration(days: 2));
    entry['completedAt'] = completed.toUtc().toIso8601String();
    await prefs.setString(CompletionJournal.key, jsonEncode(entry));
    await CompletionJournal(active: PrefsActiveRideRepository()).reconcile();
    final b = (await PrefsActiveRideRepository().read())!;
    expect(b.tripId, 'B');
    expect(b.isFresh, isFalse, reason: 'Home asks before restoring it');
    expect(b.savedAt!.toUtc(), completed.toUtc());
  });

  group('driver-u45: Ride check after a pause', () {
    const car = GeoPoint(59.33, 18.06);
    final t0 = DateTime(2026, 10, 22, 9);
    const rules = RideCheckRules();
    final stop = Duration(minutes: rules.longStopMinutes);

    test('the first tick after a pause does not count the pause as a stop', () {
      final detector = RideCheckDetector()..startTrip(t0);
      expect(detector.observe(car, t0), isNull);
      // Paused (another app) or a card open: the screen says so and then
      // feeds nothing.
      detector.unwatched();
      final back = t0.add(stop + const Duration(minutes: 1));
      expect(detector.tick(back), isNull);
      expect(detector.tick(back.add(const Duration(seconds: 20))), isNull);
      expect(detector.fired(RideCheckTrigger.longStop), isFalse);
    });

    test('a car standing still with ticks running is still a long stop', () {
      final detector = RideCheckDetector()..startTrip(t0);
      detector.observe(car, t0);
      RideCheckEvent? event;
      for (var t = t0; event == null && t.isBefore(t0.add(stop * 2));) {
        t = t.add(const Duration(seconds: 20));
        event = detector.tick(t);
      }
      expect(event?.trigger, RideCheckTrigger.longStop);
    });
  });
}
