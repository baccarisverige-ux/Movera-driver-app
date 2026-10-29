/// Contract v0.10.0 §19 (owner Content answers 2026-10-28): the texts the
/// admin's Content page publishes to the driver app, from
/// `GET /driver/content?zoneId`, and the app's rules for them.
library;

/// The places of the driver app (`contract.json#content.apps`).
abstract final class DriverContentSlots {
  static const home = 'driver-home';
  static const event = 'driver-event';
  static const help = 'help';
  static const legal = 'legal';
  static const appVersions = 'app-versions';

  /// v0.17.0 (owner item 8): "How to book your info session".
  static const infoSession = 'driver-info-session';

  static const all = <String>{
    home,
    event,
    help,
    legal,
    appVersions,
    infoSession,
  };
}

/// One `ContentItem`. A broken item is left out ([tryParse] returns null).
class DriverContentItem {
  const DriverContentItem({
    required this.slot,
    required this.version,
    required this.title,
    required this.text,
    this.zoneId = '',
    this.image,
    this.expiresAt,
    this.reaccept = false,
    this.minVersion,
    this.recommendedVersion,
  });

  final String slot;
  final String zoneId;
  final int version;
  final String title;

  /// The text by language: sv, fr and en.
  final Map<String, String> text;

  /// An https image, else null.
  final String? image;
  final DateTime? expiresAt;

  /// legal only: the driver must accept the new terms.
  final bool reaccept;

  /// app-versions only: the driver app's pair.
  final AppVersion? minVersion;
  final AppVersion? recommendedVersion;

  static DriverContentItem? tryParse(Object? json) {
    if (json is! Map) return null;
    final slot = json['slot'];
    final version = json['version'];
    final title = json['title'];
    final rawText = json['text'];
    if (slot is! String || !DriverContentSlots.all.contains(slot)) return null;
    if (version is! int || title is! String || rawText is! Map) return null;
    final text = <String, String>{
      for (final entry in rawText.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: (entry.value as String).trim(),
    };
    final image = json['image'];
    final expires = json['expiresAt'];
    final zone = json['zoneId'];
    AppVersion? min;
    AppVersion? recommended;
    final versions = json['versions'];
    if (versions is Map && versions['driver'] is Map) {
      final driver = versions['driver'] as Map;
      min = AppVersion.tryParse(driver['min']);
      recommended = AppVersion.tryParse(driver['recommended']);
    }
    return DriverContentItem(
      slot: slot,
      zoneId: zone is String ? zone : '',
      version: version,
      title: title.trim(),
      text: text,
      image: image is String && image.startsWith('https://') ? image : null,
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
      reaccept: json['reaccept'] == true,
      minVersion: min,
      recommendedVersion: recommended,
    );
  }

  /// The text in [language]; English, then any text, when it has none.
  String textIn(String language) {
    for (final code in [language, 'en', 'sv', 'fr']) {
      final value = text[code];
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  /// Still shown at [now]: no expiry, or not reached yet.
  bool liveAt(DateTime now) {
    final end = expiresAt;
    return end == null || now.isBefore(end);
  }
}

/// A semantic x.y.z version.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)');

  static AppVersion? tryParse(Object? raw) {
    if (raw is! String) return null;
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(AppVersion other) => compareTo(other) < 0;

  @override
  String toString() => '$major.$minor.$patch';
}

/// The version of this build (pubspec `version`).
abstract final class DriverAppVersion {
  static AppVersion current = const AppVersion(1, 0, 0);

  /// Where "Update the app" sends the driver.
  static const playStore =
      'https://play.google.com/store/apps/details?id=se.movera.driver';
  static const appStore = 'https://apps.apple.com/app/movera-driver';
}

/// What the app versions ask of this build.
enum UpdateNeed {
  none,

  /// Below recommended: a message the driver can close.
  recommended,

  /// Below min: the app is blocked (after the trip, if one is running).
  required,
}

/// What the app shows for the app-versions rule right now.
enum UpdateView {
  none,

  /// A closable message.
  recommendedMessage,

  /// During a trip: only a small message, no block.
  tripMessage,

  /// The full "Update the app" screen.
  blocked,
}

/// The driver app's published content (`ContentList.items`).
class DriverContent {
  const DriverContent(this.items);

  static const empty = DriverContent(<DriverContentItem>[]);

  factory DriverContent.fromJson(Object? json) {
    final raw = json is Map ? json['items'] : null;
    if (raw is! List) return empty;
    return DriverContent([
      for (final row in raw)
        if (DriverContentItem.tryParse(row) case final item?) item,
    ]);
  }

  final List<DriverContentItem> items;

  DriverContentItem? _slot(String slot, DateTime now) {
    DriverContentItem? found;
    for (final item in items) {
      if (item.slot != slot || !item.liveAt(now)) continue;
      if (found == null || item.version > found.version) found = item;
    }
    return found;
  }

  /// Home's admin texts at [now]: driver-home, then driver-event.
  List<DriverContentItem> homeAt(DateTime now) => [
    if (_slot(DriverContentSlots.home, now) case final item?) item,
    if (_slot(DriverContentSlots.event, now) case final item?) item,
  ];

  DriverContentItem? helpAt(DateTime now) =>
      _slot(DriverContentSlots.help, now);

  DriverContentItem? legalAt(DateTime now) =>
      _slot(DriverContentSlots.legal, now);

  DriverContentItem? infoSessionAt(DateTime now) =>
      _slot(DriverContentSlots.infoSession, now);

  /// The legal version the driver must accept, or null when none is due
  /// ([accepted]: the version the driver last accepted).
  int? termsDue(DateTime now, int? accepted) {
    final legal = legalAt(now);
    if (legal == null || !legal.reaccept) return null;
    if (accepted != null && accepted >= legal.version) return null;
    return legal.version;
  }

  UpdateNeed updateNeed(AppVersion app, DateTime now) {
    final item = _slot(DriverContentSlots.appVersions, now);
    if (item == null) return UpdateNeed.none;
    if (item.minVersion case final min? when app < min) {
      return UpdateNeed.required;
    }
    if (item.recommendedVersion case final rec? when app < rec) {
      return UpdateNeed.recommended;
    }
    return UpdateNeed.none;
  }

  /// The view for [need]: during a trip only a small message; the block
  /// starts after the trip ends. [dismissed]: the driver closed the
  /// recommended message.
  static UpdateView viewFor(
    UpdateNeed need, {
    required bool onTrip,
    bool dismissed = false,
  }) {
    switch (need) {
      case UpdateNeed.none:
        return UpdateView.none;
      case UpdateNeed.required:
        return onTrip ? UpdateView.tripMessage : UpdateView.blocked;
      case UpdateNeed.recommended:
        if (dismissed) return UpdateView.none;
        return onTrip ? UpdateView.tripMessage : UpdateView.recommendedMessage;
    }
  }

  List<Map<String, Object?>> toJsonItems() => [
    for (final item in items)
      {
        'slot': item.slot,
        'zoneId': item.zoneId,
        'version': item.version,
        'title': item.title,
        'text': item.text,
        if (item.image != null) 'image': item.image,
        if (item.expiresAt != null)
          'expiresAt': item.expiresAt!.toUtc().toIso8601String(),
        if (item.reaccept) 'reaccept': true,
        if (item.minVersion != null || item.recommendedVersion != null)
          'versions': {
            'driver': {
              'min': item.minVersion?.toString(),
              'recommended': item.recommendedVersion?.toString(),
            },
          },
      },
  ];
}
