import 'dart:async';

import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_trip_chat.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/live/trip_chat_options.dart';
import 'package:movera/presentation/common/chat/chat_g92.dart';
import 'package:movera/presentation/common/chat/components/appbar.dart';
import 'package:movera/presentation/common/chat/trip_call.dart';
import 'package:movera/presentation/common/chat/local_chat_messages.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/custom_textfield.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

// Moved to its own file (LT-4) so the app can clear it at sign-out without
// loading Chat; still exported here for older imports.
export 'package:movera/presentation/common/chat/local_chat_messages.dart';

class Chat extends StatefulWidget {
  const Chat({
    super.key,
    required this.riderDisplayName,
    this.tripId,
    this.liveChat,
  });

  final String riderDisplayName;

  /// The trip whose messages this Chat shows: the server's in a live
  /// build, this phone's local ones in the demo.
  final String? tripId;

  /// Test seam: the live chat; by default the live build's.
  final LiveTripChat? liveChat;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TextEditingController _messageController = TextEditingController();

  late final List<String> _messages = LocalChatMessages.forTrip(widget.tripId);

  /// A live build: the trip's chat on the server; null in the demo.
  late final LiveTripChat? _live = widget.tripId == null
      ? null
      : widget.liveChat ?? LiveDriverServices.instance?.chat;
  TripChatThread? _thread;
  bool _historyFailed = false;
  final ScrollController _scroll = ScrollController();
  bool showSendIcon = false;

  /// The call answer ("Calls coming soon – use the chat"), shown above the
  /// write field for a few seconds so it never covers the field or the
  /// send button (G9 live 2026-11-02).
  String? _callNotice;
  Timer? _callNoticeTimer;
  int _shown = 0;

