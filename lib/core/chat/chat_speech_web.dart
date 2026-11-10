import 'package:web/web.dart' as web;

/// The web build: the browser's own voice (`speechSynthesis`) in the
/// app language. False when the browser has none.
bool deviceSpeak(String text, String language) {
  try {
    final utterance = web.SpeechSynthesisUtterance(text)
      ..lang = switch (language) {
        'sv' => 'sv-SE',
        'fr' => 'fr-FR',
        _ => 'en-GB',
      };
    web.window.speechSynthesis.speak(utterance);
    return true;
  } catch (_) {
    return false;
  }
}
