part of 'accept_ride.dart';

/// Contract v0.18.144 (owner 2026-11-20): the driver's "Share my location"
/// card on the way to the pickup (accept until the rider is on board).
extension _AcceptRideLiveLocation on _AcceptRideState {
  Widget _liveLocationCard() {
    final api = LiveDriverServices.instance?.api;
    if (api == null || _stage == ActiveRideStage.onTrip) {
      return const SizedBox.shrink();
    }
    return DriverLiveLocationCard(
      key: ValueKey<String>('live-location-${widget.tripId}'),
      api: api,
      tripId: widget.tripId,
      riderName: _riderName,
      pickup: GeoPoint(_pickupPosition.latitude, _pickupPosition.longitude),
      position: () =>
          GeoPoint(_driverPosition.latitude, _driverPosition.longitude),
    );
  }
}
