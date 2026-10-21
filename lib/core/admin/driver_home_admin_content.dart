import 'package:movera/core/admin/trip_rules_admin_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';
import 'package:movera/core/scheduled/scheduled_ride_rules.dart';

class DriverHomeAdminConfig {
  const DriverHomeAdminConfig({
    required this.performance,
    required this.scheduledRides,
    required this.update,
    required this.eventsSectionTitle,
    required this.eventsSectionSubtitle,
    required this.events,
    required this.stockholmWork,
    this.appTexts = const DriverAppTextOverrides(),
    this.destinationMode,
    this.nextTrips,
  });

  final DriverPerformanceConfig performance;
  final ScheduledRidesAdminConfig scheduledRides;
  final AppUpdateAdminConfig update;
  final String eventsSectionTitle;
  final String eventsSectionSubtitle;
  final List<DriverEventConfig> events;
  final StockholmWorkStatsConfig stockholmWork;

  /// Content › Driver app texts (Q30): admin's texts per language. The
  /// demo has none, so the app shows its defaults.
  final DriverAppTextOverrides appTexts;

  /// R13-9 / R13-18: the zone's Destination mode and next-trip rules from
  /// admin's rules file; null when none was sent (the app keeps its
  /// defaults).
  final DestinationModeRules? destinationMode;
  final NextTripRules? nextTrips;
}

class DriverPerformanceConfig {
  const DriverPerformanceConfig({
    required this.rating,
    required this.acceptanceRate,
    required this.cancellationRate,
    this.showRating = true,
    this.showAcceptanceRate = true,
    this.showCancellationRate = true,
  });

  /// The demo's sample numbers. Home, the side menu and Analytics all read
  /// these, so the same metric never shows two values (UI-10).
  static const DriverPerformanceConfig sample = DriverPerformanceConfig(
    rating: 4.88,
    acceptanceRate: 94.0,
    cancellationRate: 2.4,
  );

  final double rating;
  final double acceptanceRate;
  final double cancellationRate;
  final bool showRating;
  final bool showAcceptanceRate;
  final bool showCancellationRate;

  /// "4.88"
  String get ratingLabel => rating.toStringAsFixed(2);

  /// "94%"
  String get acceptanceLabel => '${acceptanceRate.toStringAsFixed(0)}%';

  /// "2.4%"
  String get cancellationLabel => '${cancellationRate.toStringAsFixed(1)}%';
}

class ScheduledRidesAdminConfig {
  const ScheduledRidesAdminConfig({
    required this.enabled,
    required this.hasOpenRequests,
    required this.title,
    required this.subtitle,
    this.newRequest,
    this.newRequests = const <ReservationRequestPreview>[],
    this.driverAccess = const ScheduledRidesDriverAccess(),
  });

  final bool enabled;
  final bool hasOpenRequests;
  final String title;
  final String subtitle;

  /// Newest reservation request, shown as a Home popup when present.
  final ReservationRequestPreview? newRequest;

  /// Every request sent to the Home popup, shown one at a time; empty
  /// means just [newRequest].
  final List<ReservationRequestPreview> newRequests;

  /// The Home popup's requests, in order.
  List<ReservationRequestPreview> get homeRequests => newRequests.isNotEmpty
      ? newRequests
      : [if (newRequest case final request?) request];

  /// Admin's on/off for this driver (Admin › Drivers).
  final ScheduledRidesDriverAccess driverAccess;
}

/// Scheduled rides on or off for one driver, set by admin on the driver's
/// page (also in Reservations and Dispatch).
class ScheduledRidesDriverAccess {
  const ScheduledRidesDriverAccess({this.enabled = true, this.offUntil});

  final bool enabled;

  /// When admin turned them off: back on at this time; null means until
  /// admin turns them on again.
  final DateTime? offUntil;

  /// Off right now, at [now].
  bool offAt(DateTime now) {
    final until = offUntil;
    return !enabled && (until == null || now.isBefore(until));
  }
}

