import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/money/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/ratings/rider_rating.dart';
import 'package:movera/core/ride/active_ride_repository.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/waybill/waybill.dart';
import 'package:movera/presentation/driver/accept%20ride/island_morph.dart';
import 'package:movera/presentation/driver/accept%20ride/trip_island.dart';
import 'package:movera/presentation/driver/home/components/home_offer_sheet.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/waybill/waybill_sheet.dart';
import 'package:movera/widgets/navigation_transition.dart';

/// Ride completed: a plain white page. Check, fare, rating, route, a few
/// rows and Done. After Done the driver is back on Home, online.
class DriverRideCompleted extends StatefulWidget {
  const DriverRideCompleted({
    super.key,
    this.waybillRepository,
    this.sessionController,
    this.activeRideRepository,
    this.nextRide,
    this.paidByCash,
    this.ratingSender,
    this.ratingAllowed = true,
  });

  final WaybillRepository? waybillRepository;
  final DriverSessionController? sessionController;
  final ActiveRideRepository? activeRideRepository;
  final Widget? nextRide;

  /// True for a cash trip, false for one paid in the app (card, Apple Pay
  /// …); null shows a dash.
  final bool? paidByCash;

  /// Contract v0.9.0: sends the rating of the rider (stars, tags, comment).
  /// Defaults to the live build's client; the demo sends nothing.
  final RiderRatingSender? ratingSender;

  /// v0.18.10 `finish.ratingAllowed`: false hides the stars.
  final bool ratingAllowed;

  @override
  State<DriverRideCompleted> createState() => _DriverRideCompletedState();
}

class _DriverRideCompletedState extends State<DriverRideCompleted> {
  static const Color _ink = Color(0xFF111111);
  static const Color _muted = Color(0xFF7A848A);
  static const Color _green = Color(0xFF2E9E5B);
  static const Color _soft = Color(0xFFF1F2F4);
  static const Color _line = Color(0xFFECEEF0);
  static const Color _star = Color(0xFFC3C8CD);
  static const Color _starOn = Color(0xFFF2A12E);

  double _rating = 0;
  final Set<String> _tags = <String>{};
  final TextEditingController _comment = TextEditingController();
  late final RiderRatingSender _ratings =
      widget.ratingSender ?? RiderRatingSender.fromApp();

  /// driver-u153: 'Rating not sent' shows once, not once per drag update.
  bool _ratingNoticeShown = false;
  bool _finishing = false;
  late final WaybillRepository _waybills;

  WaybillRecord? get _record => _waybills.last;

