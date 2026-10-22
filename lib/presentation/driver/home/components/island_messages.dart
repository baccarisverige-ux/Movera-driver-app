import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show IconData;

/// Colour and icon of a message on the top island.
enum IslandTone { info, success, warning, alert }

/// How long a message stays on the island.
enum IslandPriority {
  /// Quick confirmations: online, offline, matching.
  low(Duration(seconds: 2)),

  /// Things the driver should notice: a trip gone, a new reservation.
  normal(Duration(seconds: 3)),

  /// Things that change the driver's situation: a rider cancelled, a
  /// trip that needs attention.
  high(Duration(milliseconds: 4500));

  const IslandPriority(this.duration);

  final Duration duration;
}

/// One message for the driver, shown on the Home island's screen.
@immutable
class IslandMessage {
  const IslandMessage({
    required this.title,
    this.tone = IslandTone.info,
    this.priority = IslandPriority.normal,
    this.onTap,
    this.live = false,
    this.group,
    this.icon,
  });

  /// A few essential words, e.g. "Rider cancelled" or "Radar online".
  final String title;
  final IslandTone tone;
  final IslandPriority priority;

  /// Tapping the island while the message shows, e.g. to retry.
  final VoidCallback? onTap;

  /// A breathing dot instead of an icon, for live states like "online".
  final bool live;

  /// Messages of one group replace each other at once: "Matching trip"
  /// gives way to "Trip matched" without waiting out its time.
  final String? group;

  /// Drawn instead of the tone's own icon, in the tone's colour, e.g. a
  /// bolt for "Exclusive ride".
  final IconData? icon;
}

/// Messages waiting for the Home island. Any screen can post one; the
/// island shows them one after another, each for its priority's time.
/// Important messages go ahead of quick ones still waiting.
class IslandMessages {
  IslandMessages._();

  static final ValueNotifier<int> _changes = ValueNotifier<int>(0);
  static final List<IslandMessage> _queue = <IslandMessage>[];

  /// Notifies when a message is posted.
  static ValueListenable<int> get changes => _changes;

  static bool get hasPending => _queue.isNotEmpty;

  /// The newest messages posted since the last [reset] (at most
  /// [maxPosted]), oldest first.
  @visibleForTesting
  static final List<IslandMessage> posted = <IslandMessage>[];

  /// driver-63: a long shift posts many messages, each often holding a
  /// closure over Home; only the newest are kept for tests to read.
  static const int maxPosted = 100;

  static void show(IslandMessage message) {
    posted.add(message);
    if (posted.length > maxPosted) {
      posted.removeRange(0, posted.length - maxPosted);
    }
    if (message.priority == IslandPriority.high) {
      final at = _queue.indexWhere(
        (queued) => queued.priority != IslandPriority.high,
      );
      _queue.insert(at < 0 ? _queue.length : at, message);
    } else {
      _queue.add(message);
    }
    _changes.value++;
  }

  /// Next message to show, still in the queue.
  static IslandMessage? peek() => _queue.isEmpty ? null : _queue.first;

  /// Next message to show, removed from the queue.
  static IslandMessage? take() => _queue.isEmpty ? null : _queue.removeAt(0);

  /// Drops every waiting message (logout, driver-r5-27): each may hold a
  /// closure over the departing driver's Home, and the next driver must
  /// not see the previous one's notices.
  static void clear() {
    _queue.clear();
    posted.clear();
  }

  @visibleForTesting
  static void reset() => clear();
}
