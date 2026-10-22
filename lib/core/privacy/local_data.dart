import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Class of a local key. This store is recoverable demo state, not secure storage.
enum LocalDataClass {
  /// Needed to restore an in-progress trip until logout or terminal cleanup.
  recovery,

  /// Rider names, addresses, phones, photos, or free text.
  personal,

  /// Non-personal preview preferences.
  preference,
}

class LocalDataRecord {
  const LocalDataRecord({
    required this.key,
    required this.dataClass,
    required this.purpose,
    required this.retention,
  });

  final String key;
  final LocalDataClass dataClass;
  final String purpose;
  final String retention;
}

/// Inventory of Driver keys written through SharedPreferences.
///
/// Web maps these keys into localStorage with a `flutter.` prefix.
const localDataInventory = <LocalDataRecord>[
  LocalDataRecord(
    key: PrefsActiveRideRepository.key,
    dataClass: LocalDataClass.recovery,
    purpose: 'Restore the active trip after a process restart.',
    retention: 'Until the trip ends, or until logout clears local data.',
  ),
  LocalDataRecord(
    key: PrefsActiveRideRepository.terminalKey,
    dataClass: LocalDataClass.recovery,
    purpose: 'Stop a finished trip from coming back after restart.',
    retention: 'Until logout. Not personal free text.',
  ),
  LocalDataRecord(
    key: CompletionJournal.key,
    dataClass: LocalDataClass.recovery,
    purpose: 'Replay a completion that was interrupted locally.',
    retention: 'Until the journal entry is applied, or until logout.',
  ),
  LocalDataRecord(
    key: PrefsTripHistoryRepository.key,
    dataClass: LocalDataClass.personal,
    purpose: 'Local history rows, including rider and address labels.',
    retention: 'Until logout. Not sent to a server.',
  ),
  LocalDataRecord(
    key: PrefsRideCheckLog.key,
    dataClass: LocalDataClass.personal,
    purpose: 'Ride checks for the trip details: time, trigger and answers.',
    retention: 'Newest ${PrefsRideCheckLog.maxRows} checks, until logout. '
        'Audio recordings are separate files on the phone, deleted at '
        'logout too.',
  ),
  LocalDataRecord(
    key: LocalSupportRepository.key,
    dataClass: LocalDataClass.personal,
    purpose: 'Unsent support draft text.',
    retention: 'Until logout.',
  ),
  LocalDataRecord(
    key: SettingsRepository.key,
    dataClass: LocalDataClass.personal,
    purpose: 'Legacy settings blob. May include contacts or vehicle drafts.',
    retention: 'Until logout.',
  ),
  LocalDataRecord(
    key: '${SettingsRepository.sectionPrefix}*',
    dataClass: LocalDataClass.personal,
    purpose:
        'Section settings such as trusted-contact phones and vehicle drafts.',
    retention: 'Until logout.',
  ),
  LocalDataRecord(
    key: DriverStartPosition.key,
    dataClass: LocalDataClass.personal,
    purpose: 'Last known driver position, so the map opens there.',
    retention: 'Overwritten while driving, until logout.',
  ),
  LocalDataRecord(
    key: '${LocalQuarantine.prefix}*',
    dataClass: LocalDataClass.personal,
    purpose: 'Unreadable or conflicting trip/settings records set aside so the driver is not blocked.',
    retention: 'Newest ${LocalQuarantine.maxEntries} entries, until logout.',
  ),
];

/// Removes classified personal and recovery keys.
///
/// Active-trip recovery still works until this runs. After it runs, terminal
/// and active trips cannot resurrect from local storage. Keys outside the
/// Movera inventory are left untouched.
Future<void> clearLocalUserData({
  Future<SharedPreferences> Function()? load,
}) async {
  LocalWriteSession.beginCleanup();
  try {
    await PrefsActiveRideRepository.settle();
    await CompletionJournal.settle();
    await SettingsRepository.settle();
    await PrefsTripHistoryRepository.settle();
    await PrefsRideCheckLog.settle();
    await LocalSupportRepository.settle();
    final prefs = await (load ?? SharedPreferences.getInstance)();
    const exact = <String>[
      PrefsActiveRideRepository.key,
      CompletionJournal.key,
      PrefsTripHistoryRepository.key,
      PrefsRideCheckLog.key,
      LocalSupportRepository.key,
      SettingsRepository.key,
      PrefsActiveRideRepository.terminalKey,
      DriverStartPosition.key,
    ];
    DriverStartPosition.clearMemory();
    for (final key in exact) {
      if (!await prefs.remove(key)) {
        throw StateError('Could not clear local data: $key');
      }
    }
    // driver-r5-18: list from the store, not this instance's cache. On web
    // another tab of the app shares localStorage, and the cache never sees
    // the section or quarantine keys it wrote after this tab loaded.
    await prefs.reload();
    final sectionKeys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith(SettingsRepository.sectionPrefix) ||
              key.startsWith(LocalQuarantine.prefix),
        )
        .toList(growable: false);
    for (final key in sectionKeys) {
      if (!await prefs.remove(key)) {
        throw StateError('Could not clear local data: $key');
      }
    }
    // driver-u31: the Ride check audio files the cleared log pointed at.
    await deleteRideCheckRecordings();
  } catch (_) {
    LocalWriteSession.cancelCleanup();
    rethrow;
  } finally {
    LocalWriteSession.endCleanup();
  }
}
