/// Contract v0.18.56 §78 (G9 part 2, owner Q79–Q85): what
/// `GET /trips/{tripId}/messages/options` answers (`ChatOptions`), the
/// trip's chat settings for the driver's side.
library;

/// One quick-reply chip: its id and its text in sv / fr / en.
class QuickReply {
  const QuickReply({required this.id, required this.text});

  factory QuickReply.fromJson(Map<String, dynamic> json) => QuickReply(
    id: json['id'] as String,
    text: {
      for (final entry in (json['text'] as Map).entries)
        if (entry.value is String) '${entry.key}': entry.value as String,
    },
  );

  final String id;
  final Map<String, String> text;

  /// The text in [language], else English, else any.
  String textIn(String language) =>
      text[language] ??
      text['en'] ??
      (text.values.isEmpty ? id : text.values.first);
}

/// `ChatOptions`: the driver's quick replies and the chat settings of the
/// trip's country.
class TripChatOptions {
  const TripChatOptions({
    this.quickReplies = const [],
    this.quickRepliesOn = true,
    this.maxLength = 2000,
    this.sound = true,
    this.sheetAutoOpen = 'new_message',
    this.readAloudDefault = false,
    this.translation = true,
    this.headerLine = const {},
  });

  factory TripChatOptions.fromJson(Map<String, dynamic> json) {
    final replies = json['quickReplies'];
    final header = json['headerLine'];
    return TripChatOptions(
      quickReplies: [
        if (replies is List)
          for (final item in replies)
            if (item is Map)
              QuickReply.fromJson(Map<String, dynamic>.from(item)),
      ],
      quickRepliesOn: json['quickRepliesOn'] != false,
      maxLength: (json['maxLength'] as num?)?.toInt() ?? 2000,
      sound: json['sound'] != false,
      sheetAutoOpen: json['sheetAutoOpen'] as String? ?? 'new_message',
      readAloudDefault: json['readAloudDefault'] == true,
      translation: json['translation'] != false,
      headerLine: {
        if (header is Map)
          for (final entry in header.entries)
            if (entry.value is String) '${entry.key}': entry.value as String,
      },
    );
  }

  /// `configDefaults.chat` for the driver: used until the server answers.
  static const defaults = TripChatOptions();

  final List<QuickReply> quickReplies;
  final bool quickRepliesOn;
  final int maxLength;
  final bool sound;

  /// `new_message`: a folded trip sheet opens on a new message (Q82).
  final String sheetAutoOpen;
  final bool readAloudDefault;
  final bool translation;

  /// "Problem? Use Support or SOS" from the server (Q81), by language.
  final Map<String, String> headerLine;

  bool get opensSheet => sheetAutoOpen == 'new_message';

  /// The chips to show (none while the admin turned them off).
  List<QuickReply> get chips => quickRepliesOn ? quickReplies : const [];

  QuickReply? reply(String? id) {
    if (id == null) return null;
    for (final reply in quickReplies) {
      if (reply.id == id) return reply;
    }
    return null;
  }
}

/// What a translate tap gave (`POST /trips/{tripId}/messages/translate`).
enum TranslateResult { translated, comingSoon, off, failed }

class TranslateOutcome {
  const TranslateOutcome(this.result, [this.text]);

  final TranslateResult result;

  /// The translated text when [result] is [TranslateResult.translated].
  final String? text;
}
