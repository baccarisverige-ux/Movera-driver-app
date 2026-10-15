import 'package:movera/core/geo/geo_point.dart';

class DriverHomeAdminConfig {
  const DriverHomeAdminConfig({
    required this.performance,
    required this.scheduledRides,
    required this.update,
    required this.eventsSectionTitle,
    required this.eventsSectionSubtitle,
    required this.events,
    required this.stockholmWork,
  });

  final DriverPerformanceConfig performance;
  final ScheduledRidesAdminConfig scheduledRides;
  final AppUpdateAdminConfig update;
  final String eventsSectionTitle;
  final String eventsSectionSubtitle;
  final List<DriverEventConfig> events;
  final StockholmWorkStatsConfig stockholmWork;
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

  final double rating;
  final double acceptanceRate;
  final double cancellationRate;
  final bool showRating;
  final bool showAcceptanceRate;
  final bool showCancellationRate;
}

class ScheduledRidesAdminConfig {
  const ScheduledRidesAdminConfig({
    required this.enabled,
    required this.hasOpenRequests,
    required this.title,
    required this.subtitle,
    this.newRequest,
  });

  final bool enabled;
  final bool hasOpenRequests;
  final String title;
  final String subtitle;

  /// Newest reservation request, shown as a Home popup when present.
  final ReservationRequestPreview? newRequest;
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
    this.rating = '',
  });

  /// Dispatch id; claiming it decides which driver gets the reservation.
  /// Empty for sample rides that are not open to take.
  final String id;

  /// The rider pays cash in the car (not in the app).
  final bool paidByCash;

  /// The rider's rating, e.g. "4.94"; empty when not known.
  final String rating;

  final String category;
  final String fare;
  final String pickupLabel;
  final String pickupAddress;
  final String dropoffAddress;

  /// When the rider is picked up, e.g. "07:40" on "Today".
  final String pickupTime;
  final String pickupDay;

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
    final minute = minuteOfDay;
    final day = pickupDay.trim().toLowerCase();
    final offset = day == 'today' ? 0 : day == 'tomorrow' ? 1 : null;
    if (minute == null || offset == null) {
      return null;
    }
    final pickupAt = DateTime(now.year, now.month, now.day + offset)
        .add(Duration(minutes: minute));
    final left = pickupAt.difference(now);
    return left.isNegative ? null : left;
  }
}

/// Where an untaken reservation shows, step by step (notes R21–R25), all
/// in one place. The admin panel sets each step later (jobs L1–L3 in the
/// design notes, "Later jobs (admin panel)"); until then the demo app uses
/// these fixed values.
///
/// 1. L1: it is listed in every driver's Scheduled rides (no setting yet).
/// 2. L2: untaken after [homePopupAfter], it also shows as the Home popup
///    to drivers who are online; it stays listed.
/// 3. L3: close to pickup ([nearPickupAfter], pickup within
///    [nearPickupWithinMinutes]) it becomes an Exclusive offer and joins
///    the Radar trips, where it only says "Reservation".
/// 4. Taken by a driver it leaves every place; the server gives it to the
///    first claim (R25).
/// 5. L3: the driver who took it cancels: it goes back to Scheduled rides
///    and, after [homePopupAfter], to the Home popup again.
class ReservationDemoTimings {
  const ReservationDemoTimings._();

  /// L2: how long an untaken reservation sits only in Scheduled rides
  /// before it is also sent to the Home popup. The demo counts from app
  /// start, or from when it went back out after a cancel.
  static const Duration homePopupAfter = Duration(seconds: 3);

  /// L3: the demo stand-in for "minutes before pickup": still untaken this
  /// long after Radar goes live, it becomes an Exclusive offer and joins
  /// the Radar trips.
  static const Duration nearPickupAfter = Duration(milliseconds: 40000);

  /// L3: only a pickup at most this many minutes away counts as close.
  static const int nearPickupWithinMinutes = 30;
}

/// Dispatch id of [demoReservationRequest].
const String demoReservationId = 'reservation-gamla-vagen-0740';

/// The demo reservation: listed in Scheduled rides at launch, later also
/// sent as the Home popup, close to pickup an Exclusive offer and a Radar
/// trip (see [ReservationDemoTimings]). It is one ride everywhere, so
/// taking it in one place takes it everywhere.
const ReservationRequestPreview demoReservationRequest =
    ReservationRequestPreview(
  id: demoReservationId,
  category: 'Comfort',
  rating: '4.94',
  fare: '126.75 kr',
  pickupLabel: 'Pickup today at 07:40',
  pickupAddress: 'Gamla vägen, Stockholm',
  dropoffAddress: 'Solna centrum, Solna',
  pickupTime: '07:40',
  pickupDay: 'Today',
  tripMinutes: 19,
  tripKm: 9.4,
  pickup: GeoPoint(59.3362, 18.0714),
  dropoff: GeoPoint(59.3603, 18.0009),
  stops: [
    ReservationStop(
      address: 'Odenplan, Stockholm',
      point: GeoPoint(59.3430, 18.0496),
    ),
  ],
);

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
  const DriverHomeAdminContentService();

  DriverHomeAdminConfig load() {
    return const DriverHomeAdminConfig(
      performance: DriverPerformanceConfig(
        rating: 4.88,
        acceptanceRate: 94.0,
        cancellationRate: 2.4,
      ),
      scheduledRides: ScheduledRidesAdminConfig(
        enabled: true,
        hasOpenRequests: true,
        title: 'Scheduled rides available',
        subtitle: 'View open requests in your area',
        newRequest: demoReservationRequest,
      ),
      update: AppUpdateAdminConfig(
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
      events: [
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
      stockholmWork: StockholmWorkStatsConfig(
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
