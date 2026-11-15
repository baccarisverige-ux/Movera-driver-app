import 'package:flutter/foundation.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// G3-D6: the side menu's "NEW" on Promotions shows only while a campaign
/// was not opened yet. The demo's sample campaigns count until the screen is
/// opened once; a live build has no campaign source, so never. Kept apart
/// from the Promotions screen so the menu can ask without loading it (the
/// screen loads on first open, `deferred_screens.dart`).
abstract final class PromotionsBadge {
  static bool get hasUnopened => !LiveDriverServices.active && !_opened;
  static bool _opened = false;

  /// The Promotions screen was opened.
  static void markOpened() => _opened = true;

  /// Tests: the demo's campaigns unopened again.
  @visibleForTesting
  static void resetOpened() => _opened = false;
}