  @override
  void initState() {
    super.initState();
    _waybills = widget.waybillRepository ?? InMemoryWaybillRepository.instance;
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Done: a rating the driver gave goes to Movera first (owner, part 3).
  /// It is optional, so a failed send says so and the driver goes on.
  Future<void> _done() async {
    if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final tripId = _record?.tripId;
    if (_rating >= 1 && tripId != null && _ratings.live) {
      setState(() => _finishing = true);
      final outcome = await _ratings.send(
        tripId: tripId,
        stars: _rating.round(),
        tags: [
          for (final tag in RiderRatingTags.aboutRider)
            if (_tags.contains(tag)) tag,
        ],
        comment: _comment.text,
      );
      if (!mounted) return;
      if (outcome == RiderRatingOutcome.failed) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.ratingCouldNotSend)));
      }
      setState(() => _finishing = false);
    }
    _finish();
  }

  void _finish() {
    if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _finishing = true);
    final navigator = Navigator.of(context);
    final nextRide = widget.nextRide;
    // R13-5: the driver always stays online after a trip. Only holding the
    // radar or the missed-offers rule takes them offline; endTrip() keeps
    // that rule's offline-after-trip and a suspension.
    widget.sessionController?.stayOnlineAfterTrip();
    if (nextRide != null) {
      _waybills.promoteNextToCurrent();
      navigator.pushReplacement(BottomToTopTransition(nextRide));
      return;
    }
    _waybills.clearNext();
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    navigator.pushReplacement(
      BottomToTopTransition(
        DriverHome(
          initialOnline: widget.sessionController?.isOnline ?? true,
          waybillRepository: _waybills,
          sessionController: widget.sessionController,
          activeRideRepository: widget.activeRideRepository,
        ),
      ),
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static (String, String) _place(String text) {
    final comma = text.indexOf(',');
    if (comma <= 0) {
      return (text.trim(), '');
    }
    return (text.substring(0, comma).trim(), text.substring(comma + 1).trim());
  }

  static String _shortId(String id) =>
      id.length > 12 ? '…${id.substring(id.length - 9)}' : id;

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final rider = record?.riderName ?? tr.rider;
    final issued = record?.issuedAt;
    final when = issued == null
        ? tr.justNow
        : '${_two(issued.hour)}:${_two(issued.minute)}';

    final page = Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey<String>('ride-completed-scroll'),
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: _CompletedIsland()),
                    const SizedBox(height: 28),
                    Center(
                      child: Container(
                        key: const ValueKey<String>('ride-completed-check'),
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _soft,
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          AppAssets.solarCheckCircle,
                          width: 30,
                          height: 30,
                          colorFilter: const ColorFilter.mode(
                            _green,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr.rideCompleted,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$rider · $when',
                      key: const ValueKey<String>('ride-completed-subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _muted, fontSize: 14),
                    ),
                    if (record?.endedEarlyBy case final by?) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${tr.g8EndedEarly} · '
                        '${by == 'rider' ? tr.g8RiderEnded : tr.g8DriverEnded}',
                        key: const ValueKey<String>('ride-completed-early'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7A5200),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _money(record),
                    const SizedBox(height: 12),
                    Center(child: _chip(record)),
                    const SizedBox(height: 26),
                    if (widget.ratingAllowed) ...[
                      _stars(rider),
                      const SizedBox(height: 22),
                    ],
                    const Divider(height: 1, thickness: 1, color: _line),
                    const SizedBox(height: 20),
                    _stop(
                      mark: const OfferStopMark.pickup(),
                      text: record?.pickup ?? tr.pickup,
                    ),
                    const SizedBox(height: 14),
                    _stop(
                      mark: const OfferStopMark.dropoff(),
                      text: record?.dropoff ?? tr.dropOff,
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, thickness: 1, color: _line),
                    const SizedBox(height: 16),
                    _row(
                      tr.payment,
                      Text(switch (widget.paidByCash) {
                        true => tr.cash,
                        false => tr.inApp,
                        null => '—',
                      }, style: _value),
                    ),
                    _row(
                      tr.waybill,
                      record == null
                          ? const Text('—', style: _value)
                          : InkWell(
                              key: const ValueKey<String>(
                                'ride-completed-waybill',
                              ),
                              onTap: () => showMoveraWaybillSheet(
                                context,
                                record,
                                title: tr.lastWaybill,
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  tr.open,
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    _row(
                      tr.tripId,
                      Text(
                        record == null ? '—' : _shortId(record.tripId),
                        style: _value,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                10,
                24,
                MediaQuery.paddingOf(context).bottom + 16,
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey<String>('ride-completed-done'),
                  onPressed: _finishing ? null : _done,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    tr.done,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // Back (Android, browser) takes the same exit as Done: the trip ends
    // and a secured next trip opens. A plain pop left the session on
    // trip, so Home could never go online again (driver-u149/u150).
    // _finish runs once; a second Back while it leaves does nothing.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: page,
    );
  }

  static const TextStyle _value = TextStyle(
    color: _ink,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  /// Owner decision 2026-10-27: Trip total (what the rider pays), Movera
  /// commission (minus) and the driver's money. v0.18.10 (owner G8 Q3):
  /// the driver's money is "Din andel" (driverTotal) with its lines under
  /// it; an earlier unpaid fee the rider paid with this trip is its own
  /// line and never Movera's commission (live bug 318 kr / −257,95 kr); a
  /// tip is all the driver's, outside the fare. The commission is what is
  /// left, so the lines always add up.
  Widget _money(WaybillRecord? record) {
    final get = record == null ? null : Money.parseLabel(record.fare);
    final paid = record?.riderFare == null || get == null
        ? null
        : Money.parseLabel(record!.riderFare!, currency: get.currency);
    if (get == null || paid == null) return _fare(record?.fare);
    final debt = record!.debtCollected?.currency == get.currency
        ? record.debtCollected
        : null;
    final tip = record.tip?.amount.currency == get.currency
        ? record.tip!.amount
        : null;
    var commission = paid - get;
    if (debt != null) commission = commission - debt;
    if (tip != null) commission = commission + tip;
    final share = commission.minorUnits < 0
        ? '+${Money(minorUnits: -commission.minorUnits, currency: get.currency).formatted}'
        : '−${commission.formatted}';
    final lines = record.earningsBreakdown;
    return Column(
      key: const ValueKey<String>('ride-completed-money'),
      children: [
        _row(
          tr.rcTripTotal,
          Text(
            paid.formatted,
            key: const ValueKey<String>('ride-completed-total'),
            style: _value,
          ),
        ),
        if (debt != null)
          _row(
            tr.g8DebtLine,
            Text(
              '−${debt.formatted}',
              key: const ValueKey<String>('ride-completed-debt'),
              style: _value,
            ),
          ),
        _row(
          tr.rcMoveraCommission,
          Text(
            share,
            key: const ValueKey<String>('ride-completed-commission'),
            style: _value,
          ),
        ),
        if (tip != null)
          _row(
            tr.g8LineTip,
            Text(
              '+${tip.formatted}',
              key: const ValueKey<String>('ride-completed-tip'),
              style: _value,
            ),
          ),
        const Divider(height: 14, thickness: 1, color: _line),
        _row(
          tr.g8YourShare,
          Text.rich(
            key: const ValueKey<String>('ride-completed-fare'),
            TextSpan(text: get.formatted),
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (lines.length > 1)
          for (final line in lines)
            _row(
              '   ${line.label}',
              Text(
                line.amount.formatted,
                key: ValueKey<String>('ride-completed-line-${line.code}'),
                style: const TextStyle(color: _muted, fontSize: 13.5),
              ),
            ),
        if (record.tip case final tipInfo?) ...[
          const SizedBox(height: 6),
          Text(
            tipInfo.text,
            key: const ValueKey<String>('ride-completed-tip-note'),
            style: const TextStyle(color: _muted, fontSize: 13.5),
          ),
        ],
      ],
    );
  }

  Widget _fare(String? fare) {
    if (fare == null) {
      return Text(
        tr.completed,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _ink,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    final (whole, rest) = OfferSheetBody.fareParts(fare);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        key: const ValueKey<String>('ride-completed-fare'),
        TextSpan(
          children: [
            TextSpan(
              text: whole,
              style: const TextStyle(
                color: _ink,
                fontSize: 52,
                height: 1.05,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
              ),
            ),
            TextSpan(
              text: rest,
              style: const TextStyle(
                color: _muted,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(WaybillRecord? record) {
    final label = [
      categoryNameText(record?.service ?? 'Movera'),
      if (record != null && record.source.trim().isNotEmpty) record.sourceText,
    ].join(' · ');
    return Container(
      key: const ValueKey<String>('ride-completed-chip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _starIcon(String asset, Color color) => SvgPicture.asset(
    asset,
    width: 32,
    height: 32,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
  );

  Widget _stars(String rider) {
    return Column(
      children: [
        // Q37/Q38: optional, whole stars 1–5; Done without a rating skips.
        RatingBar(
          initialRating: _rating,
          minRating: 1,
          allowHalfRating: false,
          glow: false,
          itemCount: 5,
          itemSize: 34,
          itemPadding: const EdgeInsets.symmetric(horizontal: 6),
          ratingWidget: RatingWidget(
            full: _starIcon(AppAssets.offerStar, _starOn),
            half: _starIcon(AppAssets.offerStar, _starOn),
            empty: _starIcon(AppAssets.solarStar, _star),
          ),
          onRatingUpdate: (rating) {
            setState(() => _rating = rating);
            // Only the demo says the rating is not sent; live sends it on Done.
            if (_ratingNoticeShown || _ratings.live) return;
            _ratingNoticeShown = true;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(tr.ratingNotSentDemo)));
          },
          updateOnDrag: true,
        ),
        const SizedBox(height: 8),
        Text(
          tr.rateRider(rider),
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
        // Contract v0.9.0: optional tags and comment once a star is given.
        if (_rating >= 1) ...[
          const SizedBox(height: 14),
          Wrap(
            key: const ValueKey<String>('rider-rating-tags'),
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in RiderRatingTags.aboutRider)
                FilterChip(
                  key: ValueKey<String>('rider-rating-tag-$tag'),
                  label: Text(RiderRatingTags.label(tag)),
                  selected: _tags.contains(tag),
                  onSelected: (_) => setState(() {
                    if (!_tags.remove(tag)) _tags.add(tag);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('rider-rating-comment'),
            controller: _comment,
            maxLength: RiderRatingTags.commentMaxLength,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: tr.ratingCommentOptional,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _stop({required Widget mark, required String text}) {
    final (street, area) = _place(text);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Align(alignment: Alignment.centerLeft, child: mark),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                street,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (area.isNotEmpty)
                Text(
                  area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13.5),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: value),
          ),
        ],
      ),
    );
  }
}

/// The trip island, closing on "Trip completed".
class _CompletedIsland extends StatelessWidget {
  const _CompletedIsland();

  @override
  Widget build(BuildContext context) {
    return IslandMorph(
      size: const Size(TripIslandGeometry.width, TripIslandGeometry.height),
      face: 'trip-completed',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              AppAssets.solarCheckCircle,
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                Color(0xFF6EDBB0),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr.tripCompleted,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}
