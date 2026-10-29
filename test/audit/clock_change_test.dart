import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/onboarding/document_status.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Times across a clock change (Europe: 29 Mar 2026 02:00 → 03:00, 25 Oct
/// 2026 03:00 → 02:00). Run with TZ=Europe/Stockholm to see the change;
/// elsewhere the expectations hold too.
void main() {
  const ride = ReservationRequestPreview(
    category: 'Comfort',
    fare: '126,75 kr',
    pickupLabel: 'Pickup today 01:50',
    pickupAddress: 'Gamla vägen',
    dropoffAddress: 'Solna centrum',
    pickupTime: '01:50',
    pickupDay: 'Today',
    tripMinutes: 20,
    tripKm: 9,
    pickup: GeoPoint(59.33, 18.06),
    dropoff: GeoPoint(59.36, 18.0),
  );

  test('a reservation arrives trip minutes after its pickup instant '
      '(driver-r4-13)', () {
    final pickup = DateTime(2026, 3, 29, 1, 50);
    expect(
      ride.scheduledFor(pickup).arrivalTime,
      clockLabel(pickup.add(const Duration(minutes: 20))),
    );
    // "Today 07:40" on the spring-forward day is 07:40, not 08:40.
    const morning = ReservationRequestPreview(
      category: 'Comfort',
      fare: '126,75 kr',
      pickupLabel: 'Pickup today 07:40',
      pickupAddress: 'Gamla vägen',
      dropoffAddress: 'Solna centrum',
      pickupTime: '07:40',
      pickupDay: 'Today',
      tripMinutes: 19,
      tripKm: 9,
      pickup: GeoPoint(59.33, 18.06),
      dropoff: GeoPoint(59.36, 18.0),
    );
    final at = morning.pickupAt(DateTime(2026, 3, 29, 0, 30))!;
    expect([at.day, at.hour, at.minute], [29, 7, 40]);
  });

  test('document days left count whole days across the autumn change '
      '(driver-r4-12, contract v0.17.0 daysLeft rounded up)', () {
    final now = DateTime.utc(2026, 10, 21, 7);
    // 7 calendar days later in Stockholm, with the 25 Oct clock change
    // between: still 7 days, never 6 or 8.
    expect(documentDaysLeft(DateTime.utc(2026, 10, 28, 6), now), 7);
    expect(documentDaysLeft(DateTime.utc(2026, 10, 28, 7), now), 7);
    expect(documentDaysLeft(DateTime.utc(2026, 10, 21, 6), now), 0);
  });

  group('saved times keep their instant in the repeated autumn hour '
      '(driver-r4-14)', () {
    final cest = DateTime.utc(2026, 10, 25, 0, 30).toLocal(); // 02:30 CEST
    final cet = DateTime.utc(2026, 10, 25, 1, 10).toLocal(); // 02:10 CET
    WaybillRecord trip(String id) => WaybillRecord(
      tripId: id,
      statusLabel: 'Completed',
      issuedAt: cest,
      fare: '126,75 kr',
      service: 'Comfort',
      riderName: 'Rider',
      pickup: 'P',
      dropoff: 'D',
      source: 'Radar',
      driverName: 'Driver',
      vehicle: 'Vehicle',
      licensePlate: 'ABC 123',
      passengerCapacity: 4,
    );
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      CompletionJournal.resetForTesting();
    });

    test('Ride history', () async {
      final repo = PrefsTripHistoryRepository();
      await repo.archive(trip('first'), completedAt: cest);
      await repo.archive(trip('second'), completedAt: cet);
      final rows = await PrefsTripHistoryRepository().list();
      expect(rows.map((r) => r.tripId), ['second', 'first']);
      expect(rows.last.completedAt!.isAtSameMomentAs(cest), isTrue);
      expect(rows.last.completedAt!.isUtc, isFalse);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(PrefsTripHistoryRepository.key)!;
      expect(saved, contains('"completedAt":"2026-10-25T00:30:00.000Z"'));
    });

    test(
      'a journal saved in UTC replays at local time; old ones still do',
      () async {
        String journal(String id, String at) => jsonEncode({
          'schemaVersion': 2,
          'tripId': id,
          'status': 'completed',
          'authoritative': false,
          'completedAt': at,
          'record': {
            'tripId': id,
            'riderName': 'R',
            'fare': '10 kr',
            'service': 's',
            'pickup': 'p',
            'dropoff': 'd',
          },
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          CompletionJournal.key,
          journal('new', '2026-10-25T00:30:00.000Z'),
        );
        await CompletionJournal(
          active: PrefsActiveRideRepository(),
        ).reconcile();
        await prefs.setString(
          CompletionJournal.key,
          journal('old', '2026-10-01T10:00:00.000'),
        );
        await CompletionJournal(
          active: PrefsActiveRideRepository(),
        ).reconcile();
        final rows = {
          for (final row in await PrefsTripHistoryRepository().list())
            row.tripId: row,
        };
        expect(rows['new']!.completedAt!.isAtSameMomentAs(cest), isTrue);
        expect(rows['new']!.completedAt!.isUtc, isFalse);
        expect(
          rows['new']!.whenLabel,
          '${cest.day}/${cest.month}/${cest.year}, ${clockLabel(cest)}',
        );
        expect(rows['old']!.completedAt, DateTime(2026, 10, 1, 10));
      },
    );

    test('Ride check', () {
      final record = RideCheckRecord(
        id: 'RC-1',
        tripId: 'trip-1',
        trigger: RideCheckTrigger.longStop,
        reason: 'Long stop',
        openedAt: cest,
        answers: [
          RideCheckAnswer(
            question: RideCheckAnswer.first,
            answer: 'OK',
            at: cest,
          ),
        ],
        answeredAt: cest,
      );
      final json = jsonDecode(jsonEncode(record.toJson())) as Map;
      expect(json['openedAt'], '2026-10-25T00:30:00.000Z');
      final back = RideCheckRecord.fromJson(json)!;
      for (final at in [
        back.openedAt,
        back.answeredAt!,
        back.answers.single.at,
      ]) {
        expect(at.isAtSameMomentAs(cest) && !at.isUtc, isTrue);
      }
      // A record saved by an older app (local time, no offset).
      final old = RideCheckRecord.fromJson({
        ...json,
        'openedAt': '2026-10-01T10:00:00.000',
      })!;
      expect(old.openedAt, DateTime(2026, 10, 1, 10));
    });
  });
}
