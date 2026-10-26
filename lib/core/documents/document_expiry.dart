import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

/// A new document sent for one that runs out.
enum DocumentRenewal { none, inReview }

/// A driver document with an end date (Q26).
@immutable
class TrackedDocument {
  /// A document whose names are already in the driver's words, e.g. from
  /// a backend.
  TrackedDocument({
    required String id,
    required String title,
    required String shortTitle,
    required DateTime expiresOn,
    DocumentRenewal renewal = DocumentRenewal.none,
  }) : this.named(
         id: id,
         title: () => title,
         shortTitle: () => shortTitle,
         expiresOn: expiresOn,
         renewal: renewal,
       );

  /// A document whose names the app writes, read in the driver's language
  /// each time (driver-13: the demo list outlives a language switch).
  const TrackedDocument.named({
    required this.id,
    required String Function() title,
    required String Function() shortTitle,
    required this.expiresOn,
    this.renewal = DocumentRenewal.none,
  }) : _title = title,
       _shortTitle = shortTitle;

  final String id;
  final String Function() _title;
  final String Function() _shortTitle;

  /// tr.docInsuranceLetter
  String get title => _title();

  /// tr.insurance, for the island.
  String get shortTitle => _shortTitle();
  final DateTime expiresOn;
  final DocumentRenewal renewal;

  bool get inReview => renewal == DocumentRenewal.inReview;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Whole days until the expiry day; 0 on it.
  int daysLeft(DateTime now) =>
      (_day(expiresOn).difference(_day(now)).inHours / 24).round();

  bool expiredAt(DateTime now) => daysLeft(now) <= 0;

  TrackedDocument copyWith({DateTime? expiresOn, DocumentRenewal? renewal}) =>
      TrackedDocument.named(
        id: id,
        title: _title,
        shortTitle: _shortTitle,
        expiresOn: expiresOn ?? this.expiresOn,
        renewal: renewal ?? this.renewal,
      );
}

/// A warning due for [document]: the admin's step ([step], e.g. 7) and
/// the real [daysLeft].
@immutable
class DocumentWarning {
  const DocumentWarning(this.document, this.step, this.daysLeft);

  final TrackedDocument document;
  final int step;
  final int daysLeft;
}

/// The driver's documents that run out (Q26): warnings on the admin's
/// days before expiry, and on the expiry day no going online until admin
/// approves the new one. A backend sends the documents; the demo keeps
/// them here.
class DocumentExpiryStore {
  DocumentExpiryStore({DateTime Function()? now, List<TrackedDocument>? seed})
    : _now = now ?? (() => ScheduledClock.realNow()),
      _seed = seed;

  static final DocumentExpiryStore instance = DocumentExpiryStore();

  final DateTime Function() _now;
  final List<TrackedDocument>? _seed;
  List<TrackedDocument>? _documents;
  final Set<String> _warned = <String>{};
  final ValueNotifier<int> _changes = ValueNotifier<int>(0);

  ValueListenable<int> get changes => _changes;

  DocumentExpiryRule get rule => DriverAccountRules.current.documents;

  DateTime get now => _now();

  /// The demo: the insurance letter ends in 7 days, the others later.
  static List<TrackedDocument> demo(DateTime now) {
    // Calendar days, not 24 h steps: a clock change on the way would end
    // a step at 23:00 the day before (driver-r4-12).
    DateTime inDays(int days) => DateTime(now.year, now.month, now.day + days);
    return <TrackedDocument>[
      TrackedDocument.named(
        id: 'DOC-INS-418',
        title: () => tr.docInsuranceLetter,
        shortTitle: () => tr.insurance,
        expiresOn: inDays(7),
      ),
      TrackedDocument.named(
        id: 'DOC-TAXI-418',
        title: () => tr.docTaxiDriverLicense,
        shortTitle: () => tr.docTaxiLicenseShort,
        expiresOn: inDays(214),
      ),
      TrackedDocument.named(
        id: 'DOC-REG-418',
        title: () => tr.docRegistrationCertificate,
        shortTitle: () => tr.docRegistrationShort,
        expiresOn: inDays(320),
      ),
    ];
  }

  List<TrackedDocument> get documents =>
      List.unmodifiable(_documents ??= _seed ?? demo(_now()));

  /// Replaces the documents, e.g. from a backend.
  void load(List<TrackedDocument> documents) {
    _documents = List<TrackedDocument>.of(documents);
    _warned.clear();
    _changes.value++;
  }

  TrackedDocument? byId(String id) {
    for (final document in documents) {
      if (document.id == id) {
        return document;
      }
    }
    return null;
  }

  /// The first expired document; the driver can't go online while it is
  /// there, even with a new one in review.
  TrackedDocument? get blocking {
    if (!rule.blockOnExpiry) {
      return null;
    }
    final now = _now();
    for (final document in documents) {
      if (document.expiredAt(now)) {
        return document;
      }
    }
    return null;
  }

  /// Documents that need a new one: in a warning step or expired.
  List<TrackedDocument> get needingNew {
    final now = _now();
    return documents
        .where(
          (d) => d.expiredAt(now) || rule.warningFor(d.daysLeft(now)) != null,
        )
        .toList();
  }

  /// Warnings not given yet, each step once. A document with a new one in
  /// review needs none.
  List<DocumentWarning> takeWarnings() {
    final now = _now();
    final due = <DocumentWarning>[];
    for (final document in documents) {
      if (document.inReview) {
        continue;
      }
      final days = document.daysLeft(now);
      final step = rule.warningFor(days);
      if (step == null || !_warned.add('${document.id}:$step')) {
        continue;
      }
      due.add(DocumentWarning(document, step, days));
    }
    return due;
  }

  /// The driver sent a new document; admin checks it.
  void uploadNew(String id) =>
      _replace(id, (d) => d.copyWith(renewal: DocumentRenewal.inReview));

  /// Demo of the admin's approval: the new document runs for a year.
  void approve(String id) {
    final now = _now();
    _warned.removeWhere((key) => key.startsWith('$id:'));
    _replace(
      id,
      (d) => d.copyWith(
        expiresOn: DateTime(now.year + 1, now.month, now.day),
        renewal: DocumentRenewal.none,
      ),
    );
  }

  void _replace(String id, TrackedDocument Function(TrackedDocument) change) {
    final list = List<TrackedDocument>.of(documents);
    final at = list.indexWhere((d) => d.id == id);
    if (at < 0) {
      return;
    }
    list[at] = change(list[at]);
    _documents = list;
    _changes.value++;
  }

  /// Back to the demo documents at the next reading.
  void reset() {
    _documents = null;
    _warned.clear();
    _changes.value++;
  }
}

/// "in 7 days", "tomorrow", "today".
String expiresInLabel(int daysLeft) => switch (daysLeft) {
  <= 0 => tr.todayLower,
  1 => tr.tomorrowLower,
  _ => tr.inDaysCount(daysLeft),
};
