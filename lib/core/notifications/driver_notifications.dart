import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

/// Admin's notification groups (Q31): N1 ride alerts, N2 demand and
/// events, N3 account and money.
enum DriverNoticeGroup { rideAlerts, demand, account }

enum DriverNoticeKind {
  newScheduledRide(DriverNoticeGroup.rideAlerts),
  exclusiveOffer(DriverNoticeGroup.rideAlerts),
  scheduledReminder(DriverNoticeGroup.rideAlerts),
  leaveNow(DriverNoticeGroup.rideAlerts),
  highDemand(DriverNoticeGroup.demand),
  event(DriverNoticeGroup.demand),
  documentExpiring(DriverNoticeGroup.account),
  documentApproved(DriverNoticeGroup.account),
  restOver(DriverNoticeGroup.account),
  scheduledPaused(DriverNoticeGroup.account),
  payoutSent(DriverNoticeGroup.account),
  bonusProgress(DriverNoticeGroup.account);

  const DriverNoticeKind(this.group);

  final DriverNoticeGroup group;
}

/// What a notification's button does.
enum DriverNoticeAction { viewScheduledRides, uploadDocument }

/// The area of a demand notification, drawn as a small map.
@immutable
class DemandArea {
  const DemandArea({required this.name, required this.center, this.radiusKm = 2});

  final String name;
  final GeoPoint center;
  final double radiusKm;
}

/// One notification for the driver (Q31).
@immutable
class DriverNotice {
  const DriverNotice({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.island,
    this.action,
    this.actionLabel,
    this.documentId,
    this.area,
  });

  final String id;
  final DriverNoticeKind kind;

  /// "High demand in Stockholm City"
  final String title;

  /// tr.noticeGoOnlineNow
  final String body;
  final DateTime at;

  /// The few words of its island popup, e.g. "High demand · City".
  final String? island;
  final DriverNoticeAction? action;

  /// tr.uploadNew
  final String? actionLabel;

  /// The document a document notification is about.
  final String? documentId;
  final DemandArea? area;

  DriverNoticeGroup get group => kind.group;
}

/// Admin's switches for each kind (Q31): a kind that is off never
/// reaches the driver.
class DriverNoticeRules {
  const DriverNoticeRules({this.off = const <DriverNoticeKind>{}});

  static DriverNoticeRules current = const DriverNoticeRules();

  final Set<DriverNoticeKind> off;

  bool allows(DriverNoticeKind kind) => !off.contains(kind);
}

/// The notifications this driver got, newest first, and the popups the
/// island still has to show. Popups reach drivers who are offline too. A
/// backend pushes them; the demo adds them here.
class DriverNotificationFeed {
  DriverNotificationFeed({DateTime Function()? now})
      : _now = now ?? (() => ScheduledClock.realNow());

  static final DriverNotificationFeed instance = DriverNotificationFeed();

  final DateTime Function() _now;
  List<DriverNotice>? _items;
  final Set<String> _read = <String>{};
  final List<DriverNotice> _popups = <DriverNotice>[];
  final ValueNotifier<int> _changes = ValueNotifier<int>(0);
  int _seq = 0;

  /// Notifications that arrive while the app is open, after the time
  /// given. Home starts them; tests and other builds set none.
  List<(Duration, DriverNotice Function(DateTime now))> arrivals =
      DriverNotices.demoArrivals;

  ValueListenable<int> get changes => _changes;

  /// The arrivals to start, once per app run.
  List<(Duration, DriverNotice Function(DateTime now))> takeArrivals() {
    final out = arrivals;
    arrivals = const [];
    return out;
  }

  DateTime get now => _now();

  List<DriverNotice> get items =>
      List.unmodifiable(_items ??= DriverNotices.demoReceived(_now()));

  int get unread => items.where((n) => !_read.contains(n.id)).length;

  bool isRead(DriverNotice notice) => _read.contains(notice.id);

