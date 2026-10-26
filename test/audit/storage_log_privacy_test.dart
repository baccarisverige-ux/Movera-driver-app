import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:shared_preferences/shared_preferences.dart';

// driver-25: a corrupt local record must not put rider names, addresses or
// phone numbers into DriverLog. Dart's FormatException.toString() quotes
// the text around the error, so logging it as is copies the record.

const _name = 'Anna Svensson';
const _pickup = 'Sveavagen 12, Stockholm';
const _dropoff = 'Kungsgatan 4, Stockholm';
const _phone = '+46709998877';

/// A JSON record cut off after the private fields, as a half-written save.
String _truncated(String head) =>
    '{$head"riderName":"$_name","pickupAddress":"$_pickup",'
    '"dropoffAddress":"$_dropoff","riderPhone":"$_phone","note":"unterminated';

List<String> _capture() {
  final lines = <String>[];
  final previous = DriverLog.sink;
  DriverLog.sink = (record) =>
      lines.add('${record.message} ${record.error ?? ''}');
  addTearDown(() => DriverLog.sink = previous);
  return lines;
}

void _expectClean(List<String> lines) {
  expect(lines, isNotEmpty, reason: 'the corrupt record is still reported');
  for (final line in lines) {
    for (final secret in [
      'Svensson',
      'Sveavagen',
      'Kungsgatan',
      _phone,
      'unterminated',
    ]) {
      expect(line, isNot(contains(secret)), reason: line);
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CompletionJournal.resetForTesting();
  });

  test(
    'driver-25 corrupt active-trip snapshot is logged without its text',
    () async {
      final lines = _capture();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PrefsActiveRideRepository.key,
        _truncated('"tripId":"T-1","stage":"onTrip",'),
      );
      final repo = PrefsActiveRideRepository();
      await expectLater(repo.read(), throwsA(anything));
      await PrefsActiveRideRepository.settle();
      await repo.quarantineUnreadable();
      expect(LocalQuarantine.keys(prefs), hasLength(1));
      _expectClean(lines);
    },
  );

  test(
    'driver-25 corrupt settings section is logged without its text',
    () async {
      final lines = _capture();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${SettingsRepository.sectionPrefix}contacts',
        _truncated('"schemaVersion":1,"values":{'),
      );
      expect(await SettingsRepository().read('contacts'), isEmpty);
      expect(LocalQuarantine.keys(prefs), hasLength(1));
      _expectClean(lines);
    },
  );

  test(
    'driver-25 corrupt completion journal is logged without its text',
    () async {
      final lines = _capture();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        CompletionJournal.key,
        _truncated('"schemaVersion":2,"tripId":"T-1",'),
      );
      expect(
        await CompletionJournal(
          active: PrefsActiveRideRepository(),
        ).reconcile(),
        JournalReplayOutcome.quarantinedCorrupt,
      );
      _expectClean(lines);
    },
  );

  test(
    'driver-25 corrupt history and Ride check log are logged without text',
    () async {
      final lines = _capture();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        PrefsTripHistoryRepository.key,
        _truncated('"schemaVersion":1,"rows":[{'),
      );
      await prefs.setString(
        PrefsRideCheckLog.key,
        _truncated('"schemaVersion":1,"rows":[{'),
      );
      expect(await PrefsTripHistoryRepository().list(), isEmpty);
      expect(await PrefsRideCheckLog().forTrip('T-1'), isEmpty);
      _expectClean(lines);
    },
  );
}
