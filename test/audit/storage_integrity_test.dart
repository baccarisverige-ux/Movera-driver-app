import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/contracts/trip_status.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/privacy/local_data.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

WaybillRecord _record(String id) => WaybillRecord(
  tripId: id,
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

String _journal({String tripId = 'A', Map<String, Object?>? next}) =>
    jsonEncode({
      'schemaVersion': 2,
      'tripId': tripId,
      'status': 'completed',
      'authoritative': false,
      'completedAt': '2026-10-01T10:00:00.000',
      'record': {
        'tripId': tripId,
        'riderName': 'R',
        'fare': '10 kr',
        'service': 's',
        'pickup': 'p',
        'dropoff': 'd',
      },
      if (next != null) 'next': next,
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
  });

  group('N01 completion journal never blocks later trips', () {
    test(
      'queued handoff conflicting with newer trip C is quarantined',
      () async {
        final repo = PrefsActiveRideRepository();
        final prefs = await SharedPreferences.getInstance();
        await repo.save(
          const PersistedActiveRide(tripId: 'C', stage: ActiveRideStage.onTrip),
        );
        await prefs.setString(
          CompletionJournal.key,
          _journal(next: {'tripId': 'B', 'stage': 'headingToPickup'}),
        );

        final outcome = await CompletionJournal(active: repo).reconcile();

        expect(outcome, JournalReplayOutcome.quarantinedConflict);
        expect(prefs.getString(CompletionJournal.key), isNull);
        expect((await repo.read())?.tripId, 'C');
        expect(LocalQuarantine.keys(prefs), hasLength(1));
        final archived = await PrefsTripHistoryRepository().list();
        expect(archived.where((row) => row.tripId == 'A'), hasLength(1));

        // C can still finish normally afterwards.
        await CompletionJournal(active: repo).finish(_record('C'));
        expect(await repo.read(), isNull);
        expect(
          (await PrefsTripHistoryRepository().list()).map((r) => r.tripId),
          containsAll(['A', 'C']),
        );
      },
    );

    for (final corrupt in [
      '{"schemaVersion":2}',
      '{broken',
      '[]',
      '{"schemaVersion":99,"tripId":"A"}',
      _journal().replaceFirst('"completed"', '"teleported"'),
    ]) {
      test(
        'corrupt journal $corrupt is quarantined and finish still works',
        () async {
          final repo = PrefsActiveRideRepository();
          final prefs = await SharedPreferences.getInstance();
          await repo.save(
            const PersistedActiveRide(
              tripId: 'C',
              stage: ActiveRideStage.onTrip,
            ),
          );
          await prefs.setString(CompletionJournal.key, corrupt);

          await CompletionJournal(active: repo).finish(_record('C'));

          expect(prefs.getString(CompletionJournal.key), isNull);
          expect(await repo.read(), isNull);
          expect(LocalQuarantine.keys(prefs), hasLength(1));
          final stored =
              jsonDecode(prefs.getString(LocalQuarantine.keys(prefs).single)!)
                  as Map;
          expect(stored['raw'], corrupt);
        },
      );
    }

    test('reconcile reports corrupt journal outcome', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CompletionJournal.key, '{broken');
      expect(
        await CompletionJournal(
          active: PrefsActiveRideRepository(),
        ).reconcile(),
        JournalReplayOutcome.quarantinedCorrupt,
      );
    });

    test('archived cancellations are labelled by outcome', () async {
      final repo = PrefsActiveRideRepository();
      await repo.save(
        const PersistedActiveRide(tripId: 'X', stage: ActiveRideStage.onTrip),
      );
      await CompletionJournal(active: repo).finish(
        _record('X'),
        status: TripStatus.cancelledByRider,
        cancellationReasonCode: 'rider_cancelled',
        cancellationActor: 'rider',
      );
      final row = (await PrefsTripHistoryRepository().list()).single;
      expect(row.status, TripStatus.cancelledByRider);
    });
  });

  group('N04 unreadable active trip can be closed', () {
    test(
      'typed unreadable error and explicit quarantine unblock new trips',
      () async {
        final prefs = await SharedPreferences.getInstance();
        const raw = '{"tripId":"A","stage":"teleporting"}';
        await prefs.setString(PrefsActiveRideRepository.key, raw);
        final repo = PrefsActiveRideRepository();

        await expectLater(repo.read(), throwsA(isA<ActiveRideUnreadable>()));
        await expectLater(
          repo.save(
            const PersistedActiveRide(
              tripId: 'B',
              stage: ActiveRideStage.headingToPickup,
            ),
          ),
          throwsA(isA<RideOwnershipConflict>()),
        );

        await repo.quarantineUnreadable();

        expect(await repo.read(), isNull);
        await repo.save(
          const PersistedActiveRide(
            tripId: 'B',
            stage: ActiveRideStage.headingToPickup,
          ),
        );
        expect((await repo.read())?.tripId, 'B');
        final stored =
            jsonDecode(prefs.getString(LocalQuarantine.keys(prefs).single)!)
                as Map;
        expect(stored['raw'], raw);
      },
    );

    test('quarantine never discards a readable trip', () async {
      final repo = PrefsActiveRideRepository();
      await repo.save(
        const PersistedActiveRide(tripId: 'A', stage: ActiveRideStage.onTrip),
      );
      await repo.quarantineUnreadable();
      expect((await repo.read())?.tripId, 'A');
    });

    test('a storage plugin failure stays a retryable error', () async {
      final repo = PrefsActiveRideRepository(
        load: () => Future.error(StateError('plugin down')),
      );
      await expectLater(repo.read(), throwsStateError);
    });
  });

  group('N13 terminal markers with delimiter characters', () {
    test('trip id containing a pipe cannot be revived', () async {
      final repo = PrefsActiveRideRepository();
      await repo.save(
        const PersistedActiveRide(tripId: 'X|Y', stage: ActiveRideStage.onTrip),
      );
      await repo.markTerminal('X|Y', TripStatus.completed, reasonCode: 'a|b');
      expect(await repo.read(), isNull);
      await expectLater(
        repo.save(
          const PersistedActiveRide(
            tripId: 'X|Y',
            stage: ActiveRideStage.onTrip,
          ),
        ),
        throwsStateError,
      );
      // A different trip sharing the prefix is unaffected.
      await repo.clearForTrip('X|Y');
      await repo.save(
        const PersistedActiveRide(tripId: 'X', stage: ActiveRideStage.onTrip),
      );
      expect((await repo.read())?.tripId, 'X');
    });
  });

  group('N10 malformed settings are kept, not silently lost', () {
    test(
      'corrupt section is quarantined before it can be overwritten',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'movera_driver_settings_section_contacts',
          '{broken',
        );
        final repo = SettingsRepository();
        expect(await repo.read('contacts'), isEmpty);
        await repo.save('contacts', {'rows': []});
        final stored =
            jsonDecode(prefs.getString(LocalQuarantine.keys(prefs).single)!)
                as Map;
        expect(stored['raw'], '{broken');
        expect(stored['source'], 'settings');
      },
    );

    test('logout clears quarantine', () async {
      final prefs = await SharedPreferences.getInstance();
      await LocalQuarantine.store(prefs, source: 's', raw: 'x', reason: 'r');
      await clearLocalUserData();
      expect(LocalQuarantine.keys(prefs), isEmpty);
    });

    test('quarantine keeps only the newest entries', () async {
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < LocalQuarantine.maxEntries + 3; i++) {
        await LocalQuarantine.store(
          prefs,
          source: 's',
          raw: '$i',
          reason: 'r',
          now: DateTime.utc(2026, 1, 1, 0, 0, i),
        );
      }
      final keys = LocalQuarantine.keys(prefs);
      expect(keys, hasLength(LocalQuarantine.maxEntries));
      final raws = keys
          .map((k) => (jsonDecode(prefs.getString(k)!) as Map)['raw'])
          .toSet();
      expect(raws.contains('0'), isFalse);
      expect(raws.contains('${LocalQuarantine.maxEntries + 2}'), isTrue);
    });
  });
}
