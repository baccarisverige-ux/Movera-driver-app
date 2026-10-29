/// The status a document line shows (`contract.json#documentStatus`):
/// the stored one, with the contract v0.17.0 shown states on top. An
/// approved document from the admin's first warning day before its end
/// date is `expiring` (orange), after it `expired`; an admin_check
/// document (the info session) is `waiting_for_movera` until Movera marks
/// it (owner items 1, 3 and 8).
library;

import 'package:movera/core/contracts/driver_onboarding_rules.dart';

/// Whole days from [now] until [expiresAt], rounded up (0 = expired).
int documentDaysLeft(DateTime expiresAt, DateTime now) {
  final left = expiresAt.difference(now);
  if (left <= Duration.zero) return 0;
  return (left.inMinutes / Duration.minutesPerDay).ceil();
}

String shownDocumentStatus({
  required DocumentKind kind,
  required String stored,
  required DateTime now,
  DateTime? expiresAt,
  int? warnDays,
}) {
  switch (kind) {
    case DocumentKind.acceptance:
      return 'approved';
    case DocumentKind.adminCheck:
      return stored == 'approved' || stored == 'rejected'
          ? stored
          : 'waiting_for_movera';
    case DocumentKind.file:
      if (stored == 'missing') return 'needed';
      if (stored != 'approved' || expiresAt == null) return stored;
      final days = documentDaysLeft(expiresAt, now);
      if (days == 0) return 'expired';
      if (days <= (warnDays ?? 30)) return 'expiring';
      return 'approved';
  }
}
