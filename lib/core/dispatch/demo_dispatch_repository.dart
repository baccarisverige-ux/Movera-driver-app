import 'dart:async';

import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/geo/geo_point.dart';

/// Frontend/demo dispatch. A backend implementation replaces this class.
///
/// Snapshot rules the Radar UI already depends on:
/// - nearby-1, nearby-2, nearby-3 are live immediately
/// - nearby-4 and nearby-5 arrive later and wait for an explicit refresh
/// - nearby-2 loses the atomic claim race
/// - nearby-3 is claimed by another driver without this driver tapping Match
class DemoDispatchRepository implements DispatchRepository {
  DemoDispatchRepository({
    Duration claimDelay = const Duration(milliseconds: 1450),
    Duration newOfferDelay = const Duration(seconds: 7),
    Duration externalClaimDelay = const Duration(seconds: 13),
    this.losingOfferId = 'nearby-2',
    this.externalClaimOfferId = 'nearby-3',
  }) : _claimDelay = claimDelay,
       _newOfferDelay = newOfferDelay,
       _externalClaimDelay = externalClaimDelay;

  final Duration _claimDelay;
  final Duration _newOfferDelay;
  final Duration _externalClaimDelay;
  final String losingOfferId;
  final String externalClaimOfferId;

  final StreamController<List<RideOffer>> _nearby =
      StreamController<List<RideOffer>>.broadcast();
  final StreamController<List<RideOffer>> _nextTrip =
      StreamController<List<RideOffer>>.broadcast();

  List<RideOffer> _offers = List<RideOffer>.from(_immediateOffers);
  List<RideOffer> _queued = List<RideOffer>.from(_laterOffers);
  bool _demoStarted = false;
  int _generation = 0;
  bool _disposed = false;
  Timer? _newOfferTimer;
  Timer? _externalClaimTimer;

  static const List<RideOffer> _immediateOffers = [
    RideOffer(
      id: 'nearby-1',
      category: 'Comfort',
      fare: '111,02 kr',
      rating: '4.95',
      pickupMinutes: 7,
      pickupKm: 2.1,
      tripMinutes: 15,
      tripKm: 10.5,
      pickup: 'Hantverkargatan 4, Stockholm',
      dropoff: 'Trollesundsvägen 58B, Bandhagen',
      pickupPosition: GeoPoint(59.3295, 18.0475),
      dropoffPosition: GeoPoint(59.2705, 18.0515),
      isNearby: true,
      followsDestination: false,
      bags: 2,
    ),
    RideOffer(
      id: 'nearby-2',
      category: 'Movera',
      fare: '96,40 kr',
      rating: '4.91',
      pickupMinutes: 5,
      pickupKm: 1.4,
      tripMinutes: 18,
      tripKm: 8.7,
      pickup: 'Klarabergsgatan, Stockholm',
      dropoff: 'Ringvägen, Södermalm',
      pickupPosition: GeoPoint(59.3316, 18.0592),
      dropoffPosition: GeoPoint(59.3125, 18.0750),
      isNearby: true,
      followsDestination: true,
      payment: 'Cash',
    ),
    RideOffer(
      id: 'nearby-3',
      category: 'Premium',
      fare: '184,60 kr',
      rating: '4.98',
      pickupMinutes: 9,
      pickupKm: 3.6,
      tripMinutes: 22,
      tripKm: 14.2,
      pickup: 'Strandvägen, Stockholm',
      dropoff: 'Solna centrum, Solna',
      pickupPosition: GeoPoint(59.3332, 18.0916),
      dropoffPosition: GeoPoint(59.3599, 18.0002),
      isNearby: true,
      followsDestination: true,
      bags: 1,
      payment: 'Apple Pay',
    ),
  ];