class ReservationRequestPreview {
  const ReservationRequestPreview({
    required this.category,
    required this.fare,
    required this.pickupLabel,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupTime,
    required this.pickupDay,
    required this.tripMinutes,
    required this.tripKm,
    required this.pickup,
    required this.dropoff,
    this.stops = const <ReservationStop>[],
    this.id = '',
    this.paidByCash = false,
    this.cashToCollect,
    this.rating = '',
    this.riderName = '',
    this.riderTrips = 0,
    this.fareBoost,
    this.kind,
    this.scheduledAt,
  });

  /// Dispatch id; claiming it decides which driver gets the reservation.
  /// Empty for sample rides that are not open to take.
  final String id;

  /// The rider pays cash in the car (not in the app).
  final bool paidByCash;

  /// R8-4: on a cash ride, the cash to take from the rider when it is not
  /// [fare] (rider promotions), e.g. "300,00 kr". Null: the fare.
  final String? cashToCollect;

  /// The rider's rating, e.g. "4.94"; empty when not known.
  final String rating;

  /// The rider's first name and trip count; empty / 0 when not known.
  final String riderName;
  final int riderTrips;

  /// Admin raised the fare because no driver was near the pickup, e.g.
  /// "+40 kr" (paid from Movera's commission). [fare] already includes it.
  final String? fareBoost;

  /// Set when admin gave the ride a kind; otherwise it follows from the
  /// ride (see `SmartGap.kindOf`).
  final ScheduledRideKind? kind;

  final String category;
  final String fare;
  final String pickupLabel;
  final String pickupAddress;
  final String dropoffAddress;

  /// When the rider is picked up, e.g. "07:40" on "Today".
  final String pickupTime;
  final String pickupDay;

  /// The pickup as a date and time (contract `scheduledAt`), fixed when
  /// the ride was booked. [pickupDay]'s "Today"/"Tomorrow" are relative to
  /// that moment, so after midnight only this still says which day it is
  /// (driver-u141). Null: [pickupDay] is read against the time asked.
  final DateTime? scheduledAt;

  /// The whole ride, pickup to drop-off.
  final int tripMinutes;
  final double tripKm;

  final GeoPoint pickup;
  final GeoPoint dropoff;

  /// Stops between pickup and drop-off, in driving order.
  final List<ReservationStop> stops;

  /// Expected drop-off time: [pickupTime] plus [tripMinutes], e.g. "07:59".
  /// Falls back to [pickupTime] if it is not "HH:mm".
  String get arrivalTime => estimatedArrival ?? pickupTime;

  /// Expected drop-off time, or null when [pickupTime] is not "HH:mm" or
  /// the ride time is unknown.
  String? get estimatedArrival {
    final pickupMinute = minuteOfDay;
    if (pickupMinute == null || tripMinutes < 0) {
      return null;
    }
    final total = (pickupMinute + tripMinutes) % (24 * 60);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(total ~/ 60)}:${two(total % 60)}';
  }

  /// [pickupTime] as minutes after midnight, or null if it is not "HH:mm".
  int? get minuteOfDay {
    final parts = pickupTime.split(':');
    final h = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final m = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  /// Time left until pickup at [now], or null when the pickup day is not
  /// "Today" / "Tomorrow", the time is not "HH:mm" or it has passed.
  Duration? untilPickup(DateTime now) {
    final at = pickupAt(now);
    if (at == null) {
      return null;
    }
    final left = at.difference(now);
    return left.isNegative ? null : left;
  }

  /// When the rider is picked up, seen from [now]; null when the pickup
  /// day is not "Today" / "Tomorrow" or the time is not "HH:mm". A ride
  /// with [scheduledAt] is picked up then, whatever [now] is.
  DateTime? pickupAt(DateTime now) {
    if (scheduledAt case final at?) { return at; }
    final minute = minuteOfDay;
    final day = pickupDay.trim().toLowerCase();
    final offset = day == 'today' ? 0 : day == 'tomorrow' ? 1 : null;
    if (minute == null || offset == null) {
      return null;
    }
    return DateTime(now.year, now.month, now.day + offset)
        .add(Duration(minutes: minute));
  }

  /// This ride, picked up at [at].
  ReservationRequestPreview scheduledFor(DateTime at) =>
      ReservationRequestPreview(
        category: category,
        fare: fare,
        pickupLabel: pickupLabel,
        pickupAddress: pickupAddress,
        dropoffAddress: dropoffAddress,
        pickupTime: pickupTime,
        pickupDay: pickupDay,
        tripMinutes: tripMinutes,
        tripKm: tripKm,
        pickup: pickup,
        dropoff: dropoff,
        stops: stops,
        id: id,
        paidByCash: paidByCash,
        cashToCollect: cashToCollect,
        rating: rating,
        riderName: riderName,
        riderTrips: riderTrips,
        fareBoost: fareBoost,
        kind: kind,
        scheduledAt: at,
      );
}

