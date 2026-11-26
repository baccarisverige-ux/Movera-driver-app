import 'package:movera/core/destination/destination_search.dart';
import 'package:movera/core/history/prefs_trip_history_repository.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/ride/completion_journal.dart';
import 'package:movera/core/ride/prefs_active_ride_repository.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/settings/navigation_app.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/storage/local_quarantine.dart';
import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/core/storage/local_write_session.dart';
import 'package:movera/core/waybill/last_trip_restore.dart';
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
    retention:
        'Newest ${PrefsRideCheckLog.maxRows} checks, until logout. '
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
    retention:
        'Until logout; the device settings (language, navigation app, '
        'sound, accessibility) are kept.',
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
    purpose:
        'Unreadable or conflicting trip/settings records set aside so the driver is not blocked.',
    retention: 'Newest ${LocalQuarantine.maxEntries} entries, until logout.',
  ),
  LocalDataRecord(
    key: RecentDestinations.key,
    dataClass: LocalDataClass.personal,
    purpose:
        'The last ${RecentDestinations.max} destinations of '
        'destination mode (often a home address).',
    retention: 'Until logout.',
  ),
  LocalDataRecord(
    key: localDataOwnerKey,
    dataClass: LocalDataClass.recovery,
    purpose:
        'The driver id the keys above belong to, so another driver who '
        'signs in after a refused session never sees them.',
    retention: 'Until logout.',
  ),
];

/// The driver id (the access token's `sub`) the local data belongs to.
const localDataOwnerKey = 'movera_driver_local_owner';

/// A session of [driver] on this phone. Local data left by another driver
/// (a session the server refused runs no clean-up, so the same driver
/// keeps everything when he signs in again) goes through [clear] first.
/// Without [clear] (a session kept from an earlier start) the driver is
/// only recorded when nobody is. [guard] runs right before the owner is
/// recorded and throws to stop it (N1: a start clean-up a sign-in
/// overtook must never record the old driver).
Future<void> claimLocalData(
  Object? driver, [
  Future<void> Function()? clear,
  void Function()? guard,
]) async {
  if (driver is! String) return;
  final prefs = await SharedPreferences.getInstance();
  final last = prefs.getString(localDataOwnerKey);
  if (last == driver) return;
  if (last != null) {
    if (clear == null) return;
    await clear();
  }
  guard?.call();
  await prefs.setString(localDataOwnerKey, driver);
}

/// The end of a clean-up run with `keepOwner`: everything of the last
/// driver is gone, so nobody owns the local data any more.
Future<void> forgetLocalDataOwner({
  Future<SharedPreferences> Function()? load,
}) async => _removeOwner(await (load ?? SharedPreferences.getInstance)());

Future<void> _removeOwner(SharedPreferences prefs) async {
  if (!await prefs.remove(localDataOwnerKey)) {
    throw StateError('Could not clear local data: $localDataOwnerKey');
  }
}

/// The driver's language choice: a device setting, kept across logout like
/// the rider app's `movera_app_language` (the next driver on this phone most
/// likely speaks it too).
const String languageSectionKey =
    '${SettingsRepository.sectionPrefix}${DriverLanguage.section}';

/// Tester 2026-11-25 ("Google Maps resets to the default"): the phone's own
/// app settings, kept across logout like the language. None holds personal
/// data: the navigation app (Trip settings), Sound & voice, Accessibility
/// (flash, vibration). Before, logout removed them while the screens kept
/// showing the choice from memory, so the next start fell back to the
/// defaults (Google Maps, vibration on).
const Set<String> keptDeviceSettingKeys = <String>{
  languageSectionKey,
  '${SettingsRepository.sectionPrefix}${NavigationAppSetting.section}',
  '${SettingsRepository.sectionPrefix}sound',
  '${SettingsRepository.sectionPrefix}accessibility',
};

/// Removes classified personal and recovery keys.
///
/// Active-trip recovery still works until this runs. After it runs, terminal
/// and active trips cannot resurrect from local storage. Keys outside the
/// Movera inventory are left untouched.
///
/// The owner key ([localDataOwnerKey]) goes last, only after every other
/// step succeeded (post-merge 2026-11-15d S1): a clean-up that stops
/// part-way keeps the last driver recorded, so the next driver's sign-in
/// runs it again. [keepOwner] leaves it for a caller with more to clear
/// (the app's in-memory state), which then calls [forgetLocalDataOwner].
/// [guard] runs before each removal and throws to stop the clean-up (N1:
/// one a sign-in overtook must not delete what the new driver wrote).
Future<void> clearLocalUserData({
  Future<SharedPreferences> Function()? load,
  bool keepOwner = false,
  void Function()? guard,
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
      RecentDestinations.key,
      // Owner 2026-11-26: the island's saved last trip is the driver's.
      LastTripRestore.prefsKey,
    ];
    guard?.call();
    DriverStartPosition.clearMemory();
    for (final key in exact) {
      guard?.call();
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
              (key.startsWith(SettingsRepository.sectionPrefix) &&
                  !keptDeviceSettingKeys.contains(key)) ||
              key.startsWith(LocalQuarantine.prefix),
        )
        .toList(growable: false);
    for (final key in sectionKeys) {
      guard?.call();
      if (!await prefs.remove(key)) {
        throw StateError('Could not clear local data: $key');
      }
    }
    // driver-u31: the Ride check audio files the cleared log pointed at.
    guard?.call();
    await deleteRideCheckRecordings();
    guard?.call();
    if (!keepOwner) await _removeOwner(prefs);
  } catch (_) {
    LocalWriteSession.cancelCleanup();
    rethrow;
  } finally {
    LocalWriteSession.endCleanup();
  }
}
