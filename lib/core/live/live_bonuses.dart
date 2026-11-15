import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/money/money.dart';

/// BQ-V44 (contract v0.18.103 `bonusCampaigns`, Rules
/// audits/impact/v44-driver-bonuses.md §8): the driver's bonus campaigns
/// as the server keeps them. `GET /driver/bonuses` gives the campaigns of
/// his zones with his progress; `POST /driver/bonuses/opened` tells the
/// server he saw them (the NEW badge is kept on the server, D12).
///
/// Every number is the server's: the app never works progress or money
/// out (owner R8, s06:1275-1276).
class LiveBonuses {
  LiveBonuses({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const path = '/api/v1/driver/bonuses';
  static const openedPath = '/api/v1/driver/bonuses/opened';

  /// Contract `DriverBonusOpened.bonusIds` maxItems.
  static const openedBatch = 50;

  /// True while the last list read had an item with `isNew` (G3-D6: the
  /// side menu's NEW badge).
  final ValueNotifier<bool> hasNew = ValueNotifier<bool>(false);

  /// The campaigns, in the server's order. Throws when the server could
  /// not answer; an item that cannot be read is left out.
  Future<List<DriverBonus>> list() async {
    final page = await _api.get(path);
    final items = page['items'];
    final bonuses = [
      if (items is List)
        for (final item in items)
          if (item is Map)
            ?DriverBonus.tryParse(Map<String, dynamic>.from(item)),
    ];
    hasNew.value = bonuses.any((b) => b.isNew);
    return bonuses;
  }

  /// Reads the list again for the badge only; a failure keeps the badge.
  Future<void> refreshBadge() async {
    try {
      await list();
    } catch (error) {
      DriverLog.warn('bonuses not read: $error', name: 'live');
    }
  }

  /// `POST /driver/bonuses/opened` for [bonusIds] (in batches of 50).
  /// The badge goes off once the server took them; a failure keeps it,
  /// so the next opening sends them again.
  Future<void> opened(Iterable<String> bonusIds) async {
    final ids = bonusIds.toSet().toList();
    if (ids.isEmpty) return;
    try {
      for (var i = 0; i < ids.length; i += openedBatch) {
        final end = i + openedBatch < ids.length ? i + openedBatch : ids.length;
        await _api.post(openedPath, body: {'bonusIds': ids.sublist(i, end)});
      }
      hasNew.value = false;
    } catch (error) {
      DriverLog.warn('bonuses opened not sent: $error', name: 'live');
    }
  }
}

/// Contract `BonusMeasure`.
enum BonusMeasure { trips, onlineHours }

/// Contract `BonusState`.
enum BonusState { scheduled, active, paused, ended }

/// One `DriverBonus` (contract v0.18.103), the driver's view.
class DriverBonus {
  const DriverBonus({
    required this.bonusId,
    required this.names,
    required this.measure,
    required this.state,
    required this.startDate,
    required this.endDate,
    required this.amount,
    required this.done,
    required this.target,
    required this.earned,
    required this.isNew,
  });

  final String bonusId;

  /// `names` { sv, fr, en }.
  final Map<String, String> names;
  final BonusMeasure measure;
  final BonusState state;

  /// Local dates of the zone (`YYYY-MM-DD`), held as dates without a time
  /// zone: shown as they are, never moved to the phone's time zone.
  final DateTime startDate;
  final DateTime endDate;

  /// The server's amount, in the zone's currency.
  final Money amount;

  /// `progress.done` / `progress.target`: trips, or whole MINUTES for
  /// [BonusMeasure.onlineHours] (target = hours × 60).
  final int done;
  final int target;
  final bool earned;
  final bool isNew;

  /// The name in [language]; English, then any, when that one is empty.
  String nameIn(String language) {
    final name = names[language];
    if (name != null && name.trim().isNotEmpty) return name;
    final en = names['en'];
    if (en != null && en.trim().isNotEmpty) return en;
    return names.values.firstWhere(
      (n) => n.trim().isNotEmpty,
      orElse: () => '',
    );
  }

  static final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime? _localDate(Object? value) {
    final match = value is String ? _date.firstMatch(value) : null;
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Null when a required field is missing or wrong (never a half card).
  static DriverBonus? tryParse(Map<String, dynamic> json) {
    final id = json['bonusId'];
    final names = json['names'];
    final measure = switch (json['measure']) {
      'trips' => BonusMeasure.trips,
      'online_hours' => BonusMeasure.onlineHours,
      _ => null,
    };
    final state = switch (json['state']) {
      'scheduled' => BonusState.scheduled,
      'active' => BonusState.active,
      'paused' => BonusState.paused,
      'ended' => BonusState.ended,
      _ => null,
    };
    final start = _localDate(json['startDate']);
    final end = _localDate(json['endDate']);
    final amount = json['amount'];
    final progress = json['progress'];
    if (id is! String ||
        names is! Map ||
        measure == null ||
        state == null ||
        start == null ||
        end == null ||
        amount is! Map ||
        progress is! Map) {
      return null;
    }
    final done = progress['done'];
    final target = progress['target'];
    if (done is! int || target is! int || done < 0 || target < 1) return null;
    try {
      return DriverBonus(
        bonusId: id,
        names: {
          for (final entry in names.entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
        },
        measure: measure,
        state: state,
        startDate: start,
        endDate: end,
        amount: Money.fromJson(Map<String, dynamic>.from(amount)),
        done: done,
        target: target,
        earned: json['earned'] == true,
        isNew: json['isNew'] == true,
      );
    } on FormatException {
      return null;
    }
  }
}