/// Where an untaken reservation shows, step by step (notes R21–R25). The
/// minutes come from [ScheduledRideRules] (admin Dispatch › Reservations);
/// the demo runs on `ScheduledClock.instance` (the real clock).
///
/// 1. L1: it is listed in every driver's Scheduled rides.
/// 2. L2: untaken after [homePopupAfter], it also shows as the Home popup
///    to drivers who are online; it stays listed.
/// 3. L3: [ScheduledRideRules.exclusiveBeforeMinutes] before its pickup
///    time it becomes an Exclusive offer, and
///    [ScheduledRideRules.radarBeforeMinutes] before it joins the Radar
///    trips, where it only says "Reservation".
/// 4. Taken by a driver it leaves every place; the server gives it to the
///    first claim (R25).
/// 5. The driver who took it cancels: it goes back where the admin rule
///    "After a driver cancels" says, Radar trips too when it is close to
///    pickup.
class ReservationDemoTimings {
  const ReservationDemoTimings._();

  /// L2: how long an untaken reservation sits only in Scheduled rides
  /// before it is also sent to the Home popup. The demo counts from app
  /// start, or from when it went back out after a cancel.
  static const Duration homePopupAfter = Duration(seconds: 3);

  /// L3: when the fast test day ([DemoReservationPlan.testDay] on
  /// `ScheduledClock.fastDay`: 07:00 at start, 30 times faster) reaches the
  /// Exclusive step of its 07:40 reservation, 20 minutes before pickup. The
  /// app runs on the real clock: there it is 20 minutes before the real
  /// pickup.
  static const Duration nearPickupAfter = Duration(milliseconds: 40000);

  /// Q29: the demo ride Movera assigns to this driver arrives this long
  /// after the Radar demo starts.
  static const Duration assignedAfter = Duration(seconds: 90);
}

/// Dispatch id of [demoReservationRequest].
const String demoReservationId = 'reservation-gamla-vagen';

/// Dispatch id of [DemoReservations.airport].
const String demoAirportReservationId = 'reservation-arlanda-t5';

/// Dispatch id of [demoAssignedReservation].
const String demoAssignedReservationId = 'reservation-assigned-kungsholmen';

/// When the demo reservations are picked up, counted from the first
/// reading of `ScheduledClock.instance` (rounded up to 5 minutes).
class DemoReservationPlan {
  const DemoReservationPlan({
    required this.main,
    required this.clashing,
    required this.assigned,
    this.airport,
  });

  /// The app: booked relative to now, pickups in 2 h and 5 h.
  static const DemoReservationPlan app = DemoReservationPlan(
    main: Duration(hours: 2),
    clashing: Duration(hours: 2, minutes: 25),
    airport: Duration(hours: 5),
    assigned: Duration(hours: 8, minutes: 30),
  );

