import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

import 'dart:async';

import 'package:movera/core/support/local_support_repository.dart';
import 'package:movera/core/support/server_support_tickets.dart';
import 'package:movera/presentation/driver/support/live_support_inbox.dart';
import 'package:flutter/material.dart';

class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key, this.repository});
  final LocalSupportRepository? repository;
  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

/// Live builds send support messages to the server as tickets (contract v0.9.0 §16); the demo keeps the local inbox.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, this.repository, this.tickets});
  final LocalSupportRepository? repository;
  final ServerSupportTickets? tickets;
  @override
  Widget build(BuildContext context) {
    final live = repository == null
        ? tickets ?? ServerSupportTickets.fromApp()
        : null;
    return live != null
        ? LiveSupportInbox(tickets: live)
        : SupportInboxScreen(repository: repository);
  }
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  final List<_Ticket> tickets = [];
  late final _repository = widget.repository ?? LocalSupportRepository();
  bool _restoreFailed = false;
  bool _loading = true;
  bool _opening = false;
  bool _restoring = false;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore({bool recover = false}) async {
    if (_restoring || !mounted) {
      return;
    }
    _restoring = true;
    setState(() => _loading = true);
    try {
      if (recover) {
        await _repository.recover();
        if (!mounted) {
          return;
        }
      }
      final data = await _repository.read();
      if (!mounted) {
        return;
      }
      final restored = <_Ticket>[];
      for (final row in (data['tickets'] as List? ?? [])) {
        if (row is Map) {
          final ticket = _Ticket.fromJson(Map<String, dynamic>.from(row));
          if (ticket != null) {
            restored.add(ticket);
          }
        }
      }
      setState(() {
        tickets
          ..clear()
          ..addAll(restored);
        _restoreFailed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _restoreFailed = true);
        if (recover && ModalRoute.of(context)?.isCurrent == true) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tr.supportCouldNotRecover)));
        }
      }
    } finally {
      _restoring = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _recover() => _restore(recover: true);

  Future<void> _saveTickets() async {
    try {
      await _repository.update(
        'tickets',
        tickets.map((t) => t.toJson()).toList(),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr.supportCouldNotSaveConversation)),
        );
      }
      rethrow;
    }
  }

  Future<void> _newTicket() async {
    if (_opening ||
        _loading ||
        _restoreFailed ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _opening = true);
    try {
      await _createTicket();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _createTicket() async {
    if (_loading) {
      return;
    }
    Map<String, dynamic> data;
    try {
      data = await _repository.read();
    } catch (_) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.supportCouldNotLoadDraft),
            action: SnackBarAction(label: tr.retry, onPressed: _newTicket),
          ),
        );
      }
      return;
    }
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final draft = data['draft'] is Map
        ? data['draft'] as Map
        : <String, dynamic>{};
    final subject = TextEditingController(
      text: draft['subject'] as String? ?? '',
    );
    final message = TextEditingController(
      text: draft['message'] as String? ?? '',
    );
    const categories = [
      'Trip & rider',
      'Wallet & payments',
      'Scheduled rides',
      'Account & documents',
      'Technical issue',
      'Something else',
    ];
    String category = categories.contains(draft['category'])
        ? draft['category'] as String
        : 'Trip & rider';
    // driver-r4-25: keystrokes during a write coalesce into one more write,
    // and a failure says so once until a save works again.
    Future<void>? draftWrite;
    var draftDirty = false;
    var draftFailed = false;
    Future<void> saveDraft() {
      draftDirty = true;
      return draftWrite ??= () async {
        while (draftDirty) {
          draftDirty = false;
          try {
            await _repository.update('draft', {
              'subject': subject.text,
              'message': message.text,
              'category': category,
            });
            draftFailed = false;
          } catch (_) {
            if (!draftFailed && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr.supportCouldNotSaveDraft)),
              );
            }
            draftFailed = true;
          }
        }
        draftWrite = null;
      }();
    }

    subject.addListener(() {
      unawaited(saveDraft());
    });
    message.addListener(() {
      unawaited(saveDraft());
    });
    bool attempted = false;
    bool saving = false;
    String? saveError;
    final created = await showModalBottomSheet<_Ticket>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _DraftFormLifetime(
        controllers: [subject, message],
        child: StatefulBuilder(
          builder: (context, setSheetState) => PopScope(
            canPop: !saving,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD2D8DC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          tr.supportLocalTicketDraft,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF20282E),
                          ),
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: category,
                          decoration: _decoration(tr.category),
                          items:
                              [
                                    'Trip & rider',
                                    'Wallet & payments',
                                    'Scheduled rides',
                                    'Account & documents',
                                    'Technical issue',
                                    'Something else',
                                  ]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        _supportCategoryLabel(e),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: saving
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setSheetState(() => category = v);
                                    unawaited(saveDraft());
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: subject,
                          enabled: !saving,
                          onChanged: (_) {
                            if (attempted) setSheetState(() {});
                          },
                          decoration: _decoration(tr.subject).copyWith(
                            errorText: attempted && subject.text.trim().isEmpty
                                ? tr.enterSubject
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: message,
                          enabled: !saving,
                          onChanged: (_) {
                            if (attempted) setSheetState(() {});
                          },
                          minLines: 4,
                          maxLines: 6,
                          decoration: _decoration(tr.tellUsWhatHappened)
                              .copyWith(
                                errorText:
                                    attempted && message.text.trim().isEmpty
                                    ? tr.enterMessage
                                    : null,
                              ),
                        ),
                        if (saveError != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              saveError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              backgroundColor: const Color(0xFF202A30),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: saving
                                ? null
                                : () async {
                                    if (saving ||
                                        !sheetContext.mounted ||
                                        ModalRoute.of(
                                              sheetContext,
                                            )?.isCurrent !=
                                            true) {
                                      return;
                                    }
                                    if (subject.text.trim().isEmpty ||
                                        message.text.trim().isEmpty) {
                                      setSheetState(() => attempted = true);
                                      return;
                                    }
                                    final ticket = _Ticket(
                                      subject.text.trim(),
                                      message.text.trim(),
                                      'LOCAL DRAFT',
                                      false,
                                      category: category,
                                    );
                                    setSheetState(() {
                                      saving = true;
                                      saveError = null;
                                    });
                                    setState(() => tickets.insert(0, ticket));
                                    try {
                                      await _repository.update(
                                        'tickets',
                                        tickets.map((t) => t.toJson()).toList(),
                                      );
                                    } catch (_) {
                                      tickets.remove(ticket);
                                      if (mounted) setState(() {});
                                      if (sheetContext.mounted) {
                                        setSheetState(() {
                                          saving = false;
                                          saveError =
                                              tr.supportCouldNotSaveTicket;
                                        });
                                      }
                                      return;
                                    }
                                    if (!sheetContext.mounted ||
                                        ModalRoute.of(
                                              sheetContext,
                                            )?.isCurrent !=
                                            true) {
                                      return;
                                    }
                                    popOwned(sheetContext, ticket);
                                  },
                            child: Text(
                              saving
                                  ? tr.supportSavingDraft
                                  : tr.supportSaveDraftDemo,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await saveDraft();
    if (created != null && mounted) {
      try {
        await _repository.update('draft', {
          'subject': '',
          'message': '',
          'category': 'Trip & rider',
        });
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr.supportTicketSavedDraftNotCleared)),
          );
        }
      }
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE1E5E7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFF2FBE7B), width: 1.4),
    ),
  );

  void _open(_Ticket ticket) {
    if (_loading || _restoreFailed) {
      return;
    }
    setState(() => ticket.unread = false);
    pushSingle(
      context,
      MaterialPageRoute(
        builder: (_) => _Conversation(ticket: ticket, onChanged: _saveTickets),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F4F5),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF2F4F5),
      surfaceTintColor: Colors.transparent,
      title: Text(
        tr.supportDemo,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _loading || _restoreFailed || _opening ? null : _newTicket,
      backgroundColor: const Color(0xFF202A30),
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        tr.supportDraftLocalTicket,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF202A30),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              _SupportIcon(),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.supportLocalPreview,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      tr.supportLocalDraftsNoService,
                      style: TextStyle(color: Color(0xFFBFC8CD), fontSize: 12),
                    ),
                  ],
                ),
              ),
              CircleAvatar(radius: 5, backgroundColor: Color(0xFF2FBE7B)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_loading) const LinearProgressIndicator(),
        if (_restoreFailed) ...[
          TextButton(
            onPressed: _loading ? null : _restore,
            child: Text(tr.supportCouldNotLoadRetry),
          ),
          TextButton(
            onPressed: _loading ? null : _recover,
            child: Text(tr.supportRecoverPreserve),
          ),
        ],
        Text(
          tr.supportYourConversations,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF20282E),
          ),
        ),
        const SizedBox(height: 12),
        ...tickets.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TicketCard(ticket: t, onTap: () => _open(t)),
          ),
        ),
      ],
    ),
  );
}

