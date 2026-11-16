import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:movera/core/live/live_bonuses.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// G3-D6: the side menu's "NEW" on Promotions shows only while a campaign
/// was not opened yet. The demo's sample campaigns count until the screen is
/// opened once. A live build asks the server (BQ-V44: `isNew` of
/// `GET /driver/bonuses`, see [CampaignsNewBadge]). Kept apart from the
/// Promotions screen so the menu can ask without loading it (the screen
/// loads on first open, `deferred_screens.dart`).
abstract final class PromotionsBadge {
  static bool get hasUnopened {
    final live = LiveDriverServices.instance;
    return live != null ? live.bonuses.hasNew.value : !_opened;
  }

  static bool _opened = false;

  /// The Promotions screen was opened.
  static void markOpened() => _opened = true;

  /// Tests: the demo's campaigns unopened again.
  @visibleForTesting
  static void resetOpened() => _opened = false;
}

/// The side menu's Campaigns row badge (G3-D6): on live, NEW while the
/// server lists an unopened campaign; the list is read again each time
/// the menu is built. The demo keeps its own "opened once" flag.
class CampaignsNewBadge extends StatefulWidget {
  const CampaignsNewBadge({
    super.key,
    required this.bonuses,
    required this.builder,
  });

  final LiveBonuses bonuses;
  final Widget Function(BuildContext context, bool isNew) builder;

  @override
  State<CampaignsNewBadge> createState() => _CampaignsNewBadgeState();
}

class _CampaignsNewBadgeState extends State<CampaignsNewBadge> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.bonuses.refreshBadge());
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.bonuses.hasNew,
    builder: (context, isNew, _) => widget.builder(context, isNew),
  );
}
