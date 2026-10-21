import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/common/chat/components/appbar.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/custom_textfield.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

/// driver-u54: the driver's local chat messages, per trip, kept on this
/// phone while the app runs so closing Chat does not lose them. Nothing is
/// sent; logout clears them.
class LocalChatMessages {
  LocalChatMessages._();

  static final Map<String, List<String>> _byTrip = {};

  /// The trip's list (shared by every Chat opened for it); without a trip
  /// id, a list for this Chat only.
  static List<String> forTrip(String? tripId) => tripId == null
      ? <String>[]
      : _byTrip.putIfAbsent(tripId, () => <String>[]);

  static void reset() => _byTrip.clear();
}

class Chat extends StatefulWidget {
  const Chat({super.key, required this.riderDisplayName, this.tripId});

  final String riderDisplayName;

  /// The trip whose local messages this Chat shows and keeps.
  final String? tripId;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TextEditingController _messageController = TextEditingController();

  late final List<String> _messages = LocalChatMessages.forTrip(widget.tripId);
  final ScrollController _scroll = ScrollController();
  bool showSendIcon = false;

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
  }

  @override
  void dispose() {
    _scroll.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Function to send message
  void _sendMessage() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (_messageController.text.trim().isEmpty) {
      return; // Don't send if text is empty
    }

    _messages.add(_messageController.text.trim());
    setState(() {});
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _localNotice() => Container(
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
          child: Text(
            tr.chatLocalDemo,
            style: TextStyle(fontSize: 12.5, height: 1.3),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFAFAFA),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          (ResSize.h * 75).clamp(kToolbarHeight, double.infinity),
        ),
        child: ChatAppBar(riderDisplayName: widget.riderDisplayName),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              itemCount: _messages.length + 1,
              itemBuilder: (_, index) => index == _messages.length
                  ? _localNotice()
                  : SenderMessage(
                      text: _messages[_messages.length - 1 - index],
                    ),
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
                child: Row(
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
                        textInputAction: TextInputAction.send,
                        onFieldSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      container: true,
                      label: tr.chatSaveLocally,
                      button: true,
                      enabled: showSendIcon,
                      onTap: showSendIcon ? _sendMessage : null,
                      child: ExcludeSemantics(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xffF6F6F6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            tooltip: tr.chatSaveLocally,
                            onPressed: showSendIcon ? _sendMessage : null,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The driver's own local message: on the right, in the dark bubble, with
/// no avatar, like the driver's replies in Support (driver-u55). The
/// rider's messages would sit on the left.
class SenderMessage extends StatelessWidget {
  final String text;

  const SenderMessage({super.key, required this.text});
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
          Container(
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
          5.height,
          TextWidget(
            text: tr.chatLocalNotSent,
            color: Color(0xff858F94),
            fontSize: 12,
            fontWeight: fwNormal,
          ),
        ],
      ),
    );
  }
}