  /// The fixed test day: from 07:00 the rides are at 07:40, 08:05 and
  /// 09:30, with no airport request unless a test adds it.
  static const DemoReservationPlan testDay = DemoReservationPlan(
    main: Duration(minutes: 40),
    clashing: Duration(minutes: 65),
    assigned: Duration(minutes: 150),
  );

  /// The Home popup's reservation (Gamla vägen → Solna).
  final Duration main;

  /// The Lidingö request whose time clashes with [main] (Q9).
  final Duration clashing;

  /// The airport request (→ Arlanda T5), also sent to Home; null leaves it
  /// out.
  final Duration? airport;

  /// The ride Movera assigns to this driver (Q29).
  final Duration assigned;
}

/// The demo's reservations, booked relative to the clock's first reading
/// by [plan]. Each is one object everywhere (Scheduled rides, the Home
/// popup, dispatch), so taking it in one place takes it everywhere.
class DemoReservations {
  const DemoReservations._();

  static DemoReservationPlan plan = DemoReservationPlan.app;

  static _DemoReservationSet? _set;
  static _DemoReservationSet get _rides =>
      _set ??= _DemoReservationSet(_anchor(), plan);

  /// Books them again from the clock's next reading.
  static void reset() => _set = null;

  /// When the demo was booked: now, rounded up to 5 minutes.
  static DateTime _anchor() {
    final now = ScheduledClock.instance.now();
    final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    final up = (5 - base.minute % 5) % 5;
    return base.add(Duration(minutes: up));
  }

  /// Gamla vägen → Solna centrum, with a stop at Odenplan.
  static ReservationRequestPreview get main => _rides.main;

  /// Lidingö → Central Station: no driver near, so admin raised the fare
  /// (Q13); its time clashes with [main] (Q9).
  static ReservationRequestPreview get clashing => _rides.clashing;

  /// Fridhemsplan → Arlanda T5; null when [plan] has none.
  static ReservationRequestPreview? get airport => _rides.airport;

  /// Q29: the ride Movera assigns to this driver.
  static ReservationRequestPreview get assigned => _rides.assigned;

  /// The open reservations sent to the Home popup, one after another.
  static List<ReservationRequestPreview> get homeRequests => [
    main,
    if (airport case final airport?) airport,
  ];

  /// Every open reservation of the demo, as dispatch holds them.
  static List<ReservationRequestPreview> get dispatchReservations =>
      homeRequests;
}

