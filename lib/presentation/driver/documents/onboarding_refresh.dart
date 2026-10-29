import 'dart:async';

import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';

/// The admin's onboarding settings of the driver's country (contract
/// v0.17.0), read into [OnboardingSettingsStore.instance].
Future<OnboardingSettings> refreshOnboardingSettings(
  DriverAccountSession session,
) => OnboardingSettingsStore.instance.refresh(
  () => session.repository.onboardingSettings(),
);

/// The Home sheet's reminders, read into [DriverRemindersStore.instance];
/// quiet on failure (the last list stays).
Future<void> refreshReminders(DriverAccountSession session) async {
  try {
    await DriverRemindersStore.instance.refresh(
      () => session.repository.reminders(),
    );
  } catch (_) {
    // Offline or a server fault: the sheet keeps what it showed.
  }
}
