import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/trip_chat_options.dart';
import 'package:movera/presentation/common/chat/chat_g92.dart';

/// Contract v0.18.56 §78 (G9-2.8, G9-2.14, owner Q82): a new message from
/// the rider (or support) on the trip screen. The trip stream's `message`
/// event lands in the chat thread; this watches it and, unless Chat shows
/// the thread, holds the message for the sheet's card and calls [onNew]
/// (auto-open of a folded sheet, sound, read aloud). The rider's
/// automatic "I'm on my way" comes the same way.
class TripChatAlerts extends ChangeNotifier {
  TripChatAlerts({
    required this.chat,
    required this.tripId,
    required this.onNew,
  });

  final LiveTripChat chat;
  final String tripId;
  final void Function(TripChatMessage message, TripChatOptions options) onNew;

  TripChatThread? _thread;
  int _seen = 0;
  TripChatMessage? _card;

  /// The message the sheet's card shows; null: no card.
  TripChatMessage? get card => _card;

  TripChatThread get thread => chat.thread(tripId);

  void start() {
    final thread = this.thread;
    _thread = thread;
    _seen = thread.incomingCount;
    thread.addListener(_onThread);
    unawaited(chat.loadOptions(tripId));
  }

  void _onThread() {
    final thread = _thread;
    if (thread == null) return;
    if (thread.closed || thread.isOpen) {
      _seen = thread.incomingCount;
      dismiss();
      return;
    }
    if (thread.incomingCount <= _seen) return;
    _seen = thread.incomingCount;
    final message = thread.lastIncoming;
    if (message == null) return;
    _card = message;
    notifyListeners();
    onNew(message, thread.options);
  }

  /// The card goes (opened, answered or closed).
  void dismiss() {
    if (_card == null) return;
    _card = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _thread?.removeListener(_onThread);
    super.dispose();
  }
}

/// The card on the trip sheet: "From (first name)", the short text, an
/// arrow to the chat and the quick replies.
class TripChatCard extends StatelessWidget {
  const TripChatCard({
    super.key,
    required this.alerts,
    required this.riderFirstName,
    required this.onOpen,
  });

  final TripChatAlerts alerts;
  final String riderFirstName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([alerts, alerts.thread]),
    builder: (context, _) {
      final message = alerts.card;
      if (message == null) return const SizedBox.shrink();
      final options = alerts.thread.options;
      final from = message.fromSupport ? tr.chatSupportSender : riderFirstName;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Container(
          key: const ValueKey<String>('active-ride-chat-card'),
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF202A30),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: tr.chatCardOpen,
                      onTap: onOpen,
                      child: GestureDetector(
                        onTap: onOpen,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.automatic
                                  ? '${tr.chatCardFrom(from)} · ${tr.chatAutomatic}'
                                  : tr.chatCardFrom(from),
                              style: const TextStyle(
                                color: Color(0xFFB7C0C6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message.text,
                              key: const ValueKey<String>(
                                'active-ride-chat-card-text',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('active-ride-chat-card-open'),
                    tooltip: tr.chatCardOpen,
                    onPressed: onOpen,
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (options.chips.isNotEmpty && !alerts.thread.closed) ...[
                const SizedBox(height: 6),
                QuickReplyChips(
                  dark: true,
                  replies: options.chips,
                  onTap: (reply) {
                    unawaited(alerts.chat.sendQuickReply(alerts.tripId, reply));
                    alerts.dismiss();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
