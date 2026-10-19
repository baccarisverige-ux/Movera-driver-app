import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';

void main() {
  test(
    'authoritative cancellation replaces a tentative local completion once',
    () async {
      SharedPreferences.setMockInitialValues({});
      final active = PrefsActiveRideRepository();
      await active.save(
        const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip),
      );
      final row = WaybillRecord(
        tripId: 'A',
        statusLabel: 'Current',
        issuedAt: DateTime(2026),
        fare: '111,02 kr',
        service: 'Demo',
        riderName: 'Rider',
        pickup: 'P',
        dropoff: 'D',
        source: 'Demo',
        driverName: 'Unavailable',
        vehicle: 'Unavailable',
        licensePlate: 'Unavailable',
        passengerCapacity: 0,
      );
      final journal = CompletionJournal(active: active);
      await journal.finish(row);
      await journal.finish(
        row,
        status: TripStatus.cancelledByRider,
        cancellationActor: 'rider',
        cancellationReasonCode: 'rider_cancelled',
        authoritative: true,
      );
      final rows = await PrefsTripHistoryRepository().list();
      expect(rows, hasLength(1));
      expect(rows.single.status, TripStatus.cancelledByRider);
      expect(rows.single.fareMoney, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList(PrefsActiveRideRepository.terminalKey)!.single,
        contains('|cancelled_by_rider|rider_cancelled|rider|'),
      );
      expect(await active.read(), isNull);
    },
  );
}
