/// driver-u54: the driver's local chat messages, per trip, kept on this
/// phone while the app runs so closing Chat does not lose them. Nothing is
/// sent; logout clears them. The demo only: a live build's chat is the
/// trip's on the server (LiveTripChat).
class LocalChatMessages {
  LocalChatMessages._();

  static final Map<String, List<String>> _byTrip = {};

  /// The trip's list (shared by every Chat opened for it); without a trip
  /// id, a list for this Chat only.
  static List<String> forTrip(String? tripId) => tripId == null
      ? <String>[]
      : _byTrip.putIfAbsent(tripId, () => <String>[]);

  static void reset() => _byTrip.clear();
}
