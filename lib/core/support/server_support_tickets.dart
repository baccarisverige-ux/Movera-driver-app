import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// One message on a support ticket (contract v0.9.0 `TicketMessage`).
class ServerTicketMessage {
  const ServerTicketMessage({
    required this.fromSupport,
    required this.text,
    this.adminName,
  });

  final bool fromSupport;
  final String text;
  final String? adminName;
}

/// The driver's own support ticket (contract v0.9.0 `SupportTicket`).
class ServerTicket {
  const ServerTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    this.messages = const <ServerTicketMessage>[],
  });

  final String id;
  final String subject;
  final String category;

  /// `open`, `pending` (Movera answered), `resolved` or `closed`.
  final String status;
  final List<ServerTicketMessage> messages;

  static ServerTicket fromJson(Map<String, dynamic> json) => ServerTicket(
    id: json['ticketId']?.toString() ?? '',
    subject: json['subject']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    status: json['status']?.toString() ?? 'open',
    messages: [
      for (final item in (json['messages'] as List? ?? const []))
        if (item is Map)
          ServerTicketMessage(
            fromSupport: item['from'] == 'support',
            text: item['text']?.toString() ?? '',
            adminName: item['adminName']?.toString(),
          ),
    ],
  );
}

/// Contract v0.9.0 §16 (owner, 2026-10-27): the driver's help requests are
/// support tickets on movera-server; Admin › Support answers them and the
/// driver reads the answer here.
class ServerSupportTickets {
  ServerSupportTickets({required ApiClient api}) : _api = api;

  /// The live build's tickets; null in the demo (local drafts only).
  static ServerSupportTickets? fromApp() {
    final api = LiveDriverServices.instance?.api;
    return api == null ? null : ServerSupportTickets(api: api);
  }

  final ApiClient _api;

  /// The driver app's support categories (kept in English in the drafts)
  /// as `contract.json#support.categories`.
  static String categoryOf(String appCategory) => switch (appCategory) {
    'Wallet & payments' => 'payment',
    'Account & documents' => 'account',
    'Something else' => 'other',
    _ => 'help',
  };

  Future<ServerTicket> open({
    required String category,
    required String subject,
    required String text,
  }) async {
    final answer = await _api.post(
      '/api/v1/support/tickets',
      body: {
        'category': category,
        'subject': subject.trim(),
        'text': text.trim(),
      },
      idempotencyKey: 'ticket-${ApiClient.randomKey()}',
    );
    return ServerTicket.fromJson(answer);
  }

  Future<List<ServerTicket>> mine() async {
    final page = await _api.get('/api/v1/support/tickets?limit=50');
    return [
      for (final item in (page['items'] as List? ?? const []))
        if (item is Map) ServerTicket.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<ServerTicket> one(String ticketId) async => ServerTicket.fromJson(
    await _api.get('/api/v1/support/tickets/${Uri.encodeComponent(ticketId)}'),
  );
}