class _DemoReservationSet {
  _DemoReservationSet(DateTime anchor, DemoReservationPlan plan)
    : main = _at(
        anchor,
        plan.main,
        (time, day) => ReservationRequestPreview(
          id: demoReservationId,
          category: 'Comfort',
          rating: '4.94',
          riderName: 'Karin',
          riderTrips: 128,
          fare: '126.75 kr',
          pickupLabel: 'Pickup ${day.toLowerCase()} at $time',
          pickupAddress: 'Gamla vägen, Stockholm',
          dropoffAddress: 'Solna centrum, Solna',
          pickupTime: time,
          pickupDay: day,
          tripMinutes: 19,
          tripKm: 9.4,
          pickup: const GeoPoint(59.3362, 18.0714),
          dropoff: const GeoPoint(59.3603, 18.0009),
          stops: const [
            ReservationStop(
              address: 'Odenplan, Stockholm',
              point: GeoPoint(59.3430, 18.0496),
            ),
          ],
        ),
      ),
      clashing = _at(
        anchor,
        plan.clashing,
        (time, day) => ReservationRequestPreview(
          category: 'Premium',
          fare: '249.25 kr',
          fareBoost: '+40 kr',
          rating: '4.97',
          riderName: 'Anna',
          riderTrips: 211,
          pickupLabel: 'Pickup ${day.toLowerCase()} at $time',
          pickupAddress: 'Högsätravägen, Lidingö',
          dropoffAddress: 'Central Station, Stockholm',
          pickupTime: time,
          pickupDay: day,
          tripMinutes: 21,
          tripKm: 12,
          pickup: const GeoPoint(59.3584, 18.1567),
          dropoff: const GeoPoint(59.3303, 18.0586),
        ),
      ),
      airport = plan.airport == null
          ? null
          : _at(
              anchor,
              plan.airport!,
              (time, day) => ReservationRequestPreview(
                id: demoAirportReservationId,
                category: 'Premium',
                // R9 demo: a cash reservation; fare 248,40, cash 300, so
                // the driver owes Movera 51,60.
                paidByCash: true,
                cashToCollect: '300,00 kr',
                rating: '4.91',
                riderName: 'Maja',
                riderTrips: 73,
                fare: '248.40 kr',
                pickupLabel: 'Pickup ${day.toLowerCase()} at $time',
                pickupAddress: 'Fridhemsplan, Stockholm',
                dropoffAddress: 'Arlanda Terminal 5, Arlanda',
                pickupTime: time,
                pickupDay: day,
                tripMinutes: 36,
                tripKm: 40.8,
                pickup: const GeoPoint(59.3324, 18.0290),
                dropoff: const GeoPoint(59.6497, 17.9237),
              ),
            ),
      assigned = _at(
        anchor,
        plan.assigned,
        (time, day) => ReservationRequestPreview(
          id: demoAssignedReservationId,
          category: 'Comfort',
          rating: '4.88',
          riderName: 'Erik',
          riderTrips: 64,
          fare: '312.40 kr',
          pickupLabel: 'Pickup ${day.toLowerCase()} at $time',
          pickupAddress: 'Kungsholmstorg, Stockholm',
          dropoffAddress: 'Arlanda Terminal 5, Arlanda',
          pickupTime: time,
          pickupDay: day,
          tripMinutes: 38,
          tripKm: 41.6,
          pickup: const GeoPoint(59.3297, 18.0436),
          dropoff: const GeoPoint(59.6497, 17.9237),
        ),
      );

  final ReservationRequestPreview main;
  final ReservationRequestPreview clashing;
  final ReservationRequestPreview? airport;
  final ReservationRequestPreview assigned;

  /// The ride [lead] after [anchor], as "HH:mm" and "Today"/"Tomorrow",
  /// and as its date and time ([ReservationRequestPreview.scheduledAt]).
  static ReservationRequestPreview _at(
    DateTime anchor,
    Duration lead,
    ReservationRequestPreview Function(String time, String day) build,
  ) {
    final at = anchor.add(lead);
    final days = DateTime(at.year, at.month, at.day)
        .difference(DateTime(anchor.year, anchor.month, anchor.day))
        .inDays;
    return build(clockLabel(at), days == 0 ? 'Today' : 'Tomorrow')
        .scheduledFor(at);
  }
}

/// The demo reservation: listed in Scheduled rides at launch, later also
/// sent as the Home popup, close to pickup an Exclusive offer and a Radar
/// trip (see [ReservationDemoTimings]). Booked relative to now.
ReservationRequestPreview get demoReservationRequest => DemoReservations.main;

/// Q29: a scheduled ride Movera assigns to this driver. It arrives like an
/// Exclusive offer, "Assigned by Movera", and needs Accept in time.
ReservationRequestPreview get demoAssignedReservation =>
    DemoReservations.assigned;

class ReservationStop {
  const ReservationStop({required this.address, required this.point});

  final String address;
  final GeoPoint point;
}

class AppUpdateAdminConfig {
  const AppUpdateAdminConfig({
    required this.enabled,
    required this.latestVersion,
    required this.minimumVersion,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.dismissLabel,
    required this.mandatory,
    this.updateUrl,
  });

  final bool enabled;
  final String latestVersion;
  final String minimumVersion;
  final String title;
  final String message;
  final String actionLabel;
  final String dismissLabel;
  final bool mandatory;
  final String? updateUrl;
}

