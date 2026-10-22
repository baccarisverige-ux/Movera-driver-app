import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:movera/core/l10n/driver_l10n.dart';

/// Owner decision 10 (2026-10-22): "Hide for the moment the audio recording
/// option, only hide the option". The one switch for it. Set it to true to
/// show Record audio again in Ride check and the Safety toolkit.
///
/// Only the entry points are hidden: the recorder, its stores and past
/// recordings in History are untouched, and a recording already running
/// still shows its Stop.
const bool safetyAudioRecordingEnabled = false;

abstract final class SafetyAudioOption {
  /// Tests turn the option on (or off) here; null follows the switch.
  @visibleForTesting
  static bool? debugEnabled;

  /// Whether Record audio is offered.
  static bool get enabled => debugEnabled ?? safetyAudioRecordingEnabled;

  /// The Safety toolkit row's subtitle: it names audio only while offered.
  static String get toolkitSubtitle =>
      enabled ? tr.shareTripRecordAudioGetHelp : tr.shareTripGetHelp;
}