  /// A new id, e.g. for a notification made on this phone.
  String nextId(String prefix) => '$prefix-${++_seq}';

  /// Adds [notice] unless admin turned its kind off. With [popup] the
  /// island shows it too; ride alerts the island already shows are added
  /// without.
  bool add(DriverNotice notice, {bool popup = true}) {
    if (!DriverNoticeRules.current.allows(notice.kind)) { return false; }
    _items = <DriverNotice>[notice, ...items];
    if (popup && notice.island != null) { _popups.add(notice); }
    _changes.value++;
    return true;
  }

  /// Popups waiting for the island, removed from the queue.
  List<DriverNotice> takePopups() {
    final out = List<DriverNotice>.of(_popups);
    _popups.clear();
    return out;
  }

  void markAllRead() {
    if (unread == 0) { return; }
    _read.addAll(items.map((n) => n.id));
    _changes.value++;
  }

  /// Replaces the list, e.g. from a backend.
  void load(List<DriverNotice> notices) {
    _items = List<DriverNotice>.of(notices);
    _read.clear();
    _popups.clear();
    _changes.value++;
  }

  /// Back to the demo list at the next reading.
  void reset() {
    _items = null;
    _read.clear();
    _popups.clear();
    arrivals = DriverNotices.demoArrivals;
    _changes.value++;
  }
}

/// The notifications the app makes, in admin's default words.
class DriverNotices {
  DriverNotices._();

  static DriverNotificationFeed get _feed => DriverNotificationFeed.instance;

  static const DemandArea stockholmCity = DemandArea(
    name: 'Stockholm City',
    center: GeoPoint(59.3326, 18.0649),
    radiusKm: 1.6,
  );

  /// N1: "New scheduled ride · Tomorrow 07:40 · 126 kr · Tap to view".
  static DriverNotice newScheduledRide({
    required DateTime at,
    required String day,
    required String time,
    required String fare,
  }) =>
      DriverNotice(
        id: _feed.nextId('scheduled'),
        kind: DriverNoticeKind.newScheduledRide,
        title: tr.noticeNewScheduledRide,
        body: tr.noticeScheduledBody(day, time, fare),
        at: at,
        island: driverText(DriverTexts.islandNewReservation),
        action: DriverNoticeAction.viewScheduledRides,
        actionLabel: tr.view,
      );

  /// N1: "Exclusive offer · 8 s to accept".
  static DriverNotice exclusiveOffer({required DateTime at, required int seconds}) =>
      DriverNotice(
        id: _feed.nextId('exclusive'),
        kind: DriverNoticeKind.exclusiveOffer,
        title: tr.exclusiveOffer,
        body: tr.noticeSecondsToAccept(seconds),
        at: at,
        island: driverText(DriverTexts.islandExclusiveRide),
      );

  /// N1: a reminder before a scheduled pickup, or "Leave now".
  static DriverNotice scheduledReminder({
    required DateTime at,
    required String title,
    required String body,
    bool leaveNow = false,
  }) =>
      DriverNotice(
        id: _feed.nextId('reminder'),
        kind: leaveNow
            ? DriverNoticeKind.leaveNow
            : DriverNoticeKind.scheduledReminder,
        title: title,
        body: body,
        at: at,
        island: title,
        action: DriverNoticeAction.viewScheduledRides,
        actionLabel: tr.view,
      );

  /// N2: "High demand in Stockholm City · Go online now", with a map.
  static DriverNotice highDemand(DateTime at, {DemandArea area = stockholmCity}) =>
      DriverNotice(
        id: _feed.nextId('demand'),
        kind: DriverNoticeKind.highDemand,
        title: tr.noticeHighDemandIn(area.name),
        body: tr.noticeGoOnlineNow,
        at: at,
        island: driverText(DriverTexts.islandHighDemand, {
          'area': area.name.replaceFirst('Stockholm ', ''),
        }),
        area: area,
      );

