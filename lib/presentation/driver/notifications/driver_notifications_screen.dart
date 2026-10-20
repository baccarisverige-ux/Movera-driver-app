import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/presentation/driver/documents/document_renewal.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/styles/movera_map_palette.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

const Color _ink = Color(0xFF111614);
const Color _muted = Color(0xFF6F7A80);
const Color _line = Color(0xFFECEEEF);
const Color _green = Color(0xFF1C6B45);

/// Notifications (Q31): ride alerts, demand and events, account and
/// money, newest first. The island shows them as popups when they come.
class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({
    super.key,
    this.feed,
    this.dispatchRepository,
  });

  final DriverNotificationFeed? feed;

  /// For "View" on a scheduled ride.
  final DispatchRepository? dispatchRepository;

  @override
  State<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  late final DriverNotificationFeed _feed =
      widget.feed ?? DriverNotificationFeed.instance;

  /// Unread when the screen opened: they keep their dot while it is open.
  late final Set<String> _new = {
    for (final notice in _feed.items)
      if (!_feed.isRead(notice)) notice.id,
  };
  DriverNoticeGroup? _group;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _feed.markAllRead());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        centerTitle: true,
        title: Text(
          tr.notifications,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _feed.changes,
        builder: (context, _, _) {
          final now = _feed.now;
          final items = _feed.items
              .where((n) => _group == null || n.group == _group)
              .toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              _filters(),
              if (items.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(22, 40, 22, 0),
                  child: Text(
                    tr.noNotificationsYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 15),
                  ),
                ),
              for (var i = 0; i < items.length; i++) ...[
                _NoticeTile(
                  notice: items[i],
                  now: now,
                  fresh: _new.contains(items[i].id) || !_feed.isRead(items[i]),
                  onAction: () => _act(items[i]),
                ),
                if (i < items.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 74),
                    child: Divider(height: 1, thickness: 1, color: _line),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _filters() {
    Widget chip(String label, DriverNoticeGroup? group) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: ValueKey<String>('notifications-filter-${group?.name ?? 'all'}'),
            label: Text(label),
            selected: _group == group,
            showCheckmark: false,
            onSelected: (_) => setState(() => _group = group),
            selectedColor: _ink,
            backgroundColor: const Color(0xFFF2F4F5),
            side: BorderSide.none,
            labelStyle: TextStyle(
              color: _group == group ? Colors.white : _ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
      child: Row(
        children: [
          chip(tr.filterAll, null),
          chip(tr.rides, DriverNoticeGroup.rideAlerts),
          chip(tr.filterDemand, DriverNoticeGroup.demand),
          chip(tr.account, DriverNoticeGroup.account),
        ],
      ),
    );
  }

  void _act(DriverNotice notice) {
    switch (notice.action) {
      case DriverNoticeAction.viewScheduledRides:
        pushSingle(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ScheduledRidesScreen(
              dispatchRepository: widget.dispatchRepository,
            ),
          ),
        );
      case DriverNoticeAction.uploadDocument:
        final document =
            DocumentExpiryStore.instance.byId(notice.documentId ?? '');
        if (document != null && !document.inReview) {
          showDocumentUploadSheet(context, document);
        }
      case null:
        break;
    }
  }
}

/// "Now", "12 min ago", "3 h ago", "Yesterday", "4 days ago".
String noticeTimeLabel(DateTime at, DateTime now) {
  final ago = now.difference(at);
  if (ago.inMinutes < 1) { return tr.now; }
  if (ago.inMinutes < 60) { return tr.minutesAgo(ago.inMinutes); }
  if (ago.inHours < 24) { return tr.hoursAgo(ago.inHours); }
  if (ago.inDays == 1) { return tr.yesterday; }
  return tr.daysAgo(ago.inDays);
}

/// The Solar icon of each kind.
String noticeIcon(DriverNoticeKind kind) => switch (kind) {
      DriverNoticeKind.newScheduledRide => AppAssets.solarCalendarMark,
      DriverNoticeKind.exclusiveOffer => AppAssets.solarBolt,
      DriverNoticeKind.scheduledReminder => AppAssets.solarAlarm,
      DriverNoticeKind.leaveNow => AppAssets.solarRouting2,
      DriverNoticeKind.highDemand => AppAssets.solarGraphUp,
      DriverNoticeKind.event => AppAssets.solarMapPointWave,
      DriverNoticeKind.documentExpiring => AppAssets.solarDocumentText,
      DriverNoticeKind.documentApproved => AppAssets.solarCheckCircle,
      DriverNoticeKind.restOver => AppAssets.solarClockCircle,
      DriverNoticeKind.scheduledPaused => AppAssets.solarPauseCircle,
      DriverNoticeKind.payoutSent => AppAssets.solarWallet,
      DriverNoticeKind.bonusProgress => AppAssets.solarMedalRibbonStar,
    };

