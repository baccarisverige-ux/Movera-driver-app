/// Contract v0.17.0 §25 (`contract.json#driverOnboarding.reminders`),
/// owner decisions of 2026-10-29, driver group 2 items 1, 2, 3, 8 and 9:
/// what the Home sheet "Important reminders (N)" shows, one line per issue
/// with tap-to-fix, from `GET /driver/reminders`. Red lines block going
/// online, orange ones are due soon (from the admin's first warning day,
/// 30 by default), the rest wait on Movera. The same list says why an
/// account that is not active cannot go online (group 1).
library;

import 'package:flutter/foundation.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

enum ReminderLevel {
  /// Red: going online is refused until it is fixed.
  blocksOnline,

  /// Orange: expires within the warning window, still works.
  dueSoon,

  /// Nothing to do; Movera acts next.
  waiting;

  static ReminderLevel of(Object? wire) => switch (wire) {
    'blocks_online' => blocksOnline,
    'due_soon' => dueSoon,
    _ => waiting,
  };
}

/// Where a tap on a line goes (`ReminderFix.target`).
enum ReminderFixTarget {
  /// The document's upload guide.
  document,

  /// "How to book your info session" (content slot driver-info-session).
  infoSession,

  /// My fleet › cars (the owner adds or finishes a car).
  fleetVehicles,

  /// The fleet's car list, to pick one.
  pickVehicle;

  static ReminderFixTarget? of(Object? wire) => switch (wire) {
    'document' => document,
    'info_session' => infoSession,
    'fleet_vehicles' => fleetVehicles,
    'pick_vehicle' => pickVehicle,
    _ => null,
  };
}

@immutable
class ReminderFix {
  const ReminderFix({
    required this.target,
    this.documentType,
    this.scope,
    this.vehicleId,
    this.contentSlot,
  });

  static ReminderFix? fromJson(Object? json) {
    if (json is! Map) return null;
    final target = ReminderFixTarget.of(json['target']);
    if (target == null) return null;
    return ReminderFix(
      target: target,
      documentType: _text(json['documentType']),
      scope: _text(json['scope']),
      vehicleId: _text(json['vehicleId']),
      contentSlot: _text(json['contentSlot']),
    );
  }

  final ReminderFixTarget target;
  final String? documentType;
  final String? scope;
  final String? vehicleId;
  final String? contentSlot;
}

/// `DriverReminder`.
@immutable
class DriverReminder {
  const DriverReminder({
    required this.kind,
    required this.level,
    this.scope,
    this.documentType,
    this.documentId,
    this.vehicleId,
    this.status,
    this.expiresAt,
    this.daysLeft,
    this.reviewNote,
    this.fix,
  });

  factory DriverReminder.fromJson(Map<String, dynamic> json) => DriverReminder(
    kind: _text(json['kind']) ?? '',
    level: ReminderLevel.of(json['level']),
    scope: _text(json['scope']),
    documentType: _text(json['documentType']),
    documentId: _text(json['documentId']),
    vehicleId: _text(json['vehicleId']),
    status: _text(json['status']),
    expiresAt: json['expiresAt'] is String
        ? DateTime.tryParse(json['expiresAt'] as String)?.toUtc()
        : null,
    daysLeft: json['daysLeft'] is num
        ? (json['daysLeft'] as num).toInt()
        : null,
    reviewNote: _text(json['reviewNote']),
    fix: ReminderFix.fromJson(json['fix']),
  );

  /// `document_needed`, `document_expiring`, `fleet_no_approved_car`, …
  final String kind;
  final ReminderLevel level;

  /// `driver`, `fleet` or `vehicle`.
  final String? scope;
  final String? documentType;
  final String? documentId;
  final String? vehicleId;

  /// The shown document state, e.g. `waiting_for_movera`.
  final String? status;
  final DateTime? expiresAt;
  final int? daysLeft;
  final String? reviewNote;
  final ReminderFix? fix;

  bool get blocksOnline => level == ReminderLevel.blocksOnline;
}

/// `DriverReminderList`, in the server's order (red, orange, waiting).
@immutable
class DriverReminderList {
  const DriverReminderList(this.items);

  static const empty = DriverReminderList([]);

  factory DriverReminderList.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = [
      if (raw is List)
        for (final row in raw)
          if (row is Map)
            DriverReminder.fromJson(Map<String, dynamic>.from(row)),
    ];
    // The server sends them in order; keep the levels together anyway.
    final ordered = [
      for (final level in ReminderLevel.values)
        for (final item in items)
          if (item.level == level) item,
    ];
    return DriverReminderList(ordered);
  }

  final List<DriverReminder> items;

  /// Owner decision 19: car-document lines are the fleet owner's; a member
  /// driver gets none (the server also leaves them out).
  DriverReminderList forViewer({required bool owner}) => owner
      ? this
      : DriverReminderList([
          for (final item in items)
            if (item.scope != 'vehicle') item,
        ]);

  int get count => items.length;
  bool get isEmpty => items.isEmpty;

  /// Lines with level blocks_online.
  int get blocksOnline => items.where((item) => item.blocksOnline).length;

  DriverReminder? get firstBlocking {
    for (final item in items) {
      if (item.blocksOnline) return item;
    }
    return null;
  }
}

