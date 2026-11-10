part of 'accept_ride.dart';

/// IN-DL.9 #524 (a), owner 2026-11-10 "Check real result".
///
/// An on-trip Accept whose answer (and every `GET /driver/offers/{offerId}`
/// check of it) was lost after the offer's local time ran out is not
/// "Offer no longer available": the server may have queued that trip for
/// this driver. The card stays on "Accepting…" while the app asks again
/// with backoff (the same Accept, the same Idempotency-Key, then the
/// contract's checks); the server's answer decides. Still no answer: a
/// clear "no connection" notice, never "gone".
extension _ServerNextCheck on _ServerNextOffers {
  /// Waits before each further ask.
  static const backoff = [Duration(seconds: 2), Duration(seconds: 4)];

  Future<ClaimResult> _askUntilKnown(
    DispatchRepository dispatch,
    RideOffer offer,
  ) async {
    for (final wait in backoff) {
      await Future<void>.delayed(wait);
      if (!_s.mounted || _s._onTripRadarState != _OnTripRadarState.matching) {
        break;
      }
      ClaimResult result;
      try {
        result = await dispatch.claimOffer(offer.id);
      } catch (_) {
        result = const ClaimResult.networkError();
      }
      if (result.outcome != ClaimOutcome.networkError) return result;
    }
    return const ClaimResult.networkError();
  }

  /// Nothing known after every ask: the card goes down with a clear
  /// connection notice. Not marked done, so if the server's feed still
  /// shows the offer (or the accepted trip) the screen follows it.
  void _unknownAfterChecks() {
    final s = _s;
    _pending = null;
    s._rebuild(() {
      s._nextTripRadarOffer = null;
      s._onTripRadarState = _OnTripRadarState.scanning;
    });
    IslandMessages.show(HomeIslandNotices.noConnection);
    _changed();
  }
}
