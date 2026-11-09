part of 'accept_ride.dart';

// Rule 25 split (owner 2026-11-07, "split first"): moved word for word out of
// accept_ride_panel.dart (no behaviour change). The incoming next-trip offer card.
extension _AcceptRideOfferCard on _AcceptRideState {
  Widget _buildIncomingRideCard() {
    final offer = _nextTripRadarOffer;
    if (offer == null) {
      return const SizedBox.shrink();
    }
    const alertCoral = Color(0xFFFF765C);
    // On-trip Exclusive (2026-11-08): a server offer counts down to its
    // own `expiresAt`; a demo offer has the whole admin time.
    final (:left, :span) = _offerTimeLeft(offer);

    return Material(
      key: const ValueKey<String>('on-trip-radar-offer-button'),
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: alertCoral.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: alertCoral.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF11181C).withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9EEF1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    categoryNameText(offer.category),
                    style: const TextStyle(
                      color: _AcceptRideState._ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_destinationActive) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _AcceptRideState._ink,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      tr.onYourWay,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 7),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: alertCoral.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      tr.afterThisDropOff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFB84F3D),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Q18: while driving a rider, only Exclusive offers. G4-E7: the
            // mark alone, no "why you got this trip" line.
            const Row(
              children: [
                OfferBadge.exclusive(
                  key: ValueKey<String>('on-trip-exclusive-mark'),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    offer.shownFare,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AcceptRideState._ink,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.9,
                    ),
                  ),
                ),
                // G4 decision 3: no made-up rating when the server sent none.
                if (offer.rating > 0) ...[
                  const SizedBox(width: 8),
                  const MoveraLineIcon(
                    mark: MoveraMark.star,
                    color: Color(0xFFD7A02C),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    offer.rating.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF6F7B82),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              tr.availableAfterYourCurrentDropOff,
              style: TextStyle(
                color: _AcceptRideState._muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              key: ValueKey<String>('on-trip-offer-${offer.id}'),
              tween: Tween<double>(
                begin: left.inMilliseconds / span.inMilliseconds,
                end: 0,
              ),
              duration: left,
              builder: (context, remaining, _) {
                final seconds = (remaining * (span.inMilliseconds / 1000))
                    .ceil();
                return Column(
                  children: [
                    Row(
                      children: [
                        const MoveraLineIcon(
                          mark: MoveraMark.timer,
                          color: _AcceptRideState._ink,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tr.exclusiveSecondsS(seconds),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _AcceptRideState._ink,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            tr.onThisRide,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF8A9499),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: remaining,
                        backgroundColor: const Color(0xFFF0E8E5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          alertCoral,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE4E8EA)),
            const SizedBox(height: 11),
            _offerLocationRow(
              color: const Color(0xFF215277),
              title: tr.pickupMinutesMinAway(offer.pickupMinutes),
              subtitle: offer.pickup,
            ),
            const SizedBox(height: 9),
            _offerLocationRow(
              color: _AcceptRideState._ink,
              title: tr.tripMinutesMinTrip(offer.tripMinutes),
              subtitle: offer.dropoff,
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey<String>('on-trip-radar-deny'),
                    onPressed: _AcceptRideTrip(this)._denyNextTripRadar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _AcceptRideState._ink,
                      side: const BorderSide(color: Color(0xFFD5DCDF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(0, 42),
                    ),
                    child: Text(
                      tr.deny,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const ValueKey<String>('on-trip-radar-match-next'),
                    onPressed: _AcceptRideTrip(this)._acceptNextTripRadar,
                    style: FilledButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF252E3A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      minimumSize: const Size(0, 42),
                    ),
                    child: Text(
                      driverText(DriverTexts.offerAccept),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The offer's time to answer: [left] of a bar [span] long.
  ({Duration left, Duration span}) _offerTimeLeft(_NextTripRadarOffer offer) {
    final lifetime = _AcceptRideState._onTripOfferLifetime;
    final expires = offer.expiresAt;
    if (expires == null) return (left: lifetime, span: lifetime);
    final left = expires.difference(_AcceptRideTrip(this)._offerNow());
    if (left <= Duration.zero) {
      return (left: const Duration(milliseconds: 1), span: lifetime);
    }
    return (left: left, span: left > lifetime ? left : lifetime);
  }

  Widget _offerLocationRow({
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AcceptRideState._ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AcceptRideState._muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
