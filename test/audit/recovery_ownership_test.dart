import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'terminal snapshot cannot be resurrected by another repository instance',
    () async {
      final first = PrefsActiveRideRepository(),
          second = PrefsActiveRideRepository();
      const a = PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip);
      await first.save(a);
      await second.markTerminal('A', TripStatus.completed);
      await expectLater(first.save(a), throwsStateError);
      await second.clearForTrip('A');
      expect(await first.read(), isNull);
    },
  );
  test(
    'old journal cannot replace a newer active trip or rewind its next trip',
    () async {
      final first = PrefsActiveRideRepository(),
          second = PrefsActiveRideRepository();
      await first.save(
        const PersistedActiveRide(tripId: 'C', stage: ActiveRideStage.onTrip),
      );
      await expectLater(
        second.handoff(
          'A',
          const PersistedActiveRide(
            tripId: 'B',
            stage: ActiveRideStage.headingToPickup,
          ),
        ),
        throwsStateError,
      );
      expect((await first.read())!.tripId, 'C');
      await second.clearForTrip('C');
      await second.handoff(
        'A',
        const PersistedActiveRide(tripId: 'B', stage: ActiveRideStage.onTrip),
      );
      await first.handoff(
        'A',
        const PersistedActiveRide(
          tripId: 'B',
          stage: ActiveRideStage.headingToPickup,
        ),
      );
      expect((await second.read())!.stage, ActiveRideStage.onTrip);
    },
  );
  test(
    'driver-r4-23: web reads what another tab wrote before guarding a save',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final tab = PrefsActiveRideRepository(
        load: () async => prefs,
        sharedAcrossTabs: true,
      );
      const waiting = PersistedActiveRide(
        tripId: 'A',
        stage: ActiveRideStage.waitingForRider,
      );
      await tab.save(waiting);
      // Another tab moves the trip on in localStorage, behind this tab's cache.
      SharedPreferences.setMockInitialValues({
        'flutter.${PrefsActiveRideRepository.key}': jsonEncode(
          const PersistedActiveRide(
            tripId: 'A',
            stage: ActiveRideStage.onTrip,
          ).toJson(),
        ),
      });
      await expectLater(tab.save(waiting), throwsStateError);
    },
  );
  test(
    'malformed storage is an error and remains available for recovery',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsActiveRideRepository.key, 'broken-json');
      await expectLater(
        PrefsActiveRideRepository().read(),
        throwsA(isA<ActiveRideUnreadable>()),
      );
      expect(prefs.getString(PrefsActiveRideRepository.key), 'broken-json');
    },
  );
  test(
    'future timestamps and malformed coordinates cannot bypass recovery',
    () {
      const valid = {'tripId': 'A', 'stage': 'onTrip', 'savedAt': 'bad-date'};
      expect(PersistedActiveRide.fromJson(valid), isNull);
      expect(
        PersistedActiveRide.fromJson({
          'tripId': 'A',
          'stage': 'onTrip',
          'pickupLat': 91,
        }),
        isNull,
      );
      expect(PersistedQueuedTrip.fromJson({'tripId': 'B'}), isNull);
      final future = PersistedActiveRide(
        tripId: 'A',
        stage: ActiveRideStage.onTrip,
        savedAt: DateTime(2030),
      );
      expect(future.isFreshAt(DateTime(2026)), isFalse);
    },
  );
}
