import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/scheduled/scheduled_clock.dart';

/// A new document sent for one that runs out.
enum DocumentRenewal { none, inReview }

/// A driver document with an end date (Q26).
@immutable
class TrackedDocument {
  const TrackedDocument({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.expiresOn,
    this.renewal = DocumentRenewal.none,
  });

  final String id;

  /// tr.docInsuranceLetter
  final String title;

  /// tr.insurance, for the island.
  final String shortTitle;
  final DateTime expiresOn;
  final DocumentRenewal renewal;

  bool get inReview => renewal == DocumentRenewal.inReview;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Whole days until the expiry day; 0 on it.
  int daysLeft(DateTime now) =>
      (_day(expiresOn).difference(_day(now)).inHours / 24).round();

  bool expiredAt(DateTime now) => daysLeft(now) <= 0;

  TrackedDocument copyWith({DateTime? expiresOn, DocumentRenewal? renewal}) =>
      TrackedDocument(
        id: id,
        title: title,
        shortTitle: shortTitle,
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
    final today = DateTime(now.year, now.month, now.day);
    return <TrackedDocument>[
      TrackedDocument(
        id: 'DOC-INS-418',
        title: tr.docInsuranceLetter,
        shortTitle: tr.insurance,
        expiresOn: today.add(const Duration(days: 7)),
      ),
      TrackedDocument(
        id: 'DOC-TAXI-418',
        title: tr.docTaxiDriverLicense,
        shortTitle: tr.docTaxiLicenseShort,
        expiresOn: today.add(const Duration(days: 214)),
      ),
      TrackedDocument(
        id: 'DOC-REG-418',
        title: tr.docRegistrationCertificate,
        shortTitle: tr.docRegistrationShort,
        expiresOn: today.add(const Duration(days: 320)),
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
      if (document.id == id) { return document; }
    }
    return null;
  }

  /// The first expired document; the driver can't go online while it is
  /// there, even with a new one in review.
  TrackedDocument? get blocking {
    if (!rule.blockOnExpiry) { return null; }
    final now = _now();
    for (final document in documents) {
      if (document.expiredAt(now)) { return document; }
    }
    return null;
  }

  /// Documents that need a new one: in a warning step or expired.
  List<TrackedDocument> get needingNew {
    final now = _now();
    return documents
        .where((d) =>
            d.expiredAt(now) || rule.warningFor(d.daysLeft(now)) != null)
        .toList();
  }

  /// Warnings not given yet, each step once. A document with a new one in
  /// review needs none.
  List<DocumentWarning> takeWarnings() {
    final now = _now();
    final due = <DocumentWarning>[];
    for (final document in documents) {
      if (document.inReview) { continue; }
      final days = document.daysLeft(now);
      final step = rule.warningFor(days);
      if (step == null || !_warned.add('${document.id}:$step')) { continue; }
      due.add(DocumentWarning(document, step, days));
    }
    return due;
  }

  /// The driver sent a new document; admin checks it.
  void uploadNew(String id) => _replace(
        id,
        (d) => d.copyWith(renewal: DocumentRenewal.inReview),
      );

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
    if (at < 0) { return; }
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
