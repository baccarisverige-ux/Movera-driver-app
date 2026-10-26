import 'package:movera/core/contracts/trip_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';

void main() {
  test('driver cancellation reason survives journal cleanup', () async {
    SharedPreferences.setMockInitialValues({});
    final active = PrefsActiveRideRepository();
    await active.save(
      const PersistedActiveRide(
        tripId: 'cancel-A',
        stage: ActiveRideStage.onTrip,
      ),
    );
    final record = WaybillRecord(
      tripId: 'cancel-A',
      statusLabel: 'Current',
      issuedAt: DateTime(2026),
      fare: '10 kr',
      service: 'Demo',
      riderName: 'Sample',
      pickup: 'P',
      dropoff: 'D',
      source: 'Demo',
      driverName: 'Sample',
      vehicle: 'Sample',
      licensePlate: 'Sample',
      passengerCapacity: 4,
    );
    await CompletionJournal(active: active).finish(
      record,
      status: TripStatus.cancelledByDriver,
      cancellationReasonCode: 'unsafe_pickup',
      cancellationActor: 'driver',
    );
    final prefs = await SharedPreferences.getInstance();
    final markers =
        prefs.getStringList(PrefsActiveRideRepository.terminalKey) ??
        const <String>[];
    expect(markers.where((item) => item.startsWith('cancel-A|')), hasLength(1));
    expect(
      markers.single,
      contains('|cancelled_by_driver|unsafe_pickup|driver|'),
    );
    expect(await active.read(), isNull);
  });

  test(
    'rider cancellation retains queued B and archives its terminal outcome',
    () async {
      SharedPreferences.setMockInitialValues({});
      final active = PrefsActiveRideRepository();
      await active.save(
        const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip),
      );
      await CompletionJournal(active: active).finish(
        WaybillRecord(
          tripId: 'A',
          statusLabel: 'Current',
          issuedAt: DateTime(2026),
          fare: '10',
          service: 'Demo',
          riderName: 'Sample',
          pickup: 'P',
          dropoff: 'D',
          source: 'Demo',
          driverName: 'Sample',
          vehicle: 'Sample',
          licensePlate: 'Sample',
          passengerCapacity: 4,
        ),
        status: TripStatus.cancelledByRider,
        next: const PersistedActiveRide(
          tripId: 'B',
          stage: ActiveRideStage.headingToPickup,
        ),
      );
      expect((await active.read())?.tripId, 'B');
      expect(
        (await PrefsTripHistoryRepository().list()).single.status,
        TripStatus.cancelledByRider,
      );
    },
  );
  for (final step in [
    'journal',
    'archive',
    'terminal',
    'snapshot',
    'cleanup',
  ]) {
    test(
      'interruption after $step recovers exactly one receipt and queued B',
      () async {
        SharedPreferences.setMockInitialValues({});
        final active = PrefsActiveRideRepository();
        await active.save(
          const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip),
        );
        final record = WaybillRecord(
          tripId: 'A',
          statusLabel: 'Current',
          issuedAt: DateTime(2026),
          fare: '10 kr',
          service: 'Demo',
          riderName: 'Sample',
          pickup: 'P',
          dropoff: 'D',
          source: 'Demo',
          driverName: 'Sample',
          vehicle: 'Sample',
          licensePlate: 'Sample',
          passengerCapacity: 4,
        );
        final journal = CompletionJournal(
          active: active,
          afterWrite: (at) {
            if (at == step) throw StateError('process interrupted');
          },
        );
        await expectLater(
          journal.finish(
            record,
            next: const PersistedActiveRide(
              tripId: 'B',
              stage: ActiveRideStage.headingToPickup,
            ),
          ),
          throwsStateError,
        );
        await CompletionJournal(
          active: PrefsActiveRideRepository(),
        ).reconcile();
        await CompletionJournal(
          active: PrefsActiveRideRepository(),
        ).reconcile();
        expect(
          (await PrefsTripHistoryRepository().list())
              .where((r) => r.tripId == 'A')
              .length,
          1,
        );
        expect((await active.read())?.tripId, 'B');
      },
    );
  }
}
