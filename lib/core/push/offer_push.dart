import 'package:flutter/widgets.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';

/// G4 decision 1 (contract v0.18.6 `driverOffers.push`): a tap on a
/// new-offer push opens the app at Home, where the offer card shows while
/// the offer is still open (the offer feed brings it; the open offers are
/// asked again in case the feed slept), else Home as it is.
///
/// A driver on a trip, or not free for offers, keeps the screen he is on:
/// a push never closes a trip.
void openOfferPush(
  NavigatorState navigator, {
  required bool availableForOffers,
  required DispatchRepository dispatch,
}) {
  dispatch.refreshOffers();
  if (!availableForOffers) return;
  navigator.popUntil((route) => route.isFirst);
}