  /// N2: an event message from admin.
  static DriverNotice event(
    DateTime at, {
    required String title,
    required String body,
    required String island,
  }) =>
      DriverNotice(
        id: _feed.nextId('event'),
        kind: DriverNoticeKind.event,
        title: title,
        body: body,
        at: at,
        island: island,
      );

  /// N3: a document runs out in [daysLeft] days.
  static DriverNotice documentExpiring(
    DateTime at, {
    required String documentId,
    required String title,
    required String shortTitle,
    required String when,
  }) =>
      DriverNotice(
        id: _feed.nextId('document'),
        kind: DriverNoticeKind.documentExpiring,
        title: tr.noticeDocExpires(title, when),
        body: tr.noticeUploadNewKeepDriving,
        at: at,
        island: driverText(DriverTexts.islandDocumentExpires, {
          'document': shortTitle,
          'when': when,
        }),
        action: DriverNoticeAction.uploadDocument,
        actionLabel: tr.uploadNew,
        documentId: documentId,
      );

  /// N3: admin approved the new document.
  static DriverNotice documentApproved(DateTime at, {required String title}) =>
      DriverNotice(
        id: _feed.nextId('document'),
        kind: DriverNoticeKind.documentApproved,
        title: tr.islandDocumentApproved,
        body: tr.noticeDocApprovedBody(title),
        at: at,
        island: driverText(DriverTexts.islandDocumentApproved),
      );

  /// N3: the rest after the driving limit is over.
  static DriverNotice restOver(DateTime at) => DriverNotice(
        id: _feed.nextId('rest'),
        kind: DriverNoticeKind.restOver,
        title: tr.islandRestOver,
        body: tr.noticeCanGoOnlineAgain,
        at: at,
        island: driverText(DriverTexts.islandRestOver),
      );

  /// N3: too many late cancels paused Scheduled rides.
  static DriverNotice scheduledPaused(DateTime at, {required String until}) =>
      DriverNotice(
        id: _feed.nextId('paused'),
        kind: DriverNoticeKind.scheduledPaused,
        title: tr.islandScheduledPaused,
        body: tr.noticeTooManyLateCancels(until),
        at: at,
        island: driverText(DriverTexts.islandScheduledPaused),
        action: DriverNoticeAction.viewScheduledRides,
        actionLabel: tr.view,
      );

  /// Already received when the demo opens.
  static List<DriverNotice> demoReceived(DateTime now) => <DriverNotice>[
        DriverNotice(
          id: 'demo-scheduled-0740',
          kind: DriverNoticeKind.newScheduledRide,
          title: tr.noticeNewScheduledRide,
          body: 'Tomorrow 07:40 · 126 kr · Tap to view',
          at: now.subtract(const Duration(minutes: 18)),
          action: DriverNoticeAction.viewScheduledRides,
          actionLabel: tr.view,
        ),
        DriverNotice(
          id: 'demo-bonus',
          kind: DriverNoticeKind.bonusProgress,
          title: 'Bonus progress',
          body: '18 of 25 trips this week. 7 more for 350 kr.',
          at: now.subtract(const Duration(hours: 3)),
        ),
        DriverNotice(
          id: 'demo-payout',
          kind: DriverNoticeKind.payoutSent,
          title: 'Payout sent',
          body: '2 450,00 kr is on its way to your bank.',
          at: now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ];

  /// Arrive while the demo is open: busy City, then an event.
  static final List<(Duration, DriverNotice Function(DateTime now))>
      demoArrivals = <(Duration, DriverNotice Function(DateTime now))>[
    (const Duration(seconds: 20), highDemand),
    (
      const Duration(seconds: 50),
      (now) => event(
            now,
            title: 'Stockholm evening demand',
            body: '18:00–22:30 · Central Stockholm. Be online before the '
                'main departure window.',
            island: 'Event tonight · City',
          ),
    ),
  ];
}