class DriverEventConfig {
  const DriverEventConfig({
    required this.id,
    required this.title,
    required this.category,
    required this.dateLabel,
    required this.timeLabel,
    required this.location,
    required this.description,
    required this.recommendedWindow,
    required this.demandLabel,
    required this.driverNote,
    required this.imageUrl,
    required this.imageCredit,
    required this.enabled,
  });

  final String id;
  final String title;
  final String category;
  final String dateLabel;
  final String timeLabel;
  final String location;
  final String description;
  final String recommendedWindow;
  final String demandLabel;
  final String driverNote;
  final String imageUrl;
  final String imageCredit;
  final bool enabled;
}

class StockholmAreaConfig {
  const StockholmAreaConfig({
    required this.name,
    required this.demandPercent,
    required this.demandLabel,
  });

  final String name;
  final int demandPercent;
  final String demandLabel;
}

class StockholmWorkStatsConfig {
  const StockholmWorkStatsConfig({
    required this.title,
    required this.subtitle,
    required this.innerAreas,
    required this.surroundingTitle,
    required this.surroundingAreas,
  });

  final String title;
  final String subtitle;
  final List<StockholmAreaConfig> innerAreas;
  final String surroundingTitle;
  final List<StockholmAreaConfig> surroundingAreas;
}

/// Driver-side contract for content controlled by the Movera admin system.
///
/// Today this returns frontend seed data. When the backend/admin repository is
/// connected, only this service should change; Home UI consumes the same model.
class DriverHomeAdminContentService {
  const DriverHomeAdminContentService({
    this.rulesExport,
    this.appConfig,
    this.zoneId = defaultZoneId,
  });

  /// Admin's Greater Stockholm zone (the old `svc-stockholm` id is read
  /// as an alias, see [DriverZones]).
  static const String defaultZoneId = DriverZones.defaultId;

  /// Admin's dispatch rules file (its `driverApp` part is read); null in
  /// the demo, which runs on the defaults.
  final Map<String, dynamic>? rulesExport;

  /// Admin's `DriverAppConfig` for the zone (contract §6). When set, its
  /// destination mode and next trips win over [rulesExport].
  final DriverAppConfig? appConfig;
  final String zoneId;

  /// The zone's app languages and its default for the driver app
  /// (`languages.default.driver`, Q48/Q49). Without admin's document the
  /// zone's seed: Greater Stockholm, Swedish.
  AppLanguages get languages =>
      (appConfig ?? const DriverAppConfig()).languages;

