import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// What the phone's voice does; tests put a fake in [ChatSpeech.engine].
abstract class SpeechEngine {
  Future<void> speak(String text, String locale);
}

/// Android and iOS: the phone's own text-to-speech (flutter_tts) in the
/// app language.
class FlutterTtsEngine implements SpeechEngine {
  FlutterTts? _tts;

  @override
  Future<void> speak(String text, String locale) async {
    final tts = _tts ??= FlutterTts();
    await tts.setLanguage(locale);
    await tts.speak(text);
  }
}

abstract final class ChatSpeech {
  static SpeechEngine engine = FlutterTtsEngine();

  static String locale(String language) => switch (language) {
    'sv' => 'sv-SE',
    'fr' => 'fr-FR',
    _ => 'en-GB',
  };
}

/// Reads [text] aloud in [language] (sv / fr / en). True when handed to
/// the phone's voice; a phone without one stays quiet.
bool deviceSpeak(String text, String language) {
  try {
    unawaited(
      ChatSpeech.engine.speak(text, ChatSpeech.locale(language)).catchError((
        Object e,
      ) {
        debugPrint('chat speech: $e');
      }),
    );
    return true;
  } catch (_) {
    return false;
  }
}
