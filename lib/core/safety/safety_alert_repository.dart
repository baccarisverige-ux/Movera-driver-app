import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/safety/ride_check.dart';

/// Trip, driver and rider details sent with a safety alert.
class SafetyAlertTrip {
  const SafetyAlertTrip({
    required this.tripId,
    required this.riderName,
    required this.riderRating,
    required this.pickup,
    required this.dropoff,
    required this.fare,
    required this.category,
    required this.driverName,
    required this.vehicle,
    required this.plate,
    this.position,
  });

  final String tripId;
  final String riderName;

  /// Null when the rider has no rating yet.
  final double? riderRating;
  final String pickup;
  final String dropoff;
  final String fare;
  final String category;
  final String driverName;
  final String vehicle;
  final String plate;

  /// Where the car was when the alert was sent; null without GPS.
  final GeoPoint? position;
}

/// An alert to the Movera safety team (admin and Dispatch).
/// Never carries audio: recordings stay on the phone.
class SafetyAlert {
  const SafetyAlert({
    required this.id,
    required this.trip,
    required this.trigger,
    required this.reason,
    required this.topic,
    required this.answers,
    required this.sentAt,
    required this.updatedAt,
    this.recipients = SafetyAlertRepository.recipients,
    this.updates = 0,
  });

  final String id;
  final SafetyAlertTrip trip;
  final RideCheckTrigger trigger;
  final String reason;

  /// What the driver said, e.g. "Accident or collision" or "Called 112".
  final String topic;
  final List<RideCheckAnswer> answers;
  final DateTime sentAt;
  final DateTime updatedAt;
  final List<String> recipients;

  /// Follow-up answers added after the alert was sent.
  final int updates;

  SafetyAlert withAnswer(RideCheckAnswer answer) => SafetyAlert(
    id: id,
    trip: trip,
    trigger: trigger,
    reason: reason,
    topic: topic,
    answers: List<RideCheckAnswer>.unmodifiable([...answers, answer]),
    sentAt: sentAt,
    updatedAt: answer.at,
    recipients: recipients,
    updates: updates + 1,
  );
}

/// Safety alert boundary. A backend adapter replaces the demo one.
abstract interface class SafetyAlertRepository {
  static const List<String> recipients = ['admin', 'dispatch'];

  /// Sends an alert to admin and Dispatch at once.
  Future<SafetyAlert> send({
    required SafetyAlertTrip trip,
    required RideCheckTrigger trigger,
    required String reason,
    required String topic,
    required List<RideCheckAnswer> answers,
  });

  /// Adds a follow-up answer to an alert already sent.
  Future<SafetyAlert> update(String alertId, RideCheckAnswer answer);
}
