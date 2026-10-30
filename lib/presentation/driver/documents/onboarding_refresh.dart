import 'dart:async';

import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';

/// R6 (owner 2026-10-30, "Update + notice (Recommended)"): an open Home
/// or Documents screen reads the documents and reminders again this
/// often, besides when it comes back on top or the app returns.
const Duration onboardingRefreshEvery = Duration(seconds: 60);

/// The admin's onboarding settings of the driver's country (contract
/// v0.17.0), read into [OnboardingSettingsStore.instance].
Future<OnboardingSettings> refreshOnboardingSettings(
  DriverAccountSession session,
) {
  final store = OnboardingSettingsStore.instance;
  store.country = session.account?.country ?? store.country;
  return store.refresh(() => session.repository.onboardingSettings());
}

/// The Home sheet's reminders, read into [DriverRemindersStore.instance];
/// quiet on failure (the last list stays).
Future<void> refreshReminders(DriverAccountSession session) async {
  try {
    await DriverRemindersStore.instance.refresh(() async {
      final list = await session.repository.reminders();
      final me = session.account;
      return list.forViewer(
        owner: me == null || me.isFleetAccount || (me.fleet?.isOwner ?? false),
      );
    });
  } catch (_) {
    // Offline or a server fault: the sheet keeps what it showed.
  }
}
