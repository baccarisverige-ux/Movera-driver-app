import 'package:flutter/foundation.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/settings/settings_repository.dart';

/// Driver group 5, status item 3 (Rules decisions/driver-g5.md, owner
/// 2026-10-29 "Add on setting google map or waze and put the logo"): the
/// app the trip's map button opens. Google Maps by default; Waze when the
/// driver chooses it in Trip settings. App only, no server part
/// (contract v0.18.7 `pickupWaiting.next`).
enum NavigationApp {
  googleMaps('google_maps'),
  waze('waze');

  const NavigationApp(this.storedName);
  final String storedName;

  static NavigationApp parse(Object? value) => switch (value) {
    'waze' => NavigationApp.waze,
    _ => NavigationApp.googleMaps,
  };

  /// Turn-by-turn directions to [latitude], [longitude] in this app
  /// (universal links: the installed app opens, else its web page).
  Uri directionsTo(double latitude, double longitude) => switch (this) {
    NavigationApp.googleMaps => Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude&travelmode=driving',
    ),
    NavigationApp.waze => Uri.parse(
      'https://waze.com/ul?ll=$latitude%2C$longitude&navigate=yes',
    ),
  };
}

/// The chosen navigation app, kept in the driver's local settings
/// (section `trip`, key `navigationApp`) and read by the trip screen.
abstract final class NavigationAppSetting {
  static const section = 'trip';
  static const key = 'navigationApp';

  /// The app in use now; the trip screen's map button follows it.
  static final ValueNotifier<NavigationApp> current = ValueNotifier(
    NavigationApp.googleMaps,
  );

  /// Reads the saved choice into [current] (Google Maps when none).
  static Future<NavigationApp> load([SettingsRepository? repository]) async {
    try {
      final data = await (repository ?? SettingsRepository()).read(section);
      current.value = NavigationApp.parse(data[key]);
    } catch (error) {
      DriverLog.warn('navigation app not read: $error');
    }
    return current.value;
  }

  /// Saves [app] and puts it in use.
  static Future<bool> save(
    NavigationApp app, [
    SettingsRepository? repository,
  ]) async {
    current.value = app;
    try {
      final repo = repository ?? SettingsRepository();
      final data = await repo.read(section);
      await repo.save(section, {...data, key: app.storedName});
      return true;
    } catch (error) {
      DriverLog.warn('navigation app not saved: $error');
      return false;
    }
  }

  @visibleForTesting
  static void reset() => current.value = NavigationApp.googleMaps;
}
