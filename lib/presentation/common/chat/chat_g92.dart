import 'package:flutter/material.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/trip_chat_options.dart';
import 'package:movera/widgets/responsive_size.dart';

/// Contract v0.18.56 §78 (G9 part 2, owner Q79–Q85): the chat's extra
/// pieces, kept out of chat.dart (Rule 25).

/// Owner Q81: one line under the chat header, "Problem? Use Support or
/// SOS"; the chat has no Report and no Block button.
class ChatHeaderLine extends StatelessWidget {
  const ChatHeaderLine({super.key, this.options});

  final TripChatOptions? options;

  /// The server's line in the driver's language, else the app's own.
  static String textOf(TripChatOptions? options) =>
      options?.headerLine[DriverAppTexts.language] ?? tr.chatHeaderLine;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey<String>('chat-header-line'),
    width: double.infinity,
    color: const Color(0xFFF1F3F5),
    padding: EdgeInsets.symmetric(horizontal: screenHorizPadding, vertical: 8),
    child: Row(
      children: [
        const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF5C656C)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            textOf(options),
            style: const TextStyle(
              color: Color(0xFF5C656C),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The quick-reply chips (G9-2.5): a tap sends the chip as a message.
class QuickReplyChips extends StatelessWidget {
  const QuickReplyChips({
    super.key,
    required this.replies,
    required this.onTap,
    this.dark = false,
  });

  final List<QuickReply> replies;
  final void Function(QuickReply reply) onTap;

  /// On the trip sheet's dark card.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: tr.chatQuickReplies,
      child: SingleChildScrollView(
        key: const ValueKey<String>('chat-quick-replies'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  key: ValueKey<String>('chat-quick-reply-${reply.id}'),
                  label: Text(reply.textIn(DriverAppTexts.language)),
                  onPressed: () => onTap(reply),
                  backgroundColor: dark
                      ? const Color(0xFF2E3942)
                      : const Color(0xFFF1F3F5),
                  labelStyle: TextStyle(
                    color: dark ? Colors.white : const Color(0xFF202A30),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Under a message from the other side: "Translate to (language)", or,
/// while the translation shows, "See original" (owner 2026-11-10).
class ChatTranslateLink extends StatelessWidget {
  const ChatTranslateLink({
    super.key,
    required this.showingTranslation,
    required this.busy,
    required this.onTap,
  });

  final bool showingTranslation;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey<String>(
      showingTranslation ? 'chat-see-original' : 'chat-translate',
    ),
    onTap: busy ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        showingTranslation
            ? tr.chatSeeOriginal
            : tr.chatTranslateTo(tr.chatOwnLanguageName),
        style: TextStyle(
          color: busy ? const Color(0xFF9AA3A9) : const Color(0xFF1E6FD9),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// What a translate tap says when nothing was translated.
String? translateNotice(TranslateResult result) => switch (result) {
  TranslateResult.translated => null,
  TranslateResult.comingSoon => tr.chatTranslationComingSoon,
  TranslateResult.off => tr.chatTranslationOff,
  TranslateResult.failed => tr.chatTranslationFailed,
};
