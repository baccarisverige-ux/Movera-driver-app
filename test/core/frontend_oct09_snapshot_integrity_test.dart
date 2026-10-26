import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/ride/active_ride_repository.dart';

Map<String, dynamic> _snapshot() => <String, dynamic>{
  'schemaVersion': 2,
  'tripId': 'ride-1',
  'stage': 'onTrip',
  'stopAddresses': ['Vasagatan 4', 'Kungsgatan 8'],
  'stopIndex': 1,
  'waitSeconds': 42,
  'riderRating': 4.9,
};

Map<String, dynamic> _queued() => <String, dynamic>{
  'tripId': 'next-ride',
  'riderName': 'Preview',
  'fare': '110 kr',
  'category': 'Movera',
  'pickup': 'Pickup',
  'dropoff': 'Dropoff',
  'pickupLat': 59.3,
  'pickupLng': 18.1,
  'dropoffLat': 59.4,
  'dropoffLng': 18.2,
  'rating': 4.8,
  'pickupMinutes': 4,
  'tripMinutes': 16,
};

void main() {
  test(
    'restoration rejects mixed-type stop labels rather than dropping stops',
    () {
      final invalid = _snapshot()..['stopAddresses'] = ['One', 123, 'Three'];
      expect(PersistedActiveRide.fromJson(invalid), isNull);
      final good = PersistedActiveRide.fromJson(_snapshot());
      expect(good?.stopAddresses, ['Vasagatan 4', 'Kungsgatan 8']);
    },
  );

  test('restoration rejects negative or malformed waiting clock', () {
    for (final value in [-1, '5', 2.5]) {
      final invalid = _snapshot()..['waitSeconds'] = value;
      expect(PersistedActiveRide.fromJson(invalid), isNull);
    }
    expect(PersistedActiveRide.fromJson(_snapshot())?.waitSeconds, 42);
  });

  test('restoration rejects negative or malformed stop index', () {
    for (final value in [-1, '1', 1.5]) {
      final invalid = _snapshot()..['stopIndex'] = value;
      expect(PersistedActiveRide.fromJson(invalid), isNull);
    }
    expect(PersistedActiveRide.fromJson(_snapshot())?.stopIndex, 1);
  });

  test('rider rating must be finite within the 0-to-5 range', () {
    for (final value in [-1, 6, double.nan, double.infinity, '5']) {
      final invalid = _snapshot()..['riderRating'] = value;
      expect(PersistedActiveRide.fromJson(invalid), isNull);
    }
    expect(PersistedActiveRide.fromJson(_snapshot())?.riderRating, 4.9);
  });

  test('queued ride refuses invalid preview rating and duration metrics', () {
    for (final value in [-1, 6, double.nan, '5']) {
      final invalid = _queued()..['rating'] = value;
      expect(PersistedQueuedTrip.fromJson(invalid), isNull);
    }
    for (final field in ['pickupMinutes', 'tripMinutes']) {
      for (final value in [-1, 1.5, '6']) {
        final invalid = _queued()..[field] = value;
        expect(PersistedQueuedTrip.fromJson(invalid), isNull);
      }
    }
    final restored = PersistedQueuedTrip.fromJson(_queued());
    expect(restored?.rating, 4.8);
    expect(restored?.pickupMinutes, 4);
    expect(restored?.tripMinutes, 16);
  });

  test('an invalid queued ride cannot be promoted from a saved parent', () {
    final invalid = _snapshot()..['next'] = (_queued()..['tripMinutes'] = -5);
    expect(PersistedActiveRide.fromJson(invalid), isNull);
    final valid = _snapshot()..['next'] = _queued();
    expect(PersistedActiveRide.fromJson(valid)?.next?.tripId, 'next-ride');
  });
}
