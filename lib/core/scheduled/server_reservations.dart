import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/money/money.dart';

/// Contract v0.18.17 Book later (`contract.json#bookLater.driver`): one
/// booked ride of `GET /driver/reservations` (`DriverReservation`).
class ServerReservation {
  const ServerReservation({
    required this.tripId,
    required this.version,
    required this.scheduledAt,
    required this.categoryId,
    required this.rideType,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickup,
    required this.dropoff,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.earnings,
    required this.status,
    required this.mustBeOnlineAt,
    this.popup = false,
    this.changeAskUntil,
    this.previousAt,
  });

  /// Owner BL-Q6: the rider changed this ride; answer "Keep it at the new
  /// time?" before [changeAskUntil]. [previousAt] is the old pickup time.
  final DateTime? changeAskUntil;
  final DateTime? previousAt;
  bool get asksToKeep => changeAskUntil != null;

  final String tripId;
  final int version;
  final DateTime scheduledAt;
  final String categoryId;
  final String rideType;
  final String pickupAddress;
  final String dropoffAddress;
  final GeoPoint pickup;
  final GeoPoint dropoff;
  final int distanceMeters;
  final int durationSeconds;
  final Money earnings;
  final String status;
  final DateTime mustBeOnlineAt;
  final bool popup;

  bool get accepted => status == 'accepted';

  /// Throws [FormatException] when a required field is missing or wrong.
  factory ServerReservation.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('DriverReservation.$key missing', value);
      }
      return value;
    }

    DateTime time(String key) =>
        DateTime.tryParse(text(key)) ??
        (throw FormatException('DriverReservation.$key not a time'));
    Map<String, dynamic> place(String key) {
      final value = json[key];
      if (value is! Map) throw FormatException('DriverReservation.$key');
      return Map<String, dynamic>.from(value);
    }

    GeoPoint point(Map<String, dynamic> p) => GeoPoint(
      (p['lat'] as num?)?.toDouble() ?? 0,
      (p['lng'] as num?)?.toDouble() ?? 0,
    );
    final earnings = json['earnings'];
    if (earnings is! Map) {
      throw const FormatException('DriverReservation.earnings missing');
    }
    final reservation = json['reservation'];
    final ask =
        json['changeAsk'] ??
        (reservation is Map ? reservation['changeAsk'] : null);
    final pickup = place('pickup');
    final dropoff = place('dropoff');
    return ServerReservation(
      tripId: text('tripId'),
      version: (json['version'] as num?)?.toInt() ?? 1,
      scheduledAt: time('scheduledAt'),
      categoryId: text('categoryId'),
      rideType: json['rideType'] is String
          ? json['rideType'] as String
          : 'normal',
      pickupAddress: pickup['address'] as String? ?? '',
      dropoffAddress: dropoff['address'] as String? ?? '',
      pickup: point(pickup),
      dropoff: point(dropoff),
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      earnings: Money.fromJson(Map<String, dynamic>.from(earnings)),
      status: text('status'),
      mustBeOnlineAt: time('mustBeOnlineAt'),
      popup: json['popup'] == true,
      changeAskUntil: ask is Map ? DateTime.tryParse('${ask['until']}') : null,
      previousAt: ask is Map ? DateTime.tryParse('${ask['previousAt']}') : null,
    );
  }

  /// "07:40" on this phone's clock.
  static String clockOf(DateTime at) {
    final local = at.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// The Scheduled rides list's card for this ride. [dayWord] names the
  /// pickup day ("Today", "Tomorrow", or the date) in the app language.
  ReservationRequestPreview toPreview({
    required String Function(DateTime at) dayWord,
    required String Function(String time) pickupLabel,
  }) {
    final time = clockOf(scheduledAt);
    return ReservationRequestPreview(
      category: CategoryCatalog.labelOf(categoryId),
      fare: earnings.formatted,
      earnings: earnings.formatted,
      pickupLabel: pickupLabel(time),
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupTime: time,
      pickupDay: dayWord(scheduledAt),
      tripMinutes: (durationSeconds / 60).round(),
      tripKm: (distanceMeters / 100).round() / 10,
      pickup: pickup,
      dropoff: dropoff,
      id: tripId,
      scheduledAt: scheduledAt.toLocal(),
    );
  }
}

/// `GET /driver/reservations?scope=open` and `?scope=accepted`, parsed.
/// A row that does not parse is left out (never a crash).
class ServerReservations {
  const ServerReservations({required this.open, required this.accepted});

  final List<ServerReservation> open;
  final List<ServerReservation> accepted;

  static List<ServerReservation> parsePage(Object? page) {
    final items = page is Map ? page['items'] : null;
    final out = <ServerReservation>[];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        try {
          out.add(ServerReservation.fromJson(Map<String, dynamic>.from(item)));
        } on FormatException {
          continue;
        }
      }
    }
    return out;
  }
}

/// Contract v0.18.17 `bookLater.errors`: why an Accept or Start was refused.
enum ReservationRefusal {
  changed,
  taken,
  inDispatch,
  clash,
  notOpen,
  off,
  tooEarly,
  notOnline,
  onTrip,
  network,
  other,
}

ReservationRefusal reservationRefusalOf(int status, Object? body) {
  final reason = body is Map ? body['reason'] : null;
  switch (reason) {
    case 'reservation_taken':
      return ReservationRefusal.taken;
    case 'reservation_in_dispatch':
      return ReservationRefusal.inDispatch;
    case 'reservation_clash':
      return ReservationRefusal.clash;
    case 'reservation_not_open':
      return ReservationRefusal.notOpen;
    case 'reservations_off':
      return ReservationRefusal.off;
    case 'reservation_too_early':
      return ReservationRefusal.tooEarly;
    case 'driver_not_available':
      return ReservationRefusal.notOnline;
    case 'driver_on_trip':
      return ReservationRefusal.onTrip;
  }
  return status == 404 ? ReservationRefusal.notOpen : ReservationRefusal.other;
}

/// The code sent when the driver gives a booked ride back: the reason he
/// picked when it is a contract scheduled code, else `scheduled_other`.
String giveBackReasonCode(String? picked) {
  const scheduled = {
    'scheduled_cannot_make_time',
    'scheduled_vehicle_issue',
    'scheduled_personal_emergency',
    'scheduled_pickup_too_far',
    'scheduled_trip_details',
    'scheduled_other',
  };
  return picked != null && scheduled.contains(picked)
      ? picked
      : 'scheduled_other';
}
