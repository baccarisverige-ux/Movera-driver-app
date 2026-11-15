/// BQ-V34 (contract v0.18.101 `contract.json#sosContactsSms`, CONTRACT.md
/// §92; owner 2026-11-02 Q2 "Use them in SOS (Recommended)", Rules
/// decisions/driver-g14.md:12): the driver's SOS texts his emergency
/// contacts. Both fields are optional: a server without them gives the old
/// "SOS sent" and no line on the contacts screen.
library;

/// `SosContactsSms.status`.
enum SosContactsSmsStatus {
  off,
  noContacts,
  notConnected,
  queued,
  sent,
  failed,
}

/// `SosReceipt.contactsSms`: what happened to the SMS to the driver's
/// emergency contacts on this SOS.
class SosContactsSms {
  const SosContactsSms({
    required this.status,
    required this.contacts,
    this.sent,
  });

  static const _statuses = {
    'off': SosContactsSmsStatus.off,
    'no_contacts': SosContactsSmsStatus.noContacts,
    'not_connected': SosContactsSmsStatus.notConnected,
    'queued': SosContactsSmsStatus.queued,
    'sent': SosContactsSmsStatus.sent,
    'failed': SosContactsSmsStatus.failed,
  };

  final SosContactsSmsStatus status;

  /// Number of SMS asked for (0 or more).
  final int contacts;

  /// Accepted by the SMS company (only for sent / failed).
  final int? sent;

  /// An unknown status or a bad count is null (no line is shown).
  static SosContactsSms? fromJson(Object? json) {
    if (json is! Map) return null;
    final status = _statuses[json['status']];
    final contacts = json['contacts'];
    if (status == null || contacts is! int || contacts < 0) return null;
    final sent = json['sent'];
    return SosContactsSms(
      status: status,
      contacts: contacts,
      sent: sent is int && sent >= 0 ? sent : null,
    );
  }
}

/// `DriverAppConfig.sosContactsSms { on, connected }`: the zone country's
/// switch, and whether an SMS company is connected on the server. The app
/// promises an SMS only when both are true.
class SosContactsSmsConfig {
  const SosContactsSmsConfig({required this.on, required this.connected});

  final bool on;
  final bool connected;

  bool get promised => on && connected;

  /// Null until a served document carried the field.
  static SosContactsSmsConfig? current;

  static SosContactsSmsConfig? parse(Object? json) {
    if (json is! Map) return null;
    final on = json['on'];
    final connected = json['connected'];
    if (on is! bool || connected is! bool) return null;
    return SosContactsSmsConfig(on: on, connected: connected);
  }

  /// Takes a served value when valid; otherwise the kept one stays (like
  /// EmergencyNumbers.accept).
  static void accept(Object? json) {
    final value = parse(json);
    if (value != null) current = value;
  }

  /// Another country / tests: back to "never received".
  static void reset() => current = null;
}
