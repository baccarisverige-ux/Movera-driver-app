import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/live/live_driver_services.dart';

/// One message on a support ticket (contract v0.9.0 `TicketMessage`).
class ServerTicketMessage {
  const ServerTicketMessage({
    required this.fromSupport,
    required this.text,
    this.adminName,
    this.supportName,
  });

  final bool fromSupport;
  final String text;
  final String? adminName;

  /// v0.18.15 (owner QO-2 "Agent first name"): the answering admin's first
  /// name only; never an e-mail.
  final String? supportName;
}

/// v0.18.15 (contract.json#supportDesk, owner QO-4): the same seven topics in
/// both apps; the server says which are on for the driver's country.
const supportTopics = <String>[
  'ride_dispute',
  'help',
  'lost_item',
  'payment',
  'account',
  'safety',
  'other',
];

/// The driver's own support ticket (contract v0.9.0 `SupportTicket`).
class ServerTicket {
  const ServerTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    this.messages = const <ServerTicketMessage>[],
    this.feedback,
  });

  final String id;
  final String subject;
  final String category;

  /// `open`, `pending` (Movera answered), `resolved` or `closed`.
  final String status;
  final List<ServerTicketMessage> messages;

  /// v0.18.15 (owner "Not rating only comment suggestions"): the driver's
  /// optional comment after the ticket was solved.
  final String? feedback;

  static ServerTicket fromJson(Map<String, dynamic> json) => ServerTicket(
    id: json['ticketId']?.toString() ?? '',
    subject: json['subject']?.toString() ?? '',
    category: json['category']?.toString() ?? '',
    status: json['status']?.toString() ?? 'open',
    feedback: (json['feedback'] as Map?)?['text']?.toString(),
    messages: [
      for (final item in (json['messages'] as List? ?? const []))
        if (item is Map)
          ServerTicketMessage(
            fromSupport: item['from'] == 'support',
            text: item['text']?.toString() ?? '',
            adminName: item['adminName']?.toString(),
            supportName: item['supportName']?.toString(),
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

  /// v0.18.15 (owner QO-1, chat-style): the driver writes again on the
  /// ticket; the answer is the ticket with every message.
  Future<ServerTicket> write(String ticketId, String text) async =>
      ServerTicket.fromJson(
        await _api.post(
          '/api/v1/support/tickets/${Uri.encodeComponent(ticketId)}/messages',
          body: {'text': text.trim()},
          idempotencyKey: 'ticket-msg-${ApiClient.randomKey()}',
        ),
      );

  /// v0.18.15: an optional comment once the ticket is solved (no stars).
  Future<ServerTicket> comment(String ticketId, String text) async =>
      ServerTicket.fromJson(
        await _api.post(
          '/api/v1/support/tickets/${Uri.encodeComponent(ticketId)}/feedback',
          body: {'text': text.trim()},
          idempotencyKey: 'ticket-fb-${ApiClient.randomKey()}',
        ),
      );

  /// v0.18.15: the topics that are on (contract order); all seven when the
  /// server is older or does not answer.
  Future<List<String>> topics() async {
    try {
      final answer = await _api.get('/api/v1/support/topics');
      final on = [
        for (final item in (answer['topics'] as List? ?? const []))
          if (supportTopics.contains(item)) item.toString(),
      ];
      return on.isEmpty ? supportTopics : on;
    } catch (_) {
      return supportTopics;
    }
  }
}