  /// v0.18.56 §78 translate link: the translations read (never stored
  /// beyond this screen), which of them show now, and which are on the
  /// way. The original text is always kept.
  final Map<String, String> _translated = {};
  final Set<String> _showingTranslation = {};
  final Set<String> _translating = {};

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        showSendIcon = _messageController.text.trim().isNotEmpty;
      });
    });
    final live = _live;
    final tripId = widget.tripId;
    if (live != null && tripId != null) {
      _thread = live.thread(tripId)..addListener(_onThread);
      // After this frame: opening marks the thread read, which redraws
      // the trip screen's badge under this route (not while it builds).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openLive(live, tripId));
      });
    }
  }

  @override
  void dispose() {
    _thread?.removeListener(_onThread);
    if (widget.tripId case final tripId? when _thread != null) {
      _live?.close(tripId);
    }
    _callNoticeTimer?.cancel();
    _scroll.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onThread() {
    if (!mounted) return;
    setState(() {});
    final count = _thread?.messages.length ?? 0;
    if (count > _shown) {
      _shown = count;
      _scrollToNewest();
    }
  }

  void _showCallNotice(String text) {
    if (!mounted) return;
    _callNoticeTimer?.cancel();
    setState(() => _callNotice = text);
    _callNoticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _callNotice = null);
    });
  }

  /// The conversation starts at the top (owner decision G9 2c); a new
  /// message scrolls to the newest one when the list is longer than the
  /// screen.
  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Opened on the live trip: the history is read once (then the trip's
  /// stream brings every message); the screen says when it could not be.
  Future<void> _openLive(LiveTripChat live, String tripId) async {
    unawaited(live.loadOptions(tripId));
    final ok = await live.open(tripId);
    if (mounted && !ok) setState(() => _historyFailed = true);
  }

  /// "Translate" ↔ "See original" under a message from the other side.
  Future<void> _toggleTranslation(TripChatMessage message) async {
    final id = message.messageId;
    if (_showingTranslation.remove(id)) {
      setState(() {});
      return;
    }
    if (_translated.containsKey(id)) {
      setState(() => _showingTranslation.add(id));
      return;
    }
    final live = _live;
    final tripId = widget.tripId;
    if (live == null || tripId == null || !_translating.add(id)) return;
    setState(() {});
    final outcome = await live.translate(tripId, id);
    if (!mounted) return;
    setState(() {
      _translating.remove(id);
      if (outcome.text case final text?) {
        _translated[id] = text;
        _showingTranslation.add(id);
      }
    });
    if (translateNotice(outcome.result) case final notice?) {
      _showCallNotice(notice);
    }
  }

  void _sendQuickReply(QuickReply reply) {
    final live = _live;
    final tripId = widget.tripId;
    if (live == null || tripId == null || (_thread?.closed ?? false)) return;
    unawaited(_deliver(live.sendQuickReply(tripId, reply)));
    _scrollToNewest();
  }

  Future<void> _loadAgain() async {
    final live = _live;
    final tripId = widget.tripId;
    if (live == null || tripId == null) return;
    setState(() => _historyFailed = false);
    final ok = await live.load(tripId);
    if (mounted && !ok) setState(() => _historyFailed = true);
  }

  // Function to send message
  void _sendMessage() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_thread?.closed ?? false) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return; // Don't send if text is empty
    }

    final live = _live;
    final tripId = widget.tripId;
    if (live != null && tripId != null) {
      unawaited(_deliver(live.send(tripId, text)));
    } else {
      _messages.add(text);
    }
    setState(() {});
    _messageController.clear();
    if (ModalRoute.of(context)?.isCurrent == true) _scrollToNewest();
  }

  /// The server's answer to a send (or a retry): a refusal is said the
  /// app's usual way; the message stays in the list, marked not sent.
  Future<void> _deliver(Future<LiveTripOutcome> sending) async {
    final outcome = await sending;
    if (outcome.ok || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(outcome.message!),
        backgroundColor: const Color(0xFF252E3A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _notice(String text, {VoidCallback? onRetry}) => Container(
    margin: EdgeInsets.symmetric(horizontal: screenHorizPadding, vertical: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xffF6F6F6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12.5, height: 1.3)),
        ),
        if (onRetry != null)
          TextButton(
            key: const ValueKey<String>('chat-history-retry'),
            onPressed: onRetry,
            child: Text(tr.retry),
          ),
      ],
    ),
  );

  Widget _localNotice() => _notice(tr.chatLocalDemo);

  /// Under the driver's own live message: when it was sent, or where it is.
  String _ownLabel(TripChatMessage message) => switch (message.state) {
    TripChatSendState.sending => tr.chatSending,
    TripChatSendState.failed => tr.chatNotSentTapToRetry,
    TripChatSendState.sent => DriverDates.time(message.at.toLocal()),
  };

  /// "Automatic · 14:05" for a message the server wrote (§78).
  String _timeLabel(TripChatMessage message, String label) =>
      message.automatic ? '${tr.chatAutomatic} · $label' : label;

  Widget _liveMessage(TripChatMessage message) {
    if (!message.own) {
      final id = message.messageId;
      final showing = _showingTranslation.contains(id);
      final translation = _thread?.options.translation ?? true;
      return RiderMessage(
        sender: message.fromSupport ? tr.chatSupportSender : null,
        text: showing ? _translated[id]! : message.text,
        label: _timeLabel(message, DriverDates.time(message.at.toLocal())),
        footer: translation
            ? ChatTranslateLink(
                showingTranslation: showing,
                busy: _translating.contains(id),
                onTap: () => unawaited(_toggleTranslation(message)),
              )
            : null,
      );
    }
    final failed = message.state == TripChatSendState.failed;
    return SenderMessage(
      text: message.text,
      label: message.local
          ? _ownLabel(message)
          : _timeLabel(message, _ownLabel(message)),
      onTap: failed
          ? () => unawaited(_deliver(_live!.retry(widget.tripId!, message)))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    final live = thread != null;
    final count = live ? thread.messages.length : _messages.length;
    // Contract v0.13.0 §22: the chat closes at drop-off; the history stays.
    final closed = thread?.closed ?? false;
    final canSend = showSendIcon && !closed;
    return Scaffold(
      backgroundColor: const Color(0xffFAFAFA),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          (ResSize.h * 75).clamp(kToolbarHeight, double.infinity),
        ),
        child: ChatAppBar(
          riderDisplayName: widget.riderDisplayName,
          tripId: widget.tripId,
          onCall: () => callRider(
            context,
            tripId: widget.tripId,
            chat: widget.liveChat,
            onSay: _showCallNotice,
          ),
        ),
      ),
      body: Column(
        children: [
          if (live) ChatHeaderLine(options: thread.options),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              itemCount: count + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  if (!live) return _localNotice();
                  return _historyFailed
                      ? _notice(tr.chatHistoryFailed, onRetry: _loadAgain)
                      : const SizedBox.shrink();
                }
                return live
                    ? _liveMessage(thread.messages[index - 1])
                    : SenderMessage(text: _messages[index - 1]);
              },
            ),
          ),
          ColoredBox(
            color: AppColor.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenHorizPadding,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_callNotice case final notice?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          key: const ValueKey<String>('chat-call-notice'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252E3A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            notice,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    if (live && !closed && thread.options.chips.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: QuickReplyChips(
                          replies: thread.options.chips,
                          onTap: _sendQuickReply,
                        ),
                      ),
                    if (closed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          tr.chatClosedAfterTrip,
                          key: const ValueKey<String>('chat-closed'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF5C656C),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: customTextfield(
                            borderColor: Colors.transparent,
                            borderWidth: 0,
                            textColor: AppColor.black,
                            controller: _messageController,
                            fontSize: 14,
                            hint: tr.chatSendMessageHint,
                            fillColor: const Color(0xffF6F6F6),
                            borderRadius: 32,
                            hintTextColor: const Color(0xff969696),
                            contentHorizPadding: 14,
                            contentVertPadding: 12,
                            enabled: !closed,
                            textInputAction: TextInputAction.send,
                            onFieldSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          container: true,
                          label: live ? tr.chatSend : tr.chatSaveLocally,
                          button: true,
                          enabled: canSend,
                          onTap: canSend ? _sendMessage : null,
                          child: ExcludeSemantics(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Color(0xffF6F6F6),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: live
                                    ? tr.chatSend
                                    : tr.chatSaveLocally,
                                onPressed: canSend ? _sendMessage : null,
                                padding: const EdgeInsets.all(12),
                                icon: Image.asset(
                                  AppAssets.send,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The driver's own message: on the right, in the dark bubble, with no
/// avatar, like the driver's replies in Support (driver-u55). The rider's
/// messages sit on the left ([RiderMessage]).
class SenderMessage extends StatelessWidget {
  final String text;

  /// Under the bubble: when it was sent, or where it is. The demo's "not
  /// sent" when not given.
  final String? label;

  /// Set when the message was not sent: a tap sends it again.
  final VoidCallback? onTap;

  const SenderMessage({super.key, required this.text, this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: ResSize.h * 10,
        left: 80,
        right: screenHorizPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Semantics(
            button: onTap != null,
            onTap: onTap,
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                key: const ValueKey<String>('chat-own-message'),
                padding: EdgeInsets.symmetric(
                  horizontal: ResSize.w * 12,
                  vertical: ResSize.h * 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF202A30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextWidget(
                  text: text,
                  fontSize: 14,
                  color: AppColor.white,
                  fontWeight: fwNormal,
                ),
              ),
            ),
          ),
          5.height,
          TextWidget(
            text: label ?? tr.chatLocalNotSent,
            color: Color(0xff858F94),
            fontSize: 12,
            fontWeight: fwNormal,
          ),
        ],
      ),
    );
  }
}

/// The rider's (or support's) message: on the left, in a white bubble,
/// with the time under it.
class RiderMessage extends StatelessWidget {
  const RiderMessage({
    super.key,
    required this.text,
    required this.label,
    this.sender,
    this.footer,
  });

  /// Under the time: the translate link (§78).
  final Widget? footer;

  /// Over the bubble: "Movera" for a support message, so it never looks
  /// like the rider's (G9 live 2026-11-02). None for the rider.
  final String? sender;

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: ResSize.h * 10,
        left: screenHorizPadding,
        right: 80,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sender case final name?) ...[
            Text(
              name,
              key: const ValueKey<String>('chat-support-sender'),
              style: const TextStyle(
                color: Color(0xFF5C656C),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            4.height,
          ],
          Container(
            key: const ValueKey<String>('chat-rider-message'),
            padding: EdgeInsets.symmetric(
              horizontal: ResSize.w * 12,
              vertical: ResSize.h * 10,
            ),
            decoration: BoxDecoration(
              color: AppColor.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextWidget(
              text: text,
              fontSize: 14,
              color: const Color(0xFF283138),
              fontWeight: fwNormal,
            ),
          ),
          5.height,
          TextWidget(
            text: label,
            color: Color(0xff858F94),
            fontSize: 12,
            fontWeight: fwNormal,
          ),
          ?footer,
        ],
      ),
    );
  }
}