({Color ink, Color tint}) _toneOf(DriverNoticeKind kind) => switch (kind.group) {
      DriverNoticeGroup.rideAlerts =>
        (ink: const Color(0xFF1F5FAE), tint: const Color(0xFFEAF2FC)),
      DriverNoticeGroup.demand =>
        (ink: const Color(0xFFB4441E), tint: const Color(0xFFFDF0EA)),
      DriverNoticeGroup.account => kind == DriverNoticeKind.documentExpiring ||
              kind == DriverNoticeKind.scheduledPaused
          ? (ink: const Color(0xFF9B6B24), tint: const Color(0xFFFFF6E6))
          : (ink: _green, tint: const Color(0xFFEAF5EF)),
    };

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({
    required this.notice,
    required this.now,
    required this.fresh,
    required this.onAction,
  });

  final DriverNotice notice;
  final DateTime now;
  final bool fresh;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final tone = _toneOf(notice.kind);
    final area = notice.area;
    return Padding(
      key: ValueKey<String>('notice-${notice.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: tone.tint, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              noticeIcon(notice.kind),
              width: 21,
              height: 21,
              colorFilter: ColorFilter.mode(tone.ink, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notice.title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (fresh)
                      Container(
                        key: ValueKey<String>('notice-new-${notice.id}'),
                        margin: const EdgeInsets.only(left: 8, top: 6),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE0474C),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notice.body,
                  style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 4),
                Text(
                  noticeTimeLabel(notice.at, now),
                  style: const TextStyle(color: Color(0xFF9AA3A8), fontSize: 12),
                ),
                if (area != null) ...[
                  const SizedBox(height: 10),
                  DemandAreaMap(area: area),
                ],
                if (notice.actionLabel case final label?) ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: ValueKey<String>('notice-action-${notice.id}'),
                    onPressed: onAction,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: Color(0xFFD5D9DB)),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(label),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small drawn map of a demand area: the zone in red, the water and a
/// few streets around it. It is a picture, not a live map.
class DemandAreaMap extends StatelessWidget {
  const DemandAreaMap({super.key, required this.area});

  final DemandArea area;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr.mapOfArea(area.name),
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 112,
          width: double.infinity,
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _AreaMapPainter())),
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    area.name,
                    style: const TextStyle(
                      color: MoveraMapPalette.label,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaMapPainter extends CustomPainter {
  const _AreaMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Movera map colours (MoveraMapPalette): near-white land, grey blocks,
    // a park with a path, water, grey streets and one darker highway.
    canvas.drawRect(Offset.zero & size, Paint()..color = MoveraMapPalette.land);
    final blocks = Paint()..color = MoveraMapPalette.building;
    for (final block in [
      Rect.fromLTWH(w * 0.08, h * 0.04, w * 0.16, h * 0.11),
      Rect.fromLTWH(w * 0.47, h * 0.06, w * 0.14, h * 0.12),
      Rect.fromLTWH(w * 0.1, h * 0.27, w * 0.15, h * 0.13),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, const Radius.circular(2)),
        blocks,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.74, h * 0.06, w * 0.2, h * 0.3),
        const Radius.circular(8),
      ),
      Paint()..color = MoveraMapPalette.park,
    );
    canvas.drawLine(
      Offset(w * 0.77, h * 0.1),
      Offset(w * 0.91, h * 0.3),
      MoveraMapPalette.footpath(1.5),
    );
    final water = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.25, h * 0.58, w * 0.48, h * 0.7)
      ..quadraticBezierTo(w * 0.7, h * 0.82, w, h * 0.62)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(water, Paint()..color = MoveraMapPalette.water);
    final street = MoveraMapPalette.street(4);
    canvas
      ..drawLine(
        Offset(w * 0.05, h * 0.2),
        Offset(w * 0.95, h * 0.32),
        MoveraMapPalette.mainStreet(4),
      )
      ..drawLine(Offset(w * 0.3, 0), Offset(w * 0.42, h * 0.66), street)
      ..drawLine(Offset(w * 0.7, 0), Offset(w * 0.62, h * 0.78), street);
    MoveraMapPalette.drawHighway(
      canvas,
      Path()
        ..moveTo(0, h * 0.48)
        ..lineTo(w, h * 0.44),
      4,
    );
    final center = Offset(w * 0.52, h * 0.4);
    canvas
      ..drawCircle(center, h * 0.34, Paint()..color = const Color(0x33E0474C))
      ..drawCircle(
        center,
        h * 0.34,
        Paint()
          ..color = const Color(0xFFE0474C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(center, 5, Paint()..color = const Color(0xFFE0474C));
  }

  @override
  bool shouldRepaint(_AreaMapPainter oldDelegate) => false;
}
