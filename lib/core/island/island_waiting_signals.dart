import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';

/// How a short waiting message looks on the island: the colour of its dot.
enum IslandTipLook { boost, demand, info, promotion, good }

/// One short message the island can show while the driver waits for a
/// trip, e.g. tr.tipBusyArea. Built into the app: the
/// words are chosen here, only the facts come from the app's data.
@immutable
class IslandWaitingTip {
  const IslandWaitingTip(this.id, this.title, this.look);

  /// Kind of message, so the same kind never shows twice in a row.
  final String id;
  final String title;
  final IslandTipLook look;
}

/// The facts the waiting messages are made from. Every field is optional:
/// a message only exists when its fact does, so the island never makes
/// something up. No negative or "quiet" messages.
@immutable
class IslandWaitingSignals {
  const IslandWaitingSignals({
    this.boostKr,
    this.boostZone,
    this.busyArea = false,
    this.demandRising = false,
    this.expectTripSoon = false,
    this.airportQueue,
    this.peakStart,
    this.streak = 0,
    this.topZone = false,
    this.promotionRides,
    this.promotionKr,
  });

  /// A fare boost nearby, in kr, and its zone when known.
  final int? boostKr;
  final String? boostZone;

  /// An area with high demand: trips are expected soon.
  final bool busyArea;
  final bool demandRising;

  /// Demand is high enough that a trip usually comes within 2–5 min.
  final bool expectTripSoon;

  /// Drivers waiting in the airport queue.
  final int? airportQueue;

  /// When the next busy window starts, "16:00".
  final String? peakStart;

  /// Trips accepted in a row.
  final int streak;

  /// The driver is in one of the busiest zones right now.
  final bool topZone;

  /// A promotion in the driver's zone: [promotionRides] rides pay
  /// [promotionKr] kr.
  final int? promotionRides;
  final int? promotionKr;

  /// What Home knows today: the busy windows of today's events. Boosts,
  /// promotions, the airport queue and streaks come from dispatch once it
  /// sends them.
  ///
  /// driver-u20: the admin's Stockholm demand per area says nothing about
  /// the area the driver is in (areas have no position) and is a level,
  /// not a trend, so it never makes "Busy area", "Expect a trip in 2–5
  /// min" or "Demand rising" here; those come from dispatch for the
  /// driver's own area once it sends them.
  factory IslandWaitingSignals.fromHome(
    DriverHomeAdminConfig config, {
    required DateTime now,
    int streak = 0,
  }) {
    String? peak;
    for (final event in config.events) {
      if (!event.enabled || !_isToday(event.dateLabel, now)) {
        continue;
      }
      final start = _start(event.timeLabel);
      if (start != null && _minutes(start) > now.hour * 60 + now.minute) {
        peak = start;
        break;
      }
    }
    return IslandWaitingSignals(peakStart: peak, streak: streak);
  }

  /// The demo: every kind of message has its fact, so all of them show.
  factory IslandWaitingSignals.demo(DriverHomeAdminConfig config) {
    final inner = config.stockholmWork.innerAreas;
    String? zone;
    var top = 0;
    for (final area in inner) {
      if (area.demandPercent > top) {
        top = area.demandPercent;
        zone = area.name;
      }
    }
    final events = config.events.where((e) => e.enabled);
    return IslandWaitingSignals(
      boostKr: 25,
      boostZone: zone,
      busyArea: true,
      demandRising: true,
      expectTripSoon: true,
      airportQueue: 4,
      peakStart: events.isEmpty ? null : _start(events.first.timeLabel),
      streak: 3,
      topZone: true,
      promotionRides: 3,
      promotionKr: 159,
    );
  }

  /// The messages these facts allow, in the order they rotate.
  List<IslandWaitingTip> tips() => [
    if (boostKr case final kr?)
      IslandWaitingTip(
        'boost',
        boostZone == null
            ? tr.tipHighBoostNearby
            : tr.tipHighBoostIn('$kr', boostZone!),
        IslandTipLook.boost,
      ),
    if (expectTripSoon)
      IslandWaitingTip('expect', tr.tipExpectTrip, IslandTipLook.info),
    if (promotionRides case final rides?)
      if (promotionKr case final kr?)
        IslandWaitingTip(
          'promotion',
          tr.tipPromotionRides('$rides', '$kr'),
          IslandTipLook.promotion,
        ),
    if (busyArea)
      IslandWaitingTip('busy', tr.tipBusyArea, IslandTipLook.demand),
    if (airportQueue case final queue?)
      IslandWaitingTip(
        'airport',
        tr.tipAirportQueue('$queue'),
        IslandTipLook.info,
      ),
    if (streak >= 2)
      IslandWaitingTip(
        'streak',
        tr.tipGoodStreak('$streak'),
        IslandTipLook.good,
      ),
    if (demandRising)
      IslandWaitingTip('demand', tr.tipDemandRising, IslandTipLook.demand),
    if (peakStart case final start?)
      IslandWaitingTip('peak', tr.tipPeakStart(start), IslandTipLook.info),
    if (topZone)
      IslandWaitingTip('top-zone', tr.tipTopZone, IslandTipLook.good),
  ];

  static const List<String> _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// "Fri 25 Sep" is today.
  static bool _isToday(String label, DateTime now) {
    final parts = label.trim().toLowerCase().split(RegExp(r'\s+'));
    if (parts.length < 3 || parts[2].length < 3) {
      return false;
    }
    final day = int.tryParse(parts[1]);
    final month = _months.indexOf(parts[2].substring(0, 3)) + 1;
    return day == now.day && month == now.month;
  }

  /// "18:00–22:30" → "18:00".
  static String? _start(String label) => RegExp(
    r'\b(\d{1,2}):(\d{2})',
  ).firstMatch(label)?.group(0)?.padLeft(5, '0');

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
