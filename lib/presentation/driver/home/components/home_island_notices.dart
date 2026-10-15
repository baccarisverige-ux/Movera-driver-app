import 'package:flutter/material.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';

/// What the island says, in one place. Kept to the essential words so the
/// island stays about its normal size: same or a little longer.
class HomeIslandNotices {
  const HomeIslandNotices._();

  static const IslandMessage online = IslandMessage(
    title: 'Radar online',
    tone: IslandTone.success,
    priority: IslandPriority.low,
    live: true,
    group: 'online',
  );

  static const IslandMessage offline = IslandMessage(
    title: 'Radar offline',
    priority: IslandPriority.low,
    group: 'online',
  );

  static const IslandMessage riderCancelled = IslandMessage(
    title: 'Rider cancelled',
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static const IslandMessage riderEndedTrip = IslandMessage(
    title: 'Rider ended trip',
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static const IslandMessage matching = IslandMessage(
    title: 'Matching…',
    priority: IslandPriority.low,
    group: 'radar-match',
  );

  static const IslandMessage matched = IslandMessage(
    title: 'Trip matched',
    tone: IslandTone.success,
    priority: IslandPriority.low,
    group: 'radar-match',
  );

  static const IslandMessage takenByOther = IslandMessage(
    title: 'Taken by another driver',
    tone: IslandTone.warning,
    group: 'radar-match',
  );

  static const IslandMessage tripUnavailable = IslandMessage(
    title: 'Trip unavailable',
    tone: IslandTone.warning,
    group: 'radar-match',
  );

  static const IslandMessage noConnection = IslandMessage(
    title: 'No connection',
    tone: IslandTone.warning,
    group: 'radar-match',
  );

  static const IslandMessage accountOnHold = IslandMessage(
    title: 'Contact support',
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static const IslandMessage newReservation = IslandMessage(
    title: 'New reservation',
    group: 'reservation',
  );

  /// An Exclusive offer arrives on Home: info blue, with a bolt.
  static const IslandMessage exclusiveRide = IslandMessage(
    title: 'Exclusive ride',
    icon: Icons.bolt_rounded,
    group: 'exclusive',
  );

  /// The Exclusive offer is a reservation close to pickup.
  static const IslandMessage exclusiveReservation = IslandMessage(
    title: 'Exclusive reservation',
    icon: Icons.bolt_rounded,
    group: 'exclusive',
  );

  static const IslandMessage reservationAccepted = IslandMessage(
    title: 'Reservation accepted',
    tone: IslandTone.success,
    group: 'reservation',
  );

  /// The driver tapped Accept on the radar; the server picks one driver.
  static const IslandMessage reservationMatching = IslandMessage(
    title: 'Matching…',
    priority: IslandPriority.low,
    group: 'reservation',
  );

  /// This driver's claim lost (R25): another driver was first, or was
  /// picked at the same moment; or it was cancelled or expired.
  static const IslandMessage reservationUnavailable = IslandMessage(
    title: 'No longer available',
    tone: IslandTone.warning,
    group: 'reservation',
  );

  static const IslandMessage reservationNoConnection = IslandMessage(
    title: 'No connection',
    tone: IslandTone.warning,
    group: 'reservation',
  );

  static const IslandMessage recoveryPending = IslandMessage(
    title: 'Saved trip open',
    tone: IslandTone.warning,
    priority: IslandPriority.high,
  );

  static const IslandMessage newerTripKept = IslandMessage(
    title: 'Newer trip kept',
    tone: IslandTone.warning,
    priority: IslandPriority.high,
  );

  static const IslandMessage recordSetAside = IslandMessage(
    title: 'Trip record set aside',
    tone: IslandTone.warning,
  );

  static const IslandMessage recoveryFailed = IslandMessage(
    title: 'Recovery failed',
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static const IslandMessage savedTripNotClosed = IslandMessage(
    title: 'Trip not closed',
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  static const IslandMessage unreadableTripOpen = IslandMessage(
    title: 'Close saved trip',
    tone: IslandTone.warning,
    priority: IslandPriority.high,
  );

  static const IslandMessage unreadableTripNotClosed = IslandMessage(
    title: 'Trip not closed',
    tone: IslandTone.alert,
    priority: IslandPriority.high,
  );

  /// First launch only. The one message whose tap does more than close
  /// it: it shows the earnings, as its words say.
  static IslandMessage earningsHint(VoidCallback show) => IslandMessage(
        title: 'Tap to see earnings',
        priority: IslandPriority.high,
        onTap: show,
      );
}
