import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
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
    this.paymentMethod,
  });

  final WaybillRepository? waybillRepository;
  final DriverSessionController? sessionController;
  final ActiveRideRepository? activeRideRepository;
  final Widget? nextRide;

  /// "Card" or "Cash"; unknown shows a dash.
  final String? paymentMethod;

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
  bool _finishing = false;
  late final WaybillRepository _waybills;

  WaybillRecord? get _record => _waybills.last;

  @override
  void initState() {
    super.initState();
    _waybills = widget.waybillRepository ?? InMemoryWaybillRepository.instance;
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
    final rider = record?.riderName ?? 'Rider';
    final issued = record?.issuedAt;
    final when = issued == null
        ? 'Just now'
        : '${_two(issued.hour)}:${_two(issued.minute)}';

    return Scaffold(
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
                    const Text(
                      'Ride completed',
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
                    const SizedBox(height: 22),
                    _fare(record?.fare),
                    const SizedBox(height: 12),
                    Center(child: _chip(record)),
                    const SizedBox(height: 26),
                    _stars(rider),
                    const SizedBox(height: 22),
                    const Divider(height: 1, thickness: 1, color: _line),
                    const SizedBox(height: 20),
                    _stop(
                      mark: const OfferStopMark.pickup(),
                      text: record?.pickup ?? 'Pickup',
                    ),
                    const SizedBox(height: 14),
                    _stop(
                      mark: const OfferStopMark.dropoff(),
                      text: record?.dropoff ?? 'Drop-off',
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, thickness: 1, color: _line),
                    const SizedBox(height: 16),
                    _row('Payment', Text(widget.paymentMethod ?? '—',
                        style: _value)),
                    _row(
                      'Waybill',
                      record == null
                          ? const Text('—', style: _value)
                          : InkWell(
                              key: const ValueKey<String>(
                                'ride-completed-waybill',
                              ),
                              onTap: () => showMoveraWaybillSheet(
                                context,
                                record,
                                title: 'Last waybill',
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  'Open',
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
                      'Trip ID',
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
                  onPressed: _finishing ? null : _finish,
                  style: FilledButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _value = TextStyle(
    color: _ink,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  Widget _fare(String? fare) {
    if (fare == null) {
      return const Text(
        'Completed',
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
      record?.service ?? 'Movera',
      if (record != null && record.source.trim().isNotEmpty) record.source,
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rating not sent (demo)')),
            );
          },
          updateOnDrag: true,
        ),
        const SizedBox(height: 8),
        Text(
          'Rate $rider',
          style: const TextStyle(color: _muted, fontSize: 14),
        ),
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
          Flexible(child: Align(alignment: Alignment.centerRight, child: value)),
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
            const Expanded(
              child: Text(
                'Trip completed',
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