/// A saved category (kept in English) in the driver's language.
String _supportCategoryLabel(String category) => switch (category) {
  'Trip & rider' => tr.supportCatTripRider,
  'Wallet & payments' => tr.supportCatWallet,
  'Scheduled rides' => tr.scheduledRides,
  'Account & documents' => tr.supportCatAccount,
  'Technical issue' => tr.supportCatTechnical,
  'Something else' => tr.cancelReasonSomethingElse,
  _ => category,
};

class _TicketCard extends StatelessWidget {
  final _Ticket ticket;
  final VoidCallback onTap;
  const _TicketCard({required this.ticket, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final open = ticket.status == 'OPEN';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: open
                      ? const Color(0xFFE7F6EF)
                      : const Color(0xFFF0F2F3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  open ? Icons.support_agent_rounded : Icons.task_alt_rounded,
                  color: open
                      ? const Color(0xFF16895B)
                      : const Color(0xFF758087),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (ticket.unread)
                          const CircleAvatar(
                            radius: 4,
                            backgroundColor: Color(0xFF2FBE7B),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ticket.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6F7B82),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: open
                                ? const Color(0xFFE7F6EF)
                                : const Color(0xFFF0F2F3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ticket.status == 'LOCAL DRAFT'
                                ? tr.supportLocalDraftBadge
                                : ticket.status,
                            style: TextStyle(
                              color: open
                                  ? const Color(0xFF16895B)
                                  : const Color(0xFF758087),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (ticket.category case final category?)
                          Text(
                            _supportCategoryLabel(category),
                            style: const TextStyle(
                              color: Color(0xFF6F7B82),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFABB3B8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Conversation extends StatefulWidget {
  final _Ticket ticket;
  final Future<void> Function() onChanged;
  const _Conversation({required this.ticket, required this.onChanged});
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final input = TextEditingController();
  final _history = ScrollController();
  bool _saving = false;
  Future<void> saveMessage() async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _saving ||
        input.text.trim().isEmpty) {
      return;
    }
    final rawText = input.text;
    final text = rawText.trim();
    final message = _Message(text, false);
    _saving = true;
    final previousPreview = widget.ticket.preview;
    setState(() {
      widget.ticket.messages.add(message);
      widget.ticket.preview = text;
    });
    try {
      await widget.onChanged();
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _history.hasClients) _history.jumpTo(0);
        });
      }
      if (mounted && input.text == rawText) {
        input.clear();
      }
    } catch (_) {
      widget.ticket.messages.remove(message);
      widget.ticket.preview = previousPreview;
      if (mounted) {
        setState(() {});
      }
    } finally {
      _saving = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    input.dispose();
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F4F5),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF2F4F5),
      surfaceTintColor: Colors.transparent,
      title: Text(
        tr.supportLocalDraftSubject(widget.ticket.subject),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    body: Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _history,
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: widget.ticket.messages.length,
            itemBuilder: (_, index) {
              final m = widget
                  .ticket
                  .messages[widget.ticket.messages.length - 1 - index];
              return Align(
                alignment: m.support
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  constraints: const BoxConstraints(maxWidth: 300),
                  decoration: BoxDecoration(
                    color: m.support ? Colors.white : const Color(0xFF202A30),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    m.text,
                    style: TextStyle(
                      color: m.support ? const Color(0xFF283138) : Colors.white,
                      height: 1.35,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            14,
            10,
            14,
            MediaQuery.paddingOf(context).bottom + 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  decoration: InputDecoration(
                    hintText: tr.supportWriteLocalDraft,
                    filled: true,
                    fillColor: const Color(0xFFF2F4F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: input,
                builder: (_, value, __) => IconButton.filled(
                  tooltip: tr.supportSaveLocalReply,
                  key: const ValueKey('local-reply-save'),
                  onPressed: _saving || value.text.trim().isEmpty
                      ? null
                      : saveMessage,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF202A30),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SupportIcon extends StatelessWidget {
  const _SupportIcon();
  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    width: 46,
    decoration: BoxDecoration(
      color: const Color(0xFF2FBE7B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Icon(Icons.support_agent_rounded, color: Colors.white),
  );
}

class _Ticket {
  final String subject;
  String preview;
  final String status;
  bool unread;
  final List<_Message> messages;

  /// The category picked in the draft; null on tickets saved before it
  /// was kept (driver-u171).
  final String? category;
  _Ticket(this.subject, this.preview, this.status, this.unread, {this.category})
    : messages = [_Message(preview, false)];
  Map<String, dynamic> toJson() => {
    'subject': subject,
    if (category != null) 'category': category,
    'preview': preview,
    'status': status,
    'unread': unread,
    'messages': messages
        .map((m) => {'text': m.text, 'support': false})
        .toList(),
  };
  static _Ticket? fromJson(Map<String, dynamic> json) {
    if (json['subject'] is! String || json['preview'] is! String) {
      return null;
    }
    final ticket = _Ticket(
      json['subject'] as String,
      json['preview'] as String,
      'LOCAL DRAFT',
      false,
      category: json['category'] is String ? json['category'] as String : null,
    );
    ticket.messages.clear();
    for (final row in (json['messages'] as List? ?? [])) {
      if (row is Map && row['text'] is String) {
        ticket.messages.add(_Message(row['text'] as String, false));
      }
    }
    return ticket;
  }
}

class _Message {
  final String text;
  final bool support;
  _Message(this.text, this.support);
}

/// Controllers live as long as the fields, including the sheet exit animation.
class _DraftFormLifetime extends StatefulWidget {
  const _DraftFormLifetime({required this.controllers, required this.child});
  final List<TextEditingController> controllers;
  final Widget child;
  @override
  State<_DraftFormLifetime> createState() => _DraftFormLifetimeState();
}

class _DraftFormLifetimeState extends State<_DraftFormLifetime> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
