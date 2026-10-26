import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/ride/active_ride_controller.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

WaybillRecord _record(String id) => WaybillRecord(
  tripId: id,
  statusLabel: 'Current trip',
  issuedAt: DateTime.utc(2026, 10, 19),
  fare: '126,75 kr',
  service: 'Movera',
  riderName: 'Sample',
  pickup: 'P',
  dropoff: 'D',
  source: 'Demo',
  driverName: 'Sample',
  vehicle: 'Sample',
  licensePlate: 'Sample',
  passengerCapacity: 4,
);

Future<ActiveRideController> _at(ActiveRideStage stage) async {
  final ride = ActiveRideController(tripId: 'T1');
  if (stage.index >= ActiveRideStage.waitingForRider.index) {
    expect(await ride.transitionTo(ActiveRideStage.waitingForRider), isTrue);
  }
  if (stage == ActiveRideStage.onTrip) {
    expect(await ride.transitionTo(ActiveRideStage.onTrip), isTrue);
  }
  return ride;
}

void main() {
  group('driver commands follow contract.json#transitions', () {
    test('no-show only from arrived, and it is no_show', () async {
      final heading = await _at(ActiveRideStage.headingToPickup);
      expect(heading.driverTarget(TripCommand.noShow), isNull);
      expect(await heading.noShow(), isFalse);

      final waiting = await _at(ActiveRideStage.waitingForRider);
      expect(await waiting.noShow(), isTrue);
      expect(waiting.terminalStatus, TripStatus.noShow);
      expect(waiting.terminal, isTrue);
    });

    test('cancel before the rider is on board hands the trip back', () async {
      for (final stage in [
        ActiveRideStage.headingToPickup,
        ActiveRideStage.waitingForRider,
      ]) {
        final ride = await _at(stage);
        expect(ride.driverTarget(TripCommand.cancel), TripStatus.searching);
        expect(await ride.cancel(), isTrue);
        expect(ride.terminalStatus, TripStatus.searching);
        expect(ride.releasedToDispatch, isTrue);
        expect(ride.cancelled, isTrue);
      }
    });

    test('cancel during the trip is cancelled_by_driver', () async {
      final ride = await _at(ActiveRideStage.onTrip);
      expect(await ride.cancel(), isTrue);
      expect(ride.terminalStatus, TripStatus.cancelledByDriver);
      expect(ride.releasedToDispatch, isFalse);
    });

    test('statuses no contract row reaches are rejected', () async {
      final heading = await _at(ActiveRideStage.headingToPickup);
      // A driver cancel at pickup is never cancelled_by_driver.
      expect(
        await heading.cancel(status: TripStatus.cancelledByDriver),
        isFalse,
      );
      // A rider cannot "cancel" once on board (that is end_early, allowed).
      final onTrip = await _at(ActiveRideStage.onTrip);
      expect(
        await onTrip.cancel(status: TripStatus.cancelledBySystem),
        isFalse,
      );
      expect(await onTrip.cancel(status: TripStatus.cancelledByRider), isTrue);
    });
  });

  group('local records use wire names and still read camelCase', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a driver release is journaled, archived and marked', () async {
      final active = PrefsActiveRideRepository();
      await active.save(
        const PersistedActiveRide(
          tripId: 'T1',
          stage: ActiveRideStage.headingToPickup,
        ),
      );
      await CompletionJournal(active: active).finish(
        _record('T1'),
        status: TripStatus.searching,
        cancellationReasonCode: 'vehicle_issue_before_start',
        cancellationActor: 'driver',
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(PrefsActiveRideRepository.terminalKey)!.single,
        startsWith('T1|searching|vehicle_issue_before_start|driver|'),
      );
      final history = await PrefsTripHistoryRepository().list();
      expect(history.single.status, TripStatus.searching);
      expect(history.single.cancellationActor, 'driver');
      expect(await active.read(), isNull);
      final stored =
          jsonDecode(prefs.getString(PrefsTripHistoryRepository.key)!) as Map;
      expect((stored['rows'] as List).single['status'], 'searching');
    });

    test('no-show is stored as no_show', () async {
      final active = PrefsActiveRideRepository();
      await CompletionJournal(active: active).finish(
        _record('T2'),
        status: TripStatus.noShow,
        cancellationReasonCode: 'rider_no_show',
        cancellationActor: 'driver',
      );
      final prefs = await SharedPreferences.getInstance();
      final stored =
          jsonDecode(prefs.getString(PrefsTripHistoryRepository.key)!) as Map;
      expect((stored['rows'] as List).single['status'], 'no_show');
    });

    test('older camelCase journal and history saves still load', () async {
      SharedPreferences.setMockInitialValues({
        PrefsTripHistoryRepository.key: jsonEncode({
          'schemaVersion': 1,
          'rows': [
            {
              'tripId': 'old',
              'riderName': 'R',
              'whenLabel': '1/10/2026, 10:00',
              'pickup': 'P',
              'dropoff': 'D',
              'fare': '10 kr',
              'category': 'Movera',
              'status': 'cancelledByRider',
              'completedAt': '2026-10-01T10:00:00.000',
            },
          ],
        }),
        CompletionJournal.key: jsonEncode({
          'schemaVersion': 2,
          'tripId': 'J',
          'status': 'cancelledByAdmin',
          'completedAt': '2026-10-02T10:00:00.000',
          'record': {
            'tripId': 'J',
            'riderName': 'R',
            'fare': '10 kr',
            'service': 'Movera',
            'pickup': 'P',
            'dropoff': 'D',
          },
        }),
      });
      expect(
        await CompletionJournal(
          active: MemoryActiveRideRepository(),
        ).reconcile(),
        JournalReplayOutcome.applied,
      );
      final rows = await PrefsTripHistoryRepository().list();
      expect(
        {for (final r in rows) r.tripId: r.status},
        {'old': TripStatus.cancelledByRider, 'J': TripStatus.cancelledByAdmin},
      );
    });

    test('a non-driver release status is not a valid record', () async {
      await expectLater(
        PrefsTripHistoryRepository().archive(
          _record('T3'),
          status: TripStatus.searching,
          cancellationActor: 'rider',
        ),
        throwsArgumentError,
      );
    });
  });
}
