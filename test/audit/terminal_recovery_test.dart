import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/contracts/trip_status.dart';

void main() {
  test(
    'terminal markers are bounded and old timestamped entries expire',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsActiveRideRepository.terminalKey: [
          for (var i = 0; i < 300; i++)
            'old-$i|completed|||2026-01-01T00:00:00.000Z',
        ],
      });
      final repo = PrefsActiveRideRepository();
      await repo.markTerminal(
        'current',
        TripStatus.cancelledByDriver,
        reasonCode: 'vehicle_issue_on_trip',
        actor: 'driver',
        occurredAt: DateTime.utc(2026, 9, 30),
      );
      final prefs = await SharedPreferences.getInstance();
      final markers = prefs.getStringList(
        PrefsActiveRideRepository.terminalKey,
      )!;
      expect(
        markers.length,
        lessThanOrEqualTo(PrefsActiveRideRepository.maxTerminalMarkers),
      );
      expect(markers.any((item) => item.startsWith('current|')), isTrue);
      expect(markers.any((item) => item.startsWith('old-0|')), isFalse);
    },
  );

  test(
    'legacy marker remains readable and still prevents resurrection',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsActiveRideRepository.terminalKey: ['legacy|completed'],
      });
      final repo = PrefsActiveRideRepository();
      await repo.markTerminal(
        'fresh',
        TripStatus.completed,
        occurredAt: DateTime.utc(2026, 9, 30),
      );
      await expectLater(
        repo.save(
          const PersistedActiveRide(
            tripId: 'legacy',
            stage: ActiveRideStage.onTrip,
          ),
        ),
        throwsStateError,
      );
      expect(await repo.read(), isNull);
    },
  );

  test(
    're-marking current terminal trip preserves its original marker',
    () async {
      SharedPreferences.setMockInitialValues({
        PrefsActiveRideRepository.terminalKey: [
          'A|cancelledByDriver|unsafe_pickup|driver|2026-09-30T10:00:00.000Z',
        ],
      });
      final repo = PrefsActiveRideRepository();
      await repo.markTerminal(
        'A',
        TripStatus.cancelledByDriver,
        reasonCode: 'other_on_trip',
        actor: 'driver',
        occurredAt: DateTime.utc(2026, 9, 30, 12),
      );
      final prefs = await SharedPreferences.getInstance();
      final markers = prefs.getStringList(
        PrefsActiveRideRepository.terminalKey,
      )!;
      expect(markers, hasLength(1));
      expect(markers.single, contains('|unsafe_pickup|driver|'));
    },
  );

  test(
    'tombstone prevents terminal snapshot revival even before clear',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PrefsActiveRideRepository();
      await repo.save(
        const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip),
      );
      await repo.markTerminal('A', TripStatus.completed);
      expect(await PrefsActiveRideRepository().read(), null);
      await repo.save(
        const PersistedActiveRide(
          tripId: 'B',
          stage: ActiveRideStage.headingToPickup,
        ),
      );
      expect((await repo.read())?.tripId, 'B');
    },
  );
  test('old and legacy snapshots remain explicit recovery candidates', () {
    final now = DateTime(2026, 9, 30);
    final ride = PersistedActiveRide(
      tripId: 'A',
      stage: ActiveRideStage.onTrip,
      savedAt: now.subtract(const Duration(hours: 7)),
    );
    expect(ride.isFreshAt(now), false);
    expect(PersistedActiveRide.fromJson(ride.toJson())?.tripId, 'A');
    expect(
      PersistedActiveRide.fromJson({
        'tripId': 'old',
        'stage': 'onTrip',
      })?.tripId,
      'old',
    );
    expect(
      PersistedActiveRide.fromJson({
        'schemaVersion': 999,
        'tripId': 'future',
        'stage': 'onTrip',
      }),
      null,
    );
  });
}
