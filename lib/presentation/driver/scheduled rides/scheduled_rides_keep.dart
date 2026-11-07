part of 'scheduled_rides.dart';

// Base job B8 (2026-11-04): moved word for word out of scheduled_rides.dart
// (no behaviour change).

/// Owner BL-Q6 / live test HIGH 2: "Keep it at the new time?" with the old
/// and new time and the NEW price. True keeps it, false gives it back,
/// null: no answer yet. The list, the notice tap and the details screen
/// all ask with it.
Future<bool?> askKeepAtNewTime(BuildContext context, ServerReservation ride) =>
    showDialog<bool>(
      context: context,
      // G3-D7: Movera black / green, never the default purple.
      builder: (dialogContext) => MoveraDialogTheme(
        child: AlertDialog(
          key: const ValueKey<String>('scheduled-keep-dialog'),
          title: Text(tr.schedKeepTitle),
          content: _KeepWords(ride: ride),
          actions: [
            TextButton(
              key: const ValueKey<String>('scheduled-keep-no'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr.schedKeepNo),
            ),
            FilledButton(
              key: const ValueKey<String>('scheduled-keep-yes'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr.schedKeepYes),
            ),
          ],
        ),
      ),
    );

/// Sends the driver's answer, reads the list again and says what happened.
Future<void> answerKeepAtNewTime(
  BuildContext context,
  ServerReservation ride,
  bool keep,
) async {
  final live = LiveDriverServices.instance?.reservations;
  if (live == null) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final refused = await live.keep(ride.tripId, keep: keep);
  await ScheduledRideStore.syncFromServer(live);
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        refused == null
            ? (keep
                  ? tr.schedKeptAt(ServerReservation.clockOf(ride.scheduledAt))
                  : tr.schedGaveBack)
            : refused == ReservationRefusal.network
            ? tr.islandNoConnection
            : tr.islandNoLongerAvailable,
      ),
    ),
  );
}

class _KeepWords extends StatelessWidget {
  const _KeepWords({required this.ride});

  final ServerReservation ride;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr.schedKeepBody(
          ServerReservation.clockOf(ride.previousAt ?? ride.scheduledAt),
          ServerReservation.clockOf(ride.scheduledAt),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        tr.schedKeepNewPrice(ride.earnings.formatted),
        key: const ValueKey<String>('scheduled-keep-price'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

/// The Keep-it question on the booking details screen (live test HIGH 2).
class _KeepCard extends StatelessWidget {
  const _KeepCard({required this.ride});

  final ServerReservation ride;

  @override
  Widget build(BuildContext context) => MoveraDialogTheme(
    child: Container(
      key: const ValueKey<String>('scheduled-keep-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0C46B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.schedKeepTitle,
            style: const TextStyle(
              color: Color(0xFF252E3A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          _KeepWords(ride: ride),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey<String>('scheduled-keep-card-no'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MoveraDialogTheme.ink,
                    side: const BorderSide(color: MoveraDialogTheme.ink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await answerKeepAtNewTime(context, ride, false);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  child: Text(tr.schedKeepNo, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const ValueKey<String>('scheduled-keep-card-yes'),
                  onPressed: () async {
                    await answerKeepAtNewTime(context, ride, true);
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  child: Text(tr.schedKeepYes, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// W3 (real-screen run 2026-11-07, 2-booked 069/075): the booked ride the
/// driver asked to start by hand (« Starta nu mot upphämtningen »). Home
/// listens, starts it on the server and opens its trip.
final ValueNotifier<String?> startBookedRideNow = ValueNotifier<String?>(null);

/// Owner leave on time: "Start in 12 min", then "Start now towards the
/// pickup", from the server's leaveAt (live position, road route).
class LeaveCountdown extends StatefulWidget {
  const LeaveCountdown({
    super.key,
    required this.leaveAt,
    required this.pickupAt,
    required this.earlyMin,
    this.now,
    this.rideId,
    this.startableAt,
  });

  final DateTime leaveAt;
  final DateTime pickupAt;
  final int earlyMin;
  final DateTime Function()? now;

  /// W3: the booked ride; from [startableAt] (the server's start window,
  /// `scheduledAt − onlineBeforeMin` = `mustBeOnlineAt`) the banner is a
  /// button that starts it.
  final String? rideId;
  final DateTime? startableAt;

  @override
  State<LeaveCountdown> createState() => _LeaveCountdownState();
}

class _LeaveCountdownState extends State<LeaveCountdown> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = (widget.now ?? DateTime.now)();
    final left = widget.leaveAt.difference(now);
    final go = left.inSeconds <= 0;
    final minutes = (left.inSeconds / 60).ceil();
    final id = widget.rideId;
    final from = widget.startableAt;
    final startable =
        id != null && id.isNotEmpty && from != null && !now.isBefore(from);
    final banner = _banner(go, minutes);
    if (!startable) return banner;
    return Semantics(
      button: true,
      label: tr.schedLeaveNowTitle,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey<String>('scheduled-leave-start'),
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            // Home opens the trip: it must be on top.
            Navigator.of(context).popUntil((route) => route.isFirst);
            startBookedRideNow.value = id;
          },
          child: banner,
        ),
      ),
    );
  }

  Widget _banner(bool go, int minutes) {
    return Container(
      key: const ValueKey<String>('scheduled-leave-countdown'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: go ? const Color(0xFF19865C) : const Color(0xFFE9F4EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_car_rounded,
            color: go ? Colors.white : const Color(0xFF19865C),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  go ? tr.schedLeaveNowTitle : tr.schedLeaveIn('$minutes'),
                  style: TextStyle(
                    color: go ? Colors.white : const Color(0xFF19865C),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  tr.schedLeaveArrive(
                    '${widget.earlyMin}',
                    ServerReservation.clockOf(widget.pickupAt),
                  ),
                  style: TextStyle(
                    color: go ? Colors.white : const Color(0xFF3E4A50),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