  static const List<RideOffer> _laterOffers = [
    RideOffer(
      id: 'nearby-4',
      category: 'Priority',
      fare: '128,70 kr',
      rating: '4.93',
      pickupMinutes: 4,
      pickupKm: 1.1,
      tripMinutes: 13,
      tripKm: 7.4,
      pickup: 'Vasagatan, Stockholm',
      dropoff: 'Gärdet, Stockholm',
      pickupPosition: GeoPoint(59.3323, 18.0576),
      dropoffPosition: GeoPoint(59.3417, 18.1004),
      isNearby: true,
      followsDestination: true,
    ),
    RideOffer(
      id: 'nearby-5',
      category: 'Electric',
      fare: '139,20 kr',
      rating: '4.97',
      pickupMinutes: 8,
      pickupKm: 2.9,
      tripMinutes: 20,
      tripKm: 12.1,
      pickup: 'Odengatan, Stockholm',
      dropoff: 'Liljeholmen, Stockholm',
      pickupPosition: GeoPoint(59.3427, 18.0520),
      dropoffPosition: GeoPoint(59.3105, 18.0232),
      isNearby: true,
      followsDestination: false,
    ),
  ];

  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) {
    return Stream<List<RideOffer>>.multi((sink) {
      if (_disposed) {
        sink.closeSync();
        return;
      }
      List<RideOffer> snapshot(List<RideOffer> offers) =>
          List<RideOffer>.unmodifiable(
            destinationModeActive
                ? offers.where((offer) => offer.followsDestination)
                : offers,
          );
      final subscription = _nearby.stream.listen(
        (offers) => sink.addSync(snapshot(offers)),
        onError: sink.addErrorSync,
        onDone: sink.closeSync,
      );
      sink.onCancel = subscription.cancel;
      _ensureDemoSchedule();
      // Each listener owns its initial snapshot, even when it subscribes later.
      sink.addSync(snapshot(_offers));
    }, isBroadcast: true);
  }

  @override
  Stream<List<RideOffer>> watchNextTripOffers() {
    return Stream<List<RideOffer>>.multi((sink) {
      if (_disposed) {
        sink.closeSync();
        return;
      }
      final subscription = _nextTrip.stream.listen(
        sink.addSync,
        onError: sink.addErrorSync,
        onDone: sink.closeSync,
      );
      sink.onCancel = subscription.cancel;
      sink.addSync(const <RideOffer>[]);
    }, isBroadcast: true);
  }

  @override
  Future<ClaimResult> claimOffer(String offerId) async {
    if (_disposed) {
      return const ClaimResult.unavailable();
    }
    final generation = _generation;
    await Future<void>.delayed(_claimDelay);
    if (_disposed || generation != _generation) {
      return const ClaimResult.unavailable();
    }
    RideOffer? offer;
    for (final item in _offers) {
      if (item.id == offerId) {
        offer = item;
        break;
      }
    }
    if (offer == null) {
      return const ClaimResult.unavailable();
    }
    if (offerId == losingOfferId) {
      _removeOffer(offerId);
      return const ClaimResult.alreadyClaimed();
    }
    _removeOffer(offerId);
    return ClaimResult.success(offer);
  }

  @override
  void refreshOffers() {
    _emitNearby();
  }

  void _ensureDemoSchedule() {
    if (_disposed || _demoStarted) {
      return;
    }
    _demoStarted = true;
    _newOfferTimer = Timer(_newOfferDelay, _releaseQueuedOffers);
    _externalClaimTimer = Timer(_externalClaimDelay, () {
      _removeOffer(externalClaimOfferId);
    });
  }

  void _releaseQueuedOffers() {
    if (_queued.isEmpty) {
      return;
    }
    _offers = [..._offers, ..._queued];
    _queued = const <RideOffer>[];
    _emitNearby();
  }

  void _removeOffer(String offerId) {
    final next = _offers.where((item) => item.id != offerId).toList();
    if (next.length == _offers.length) {
      return;
    }
    _offers = next;
    _emitNearby();
  }

  void _emitNearby() {
    if (_nearby.isClosed) {
      return;
    }
    _nearby.add(List<RideOffer>.unmodifiable(_offers));
  }

  /// Returns the demo to its first-launch offer set, for logout/re-entry.
  void reset() {
    if (_disposed) {
      return;
    }
    _generation++;
    _newOfferTimer?.cancel();
    _externalClaimTimer?.cancel();
    _offers = List<RideOffer>.from(_immediateOffers);
    _queued = List<RideOffer>.from(_laterOffers);
    _demoStarted = false;
    _emitNearby();
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _newOfferTimer?.cancel();
    _externalClaimTimer?.cancel();
    _nearby.close();
    _nextTrip.close();
  }
}