/// The Home sheet's reminders for the session: read when Home opens, comes
/// back on top, the app returns or a document goes up; the last list stays
/// when a read fails. The demo never reads it (empty).
class DriverRemindersStore extends ChangeNotifier {
  DriverRemindersStore();

  static DriverRemindersStore instance = DriverRemindersStore();

  DriverReminderList _list = DriverReminderList.empty;
  Future<DriverReminderList>? _loading;
  bool _loaded = false;

  DriverReminderList get list => _list;
  List<DriverReminder> get items => _list.items;

  /// True once a list came from the server.
  bool get loaded => _loaded;

  /// True while a red line keeps the driver offline.
  bool get blocksOnline => _list.blocksOnline > 0;

  DriverReminder? get firstBlocking => _list.firstBlocking;

  /// One read at a time.
  Future<DriverReminderList> refresh(
    Future<DriverReminderList> Function() load,
  ) {
    final active = _loading;
    if (active != null) return active;
    final pending = load().then(replace);
    _loading = pending;
    pending.whenComplete(() {
      if (identical(_loading, pending)) _loading = null;
    }).ignore();
    return pending;
  }

  DriverReminderList replace(DriverReminderList list) {
    _list = list;
    _loaded = true;
    notifyListeners();
    return list;
  }

  void clear() {
    _list = DriverReminderList.empty;
    _loaded = false;
    notifyListeners();
  }
}

/// One line's words: what is wrong and, when there is a fix, the button.
@immutable
class ReminderWords {
  const ReminderWords(this.title, {this.detail, this.action});

  final String title;
  final String? detail;
  final String? action;
}

/// The words of [reminder]. [nameOf] names a document type in the app's
/// language (the admin's texts, custom types included); [carName] names
/// a car by its id ("ABC 123"), null when unknown; [owner] is the fleet
/// owner (the fleet_no_approved_car fix is his).
ReminderWords reminderWords(
  DriverReminder reminder, {
  required String Function(String type) nameOf,
  String? Function(String vehicleId)? carName,
  bool owner = false,
}) {
  final type = reminder.documentType;
  var document = type == null ? tr.documents : nameOf(type);
  final vehicleId = reminder.vehicleId;
  if (reminder.scope == 'vehicle' && vehicleId != null) {
    final car = carName?.call(vehicleId);
    if (car != null && car.isNotEmpty) document = tr.remDocOfCar(document, car);
  }
  return switch (reminder.kind) {
    'document_needed' => ReminderWords(
      tr.remDocumentNeeded(document),
      action: tr.remUpload,
    ),
    'document_rejected' => ReminderWords(
      tr.remDocumentRejected(document),
      detail: reminder.reviewNote,
      action: tr.remUploadNew,
    ),
    'document_expired' => ReminderWords(
      tr.remDocumentExpired(document),
      detail: reminder.blocksOnline ? tr.remCantGoOnlineUntil : null,
      action: tr.remUploadNew,
    ),
    'document_expiring' => ReminderWords(
      tr.remDocumentExpiring(document, _daysLabel(reminder.daysLeft ?? 0)),
      action: tr.remUploadNew,
    ),
    'document_in_review' => ReminderWords(tr.remDocumentInReview(document)),
    'info_session_waiting' => ReminderWords(
      document,
      detail: tr.swDocumentStatusWaitingForMovera,
      action: tr.infoHowToBookShort,
    ),
    'admin_check_waiting' => ReminderWords(
      document,
      detail: tr.swDocumentStatusWaitingForMovera,
    ),
    'account_not_active' => ReminderWords(
      tr.remAccountNotActive,
      detail: tr.remAccountNotActiveDetail,
    ),
    'fleet_not_approved' => ReminderWords(tr.remFleetNotApproved),
    'fleet_no_approved_car' => ReminderWords(
      tr.remFleetNoApprovedCar,
      detail: owner
          ? tr.remFleetNoApprovedCarOwner
          : tr.remFleetNoApprovedCarMember,
      action: reminder.fix == null ? null : tr.myFleet,
    ),
    'no_vehicle' => ReminderWords(tr.remNoVehicle, action: tr.fleetChooseCar),
    _ => ReminderWords(
      document,
      action: reminder.fix == null ? null : tr.remOpen,
    ),
  };
}

/// "in 12 days", "tomorrow", "today".
String _daysLabel(int days) => switch (days) {
  <= 0 => tr.todayLower,
  1 => tr.tomorrowLower,
  _ => tr.inDaysCount(days),
};