  DriverHomeAdminConfig load() {
    final export = rulesExport;
    final config = appConfig;
    final tripRules = config != null
        ? (config.destinationMode, config.nextTrips)
        : export == null
            ? null
            : DriverTripRulesExport.forZone(export, zoneId);
    return DriverHomeAdminConfig(
      destinationMode: tripRules?.$1,
      nextTrips: tripRules?.$2,
      performance: DriverPerformanceConfig.sample,
      scheduledRides: ScheduledRidesAdminConfig(
        enabled: true,
        hasOpenRequests: true,
        title: 'Scheduled rides available',
        subtitle: 'View open requests in your area',
        newRequest: DemoReservations.main,
        newRequests: DemoReservations.homeRequests,
      ),
      update: const AppUpdateAdminConfig(
        enabled: false,
        latestVersion: '1.0.0',
        minimumVersion: '1.0.0',
        title: 'Movera Driver update available',
        message: 'A newer version is ready with stability and trip-flow improvements.',
        actionLabel: 'Update app',
        dismissLabel: 'Later',
        mandatory: false,
      ),
      eventsSectionTitle: 'What’s happening',
      eventsSectionSubtitle: 'Plan your shift around busy periods',
      events: const [
        DriverEventConfig(
          id: 'stockholm-night-demand',
          title: 'Stockholm evening demand',
          category: 'Event',
          dateLabel: 'Fri 25 Sep',
          timeLabel: '18:00–22:30',
          location: 'Central Stockholm',
          description: 'Expect concentrated pickup activity around the city centre and waterfront after evening events finish.',
          recommendedWindow: '18:30–22:00',
          demandLabel: 'Higher demand expected',
          driverNote: 'Be online before the main departure window and stay close to legal pickup zones.',
          imageUrl: 'https://images.unsplash.com/photo-1670257876831-7e97238da208?auto=format&fit=crop&q=82&w=1400',
          imageCredit: 'Håkon Grimstad · Unsplash',
          enabled: true,
        ),
        DriverEventConfig(
          id: 'stockholm-waterfront',
          title: 'Waterfront traffic window',
          category: 'Traffic',
          dateLabel: 'Sat 26 Sep',
          timeLabel: '16:30–20:00',
          location: 'Stockholm waterfront',
          description: 'Large visitor movements can create temporary traffic pressure and higher ride demand around waterfront routes.',
          recommendedWindow: '17:00–19:30',
          demandLabel: 'Busy pickup window',
          driverNote: 'Go online before the crowd leaves and use live routing to avoid blocked curb areas.',
          imageUrl: 'https://images.unsplash.com/photo-1781040761543-fc71fcc17eb2?auto=format&fit=crop&q=82&w=1400',
          imageCredit: 'Rafael Peier · Unsplash',
          enabled: true,
        ),
        DriverEventConfig(
          id: 'stockholm-road-demand',
          title: 'Road demand alert',
          category: 'Demand',
          dateLabel: 'Sat 26 Sep',
          timeLabel: '22:00–02:00',
          location: 'Greater Stockholm',
          description: 'Night-time road conditions and event departures can shift demand quickly between central and outer zones.',
          recommendedWindow: '22:30–01:30',
          demandLabel: 'Late-night demand',
          driverNote: 'Stay online through the busiest window and check destination direction before matching longer trips.',
          imageUrl: 'https://images.unsplash.com/photo-1511443259588-05878425294f?auto=format&fit=crop&q=82&w=1400',
          imageCredit: 'Federico Enni · Unsplash',
          enabled: true,
        ),
      ],
      stockholmWork: const StockholmWorkStatsConfig(
        title: 'Work in Stockholm',
        subtitle: 'Inner city and the area around',
        innerAreas: [
          StockholmAreaConfig(
            name: 'Södermalm',
            demandPercent: 86,
            demandLabel: 'Busy',
          ),
          StockholmAreaConfig(
            name: 'Norrmalm',
            demandPercent: 78,
            demandLabel: 'Busy',
          ),
          StockholmAreaConfig(
            name: 'Östermalm',
            demandPercent: 64,
            demandLabel: 'Steady',
          ),
          StockholmAreaConfig(
            name: 'Kungsholmen',
            demandPercent: 57,
            demandLabel: 'Steady',
          ),
        ],
        surroundingTitle: 'Around Stockholm',
        surroundingAreas: [
          StockholmAreaConfig(
            name: 'Solna',
            demandPercent: 74,
            demandLabel: 'Busy',
          ),
          StockholmAreaConfig(
            name: 'Nacka',
            demandPercent: 63,
            demandLabel: 'Steady',
          ),
          StockholmAreaConfig(
            name: 'Huddinge',
            demandPercent: 58,
            demandLabel: 'Steady',
          ),
          StockholmAreaConfig(
            name: 'Täby',
            demandPercent: 46,
            demandLabel: 'Quiet',
          ),
          StockholmAreaConfig(
            name: 'Arlanda',
            demandPercent: 82,
            demandLabel: 'Busy',
          ),
          StockholmAreaConfig(
            name: 'Södertälje',
            demandPercent: 69,
            demandLabel: 'Steady',
          ),
          StockholmAreaConfig(
            name: 'Kista',
            demandPercent: 76,
            demandLabel: 'Busy',
          ),
          StockholmAreaConfig(
            name: 'Bromma',
            demandPercent: 54,
            demandLabel: 'Steady',
          ),
        ],
      ),
    );
  }
}
