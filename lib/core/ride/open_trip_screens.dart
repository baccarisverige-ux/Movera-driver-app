import 'package:flutter/foundation.dart';

/// S6 I-1 / S8 R2 (2026-11-07): the trip screens open now, by trip, so a
/// tap on a trip push (`movera-driver://trip(s)/{tripId}`) can bring the
/// trip screen back from under a menu page and a push about a trip that
/// is not on screen (a pay change, « Course annulée ») opens the bell.
class OpenTripScreens {
  OpenTripScreens._();

  static final Map<String, VoidCallback> _screens = {};

  /// The trip screen of [tripId] is up; [bringToFront] closes what covers
  /// it and reads the trip again.
  static void add(String tripId, VoidCallback bringToFront) =>
      _screens[tripId] = bringToFront;

  static void remove(String tripId, VoidCallback bringToFront) {
    if (identical(_screens[tripId], bringToFront)) _screens.remove(tripId);
  }

  static bool isOpen(String tripId) => _screens.containsKey(tripId);

  /// True when the trip screen of [tripId] is up (and is now on top).
  static bool bringToFront(String tripId) {
    final screen = _screens[tripId];
    if (screen == null) return false;
    screen();
    return true;
  }

  @visibleForTesting
  static void reset() => _screens.clear();
}

/// A tap on a trip push: true when it is about the trip being driven (its
/// screen is brought back, or Home is still restoring it), false when the
/// notice is about another trip, so the bell list opens on it.
bool openTripPush(String tripId, {String? activeTripId}) =>
    OpenTripScreens.bringToFront(tripId) || activeTripId == tripId;
