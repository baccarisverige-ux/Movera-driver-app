import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/scheduled/server_reservations.dart';
import 'package:movera/presentation/driver/home/components/home_island_notices.dart';

Map<String, dynamic> _row({String? riderFirstName}) => {
  'tripId': 'trp_1',
  'version': 3,
  'scheduledAt': '2026-11-05T09:00:00Z',
  'categoryId': 'economy',
  'rideType': 'normal',
  'pickup': {'address': 'Sergels torg', 'lat': 59.3326, 'lng': 18.0649},
  'dropoff': {'address': 'Medborgarplatsen', 'lat': 59.3143, 'lng': 18.0736},
  'stops': 0,
  'distanceMeters': 8000,
  'durationSeconds': 1080,
  'earnings': {'amountMinor': 15000, 'currency': 'SEK'},
  'status': 'accepted',
  'mustBeOnlineAt': '2026-11-05T08:00:00Z',
  'canStartAt': '2026-11-05T08:00:00Z',
  'riderFirstName': ?riderFirstName,
};

/// v0.18.32 fix job 2 (contract.json#bookedRideSeen.leaveNowName, Q5 popup):
/// the leave-now popup says "Time to drive to pickup · {rider name}".
void main() {
  test('the accepted row carries the rider first name into the preview', () {
    final ride = ServerReservation.fromJson(_row(riderFirstName: ' Anna '));
    expect(ride.riderFirstName, 'Anna');
    final preview = ride.toPreview(
      dayWord: (_) => 'Today',
      pickupLabel: (t) => t,
    );
    expect(preview.riderName, 'Anna');
  });

  test('the leave-now island shows the name, and the old text without one', () {
    expect(
      HomeIslandNotices.leaveNow('10:00', riderName: 'Anna').title,
      'Time to drive to pickup · Anna',
    );
    expect(ServerReservation.fromJson(_row()).riderFirstName, '');
    expect(HomeIslandNotices.leaveNow('10:00').title, isNot(contains('·')));
  });
}
