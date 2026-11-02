import 'package:flutter/material.dart';
import 'package:movera/core/contracts/status_words.g.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/content/content_card.dart';
import 'package:movera/core/support/server_support_tickets.dart';

/// The live build's Support (contract v0.9.0, owner 2026-10-27): the driver
/// writes to Movera, Admin › Support answers, and the answer shows here.
class LiveSupportInbox extends StatefulWidget {
  const LiveSupportInbox({super.key, required this.tickets});

  final ServerSupportTickets tickets;

  @override
  State<LiveSupportInbox> createState() => _LiveSupportInboxState();
}

/// v0.10.4: the contract word (statusWords ticketStatus); an unknown code
/// reads as open.
String liveTicketStatus(String status) =>
    statusWord(tr, 'ticketStatus', status) ?? tr.swTicketStatusOpen;

class _LiveSupportInboxState extends State<LiveSupportInbox> {
  late Future<List<ServerTicket>> _list = widget.tickets.mine();

  void _reload() {
    setState(() {
      _list = widget.tickets.mine();
    });
  }

  Future<void> _write() async {
    // v0.18.15 (owner QO-4): the same seven topics as the rider app, as the
    // server has them on for the driver's country.
    final topics = await widget.tickets.topics();
    if (!mounted) return;
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WriteSheet(tickets: widget.tickets, categories: topics),
    );
    if (sent == true) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr.supportSentToMovera)));
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
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Contract v0.10.0 §19: the Content page's Help text.
        if (DriverContentStore.instance.help case final help?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DriverContentCard(item: help),
          ),
        Expanded(child: _tickets()),
      ],
    ),
  );

  Widget _tickets() => FutureBuilder<List<ServerTicket>>(
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
  );
}

/// A topic code (contract.json#support.categories) or an older saved
/// category (kept in English) in the driver's language.
String supportCategoryLabel(String category) => switch (category) {
  'ride_dispute' => tr.supportTopicRideDispute,
  'help' => tr.supportTopicHelp,
  'lost_item' => tr.supportTopicLostItem,
  'payment' => tr.supportTopicPayment,
  'account' => tr.supportTopicAccount,
  'safety' => tr.supportTopicSafety,
  'other' => tr.supportTopicOther,
  'Trip & rider' => tr.supportCatTripRider,
  'Wallet & payments' => tr.supportCatWallet,
  'Scheduled rides' => tr.scheduledRides,
  'Account & documents' => tr.supportCatAccount,
  'Technical issue' => tr.supportCatTechnical,
  'Something else' => tr.cancelReasonSomethingElse,
  _ => category,
};

/// v0.18.15 (owner QO-2 "Agent first name"): "`<first name>` · Movera Support",
/// or "Movera Support" without a name; never an e-mail.
String supportSenderLine(ServerTicketMessage message) {
  final name = message.supportName?.trim();
  return name == null || name.isEmpty || name.contains('@')
      ? tr.supportMovera
      : tr.supportAgentLine(name);
}

/// One ticket as a chat (owner QO-1): Movera's answers and the driver's
/// messages, and a box to write again while the ticket is not closed.
class _LiveTicket extends StatefulWidget {
  const _LiveTicket({required this.ticketId, required this.tickets});

  final String ticketId;
  final ServerSupportTickets tickets;

  @override
  State<_LiveTicket> createState() => _LiveTicketState();
}

class _LiveTicketState extends State<_LiveTicket> {
  late Future<ServerTicket> _ticket = widget.tickets.one(widget.ticketId);
  final _reply = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final next = await widget.tickets.write(widget.ticketId, text);
      _reply.clear();
      setState(() {
        _ticket = Future.value(next);
        _sending = false;
      });
    } catch (_) {
      setState(() {
        _sending = false;
        _error = tr.supportReplyFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr.support)),
    body: FutureBuilder<ServerTicket>(
      future: _ticket,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final ticket = snapshot.data;
        if (ticket == null) {
          return Center(child: Text(tr.supportCouldNotLoadRetry));
        }
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    ticket.subject,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
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
                                supportSenderLine(message),
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
              ),
            ),
            if (ticket.status == 'closed')
              Padding(
                key: const ValueKey<String>('live-ticket-closed'),
                padding: const EdgeInsets.all(16),
                child: Text(tr.supportTicketClosedNote),
              )
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const ValueKey<String>('live-ticket-reply'),
                              controller: _reply,
                              maxLength: 5000,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: tr.supportReplyHint,
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            key: const ValueKey<String>(
                              'live-ticket-reply-send',
                            ),
                            onPressed: _sending ? null : _send,
                            child: Text(tr.supportReplySend),
                          ),
                        ],
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
                      category: supportTopics.contains(_category)
                          ? _category
                          : ServerSupportTickets.categoryOf(_category),
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
