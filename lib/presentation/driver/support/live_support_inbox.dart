import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/support/server_support_tickets.dart';

/// The live build's Support (contract v0.9.0, owner 2026-10-27): the driver
/// writes to Movera, Admin › Support answers, and the answer shows here.
class LiveSupportInbox extends StatefulWidget {
  const LiveSupportInbox({super.key, required this.tickets});

  final ServerSupportTickets tickets;

  @override
  State<LiveSupportInbox> createState() => _LiveSupportInboxState();
}

String liveTicketStatus(String status) => switch (status) {
  'pending' => tr.supportTicketAnswered,
  'resolved' => tr.supportTicketSolved,
  'closed' => tr.supportTicketClosed,
  _ => tr.supportTicketWaiting,
};

class _LiveSupportInboxState extends State<LiveSupportInbox> {
  late Future<List<ServerTicket>> _list = widget.tickets.mine();
  static const _categories = [
    'Trip & rider',
    'Wallet & payments',
    'Scheduled rides',
    'Account & documents',
    'Technical issue',
    'Something else',
  ];

  void _reload() {
    setState(() {
      _list = widget.tickets.mine();
    });
  }

  Future<void> _write() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _WriteSheet(tickets: widget.tickets, categories: _categories),
    );
    if (sent == true) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.supportSentToMovera)));
      }
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey<String>('live-support-inbox'),
    appBar: AppBar(title: Text(tr.support)),
    floatingActionButton: FloatingActionButton.extended(
      key: const ValueKey<String>('live-ticket-new'),
      onPressed: _write,
      icon: const Icon(Icons.add_rounded),
      label: Text(tr.supportWriteToMovera),
    ),
    body: FutureBuilder<List<ServerTicket>>(
      future: _list,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: _reload,
              child: Text(tr.supportCouldNotLoadRetry),
            ),
          );
        }
        final tickets = snapshot.data ?? const <ServerTicket>[];
        if (tickets.isEmpty) {
          return Center(child: Text(tr.supportNoTicketsYet));
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            for (final ticket in tickets)
              Card(
                child: ListTile(
                  key: ValueKey<String>('live-ticket-${ticket.id}'),
                  title: Text(ticket.subject),
                  subtitle: Text(liveTicketStatus(ticket.status)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _LiveTicket(
                        ticketId: ticket.id,
                        tickets: widget.tickets,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

/// A saved category (kept in English) in the driver's language.
String supportCategoryLabel(String category) => switch (category) {
  'Trip & rider' => tr.supportCatTripRider,
  'Wallet & payments' => tr.supportCatWallet,
  'Scheduled rides' => tr.scheduledRides,
  'Account & documents' => tr.supportCatAccount,
  'Technical issue' => tr.supportCatTechnical,
  'Something else' => tr.cancelReasonSomethingElse,
  _ => category,
};

class _LiveTicket extends StatelessWidget {
  const _LiveTicket({required this.ticketId, required this.tickets});

  final String ticketId;
  final ServerSupportTickets tickets;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr.support)),
    body: FutureBuilder<ServerTicket>(
      future: tickets.one(ticketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final ticket = snapshot.data;
        if (ticket == null) {
          return Center(child: Text(tr.supportCouldNotLoadRetry));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              ticket.subject,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(liveTicketStatus(ticket.status)),
            const SizedBox(height: 16),
            for (final message in ticket.messages)
              Align(
                alignment: message.fromSupport
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: message.fromSupport
                        ? const Color(0xFFF1F2F4)
                        : const Color(0xFF202A30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.fromSupport)
                        Text(
                          message.adminName ?? tr.supportTicketMovera,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        message.text,
                        style: TextStyle(
                          color: message.fromSupport
                              ? const Color(0xFF202A30)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _WriteSheet extends StatefulWidget {
  const _WriteSheet({required this.tickets, required this.categories});

  final ServerSupportTickets tickets;
  final List<String> categories;

  @override
  State<_WriteSheet> createState() => _WriteSheetState();
}

class _WriteSheetState extends State<_WriteSheet> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  late String _category = widget.categories.first;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey<String>('live-ticket-category'),
          initialValue: _category,
          decoration: InputDecoration(labelText: tr.category),
          items: [
            for (final item in widget.categories)
              DropdownMenuItem(
                value: item,
                child: Text(supportCategoryLabel(item)),
              ),
          ],
          onChanged: (value) => _category = value ?? _category,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('live-ticket-subject'),
          controller: _subject,
          maxLength: 200,
          decoration: InputDecoration(labelText: tr.subject),
        ),
        TextField(
          key: const ValueKey<String>('live-ticket-message'),
          controller: _message,
          maxLength: 5000,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(labelText: tr.message),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        FilledButton(
          key: const ValueKey<String>('live-ticket-send'),
          onPressed: _sending
              ? null
              : () async {
                  if (_subject.text.trim().isEmpty ||
                      _message.text.trim().isEmpty) {
                    setState(() => _error = tr.enterMessage);
                    return;
                  }
                  setState(() {
                    _sending = true;
                    _error = null;
                  });
                  try {
                    await widget.tickets.open(
                      category: ServerSupportTickets.categoryOf(_category),
                      subject: _subject.text,
                      text: _message.text,
                    );
                    if (mounted) Navigator.of(this.context).pop(true);
                  } catch (_) {
                    setState(() {
                      _sending = false;
                      _error = tr.supportSendFailed;
                    });
                  }
                },
          child: Text(tr.supportSendToMovera),
        ),
      ],
    ),
  );
}
