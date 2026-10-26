import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/waybill/waybill.dart';

void main() {
  test(
    'malformed rows and duplicate IDs do not block history or completion',
    () async {
      final rows = <dynamic>[
        {'tripId': 42},
        null,
        for (var i = 0; i < 600; i++)
          {
            'tripId': 'trip-$i',
            'riderName': 'Sample',
            'whenLabel': 'Today',
            'pickup': 'P',
            'dropoff': 'D',
            'fare': '1',
            'category': 'Demo',
            'completedAt': DateTime(
              2026,
              1,
              1,
            ).add(Duration(minutes: i)).toIso8601String(),
          },
      ];
      rows.add(rows.last);
      SharedPreferences.setMockInitialValues({
        PrefsTripHistoryRepository.key: jsonEncode(rows),
      });
      final repo = PrefsTripHistoryRepository();
      expect((await repo.list()).length, 500);
      await repo.archive(
        WaybillRecord(
          tripId: 'new',
          statusLabel: 'Completed',
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
      );
      expect((await repo.list()).first.tripId, 'new');
      expect((await repo.list()).length, 500);
    },
  );
  test('malformed JSON is isolated', () async {
    SharedPreferences.setMockInitialValues({
      PrefsTripHistoryRepository.key: '{broken',
    });
    expect(await PrefsTripHistoryRepository().list(), isEmpty);
  });
}
