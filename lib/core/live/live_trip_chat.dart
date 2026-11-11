import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_commands.dart';
import 'package:movera/core/live/trip_chat_options.dart';
import 'package:movera/core/live/trip_chat_translations.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/realtime/driver_realtime.dart';

/// Where one of this phone's own messages is: on the server ([sent]), on
/// its way ([sending]), or refused and kept for a retry ([failed]).
enum TripChatSendState { sent, sending, failed }

/// One line of a trip's chat: the contract's `Message` (`messageId`,
/// `from`, `text`, `at`), or this phone's own copy of one it is sending.
class TripChatMessage {
  const TripChatMessage({
    required this.messageId,
    required this.from,
    required this.text,
    required this.at,
    this.state = TripChatSendState.sent,
    this.quickReplyId,
    this.auto,
    this.lang,
  });

  factory TripChatMessage.fromJson(Map<String, dynamic> json) =>
      TripChatMessage(
        messageId: json['messageId'] as String,
        from: json['from'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String).toUtc(),
        quickReplyId: json['quickReplyId'] as String?,
        auto: json['auto'] as String?,
        lang: json['lang'] as String?,
      );

  factory TripChatMessage.fromRealtime(RealtimeMessage message) =>
      TripChatMessage(
        messageId: message.messageId,
        from: message.from,
        text: message.text,
        at: message.at ?? DateTime.now().toUtc(),
        quickReplyId: message.quickReplyId,
        auto: message.auto,
        lang: message.lang,
      );

  /// The server's id; this phone's own copy carries its `Idempotency-Key`
  /// until the server answers.
  final String messageId;

  /// `rider`, `driver` or `support`.
  final String from;
  final String text;
  final DateTime at;
  final TripChatSendState state;

  /// v0.18.56 §78: the quick-reply chip it was sent from (the server wrote
  /// the chip in the reader's language).
  final String? quickReplyId;

  /// v0.18.56 §78: written by the server, not typed: `arrived` (the
  /// driver's "I've arrived") or `on_my_way` (the rider's "I'm on my way").
  final String? auto;

  /// v0.18.64 §85: the language the text was written in (sv / fr / en);
  /// exact for chips and automatic messages, a hint for typed text.
  final String? lang;

  /// Shown marked "Automatic".
  bool get automatic => auto != null;

  /// Written on this phone.
  bool get own => from == 'driver';

  /// Written by Movera support: shown as "Movera", never as the rider.
  bool get fromSupport => from == 'support';

  /// Still this phone's copy, not the server's.
  bool get local => state != TripChatSendState.sent;

  TripChatMessage _with(TripChatSendState state) => TripChatMessage(
    messageId: messageId,
    from: from,
    text: text,
    at: at,
    state: state,
    quickReplyId: quickReplyId,
    auto: auto,
    lang: lang,
  );
}

/// One trip's chat as the screens read it: the messages in time order and
/// how many the driver has not seen. Chat and the trip screen listen.
class TripChatThread extends ChangeNotifier {
  TripChatThread(this.tripId);

  final String tripId;
  final List<TripChatMessage> _messages = [];
  int _unread = 0;
  int _unreadSupport = 0;
  int _open = 0;
  bool _loaded = false;
  bool _closed = false;
  int _incoming = 0;
  TripChatMessage? _lastIncoming;
  TripChatOptions _options = TripChatOptions.defaults;
  bool _optionsRead = false;

  /// v0.18.56 §78: the trip's chat options (defaults until read).
  TripChatOptions get options => _options;

  /// v0.18.64 §85: the translations of this chat (while the trip is open).
  final TripChatTranslations translations = TripChatTranslations();

  /// What a message shows: its translation once it is here (unless "See
  /// original" was tapped), else the text as written. Own messages always
  /// show as written.
  String shownText(TripChatMessage message) => message.own
      ? message.text
      : translations.shown(message.messageId, message.text);

  /// Messages from the rider (or support) the stream brought, counted
  /// whether Chat shows the thread or not (the trip sheet's card, its
  /// auto-open and the sound follow it). History reads do not count.
  int get incomingCount => _incoming;

  /// The newest of those (the trip sheet's message card).
  TripChatMessage? get lastIncoming => _lastIncoming;

  /// The trip ended: the chat closed at drop-off (contract v0.13.0 §22).
  /// Since v0.18.5 (`chat.appStorage.afterTrip`) the messages are gone
  /// too: the driver reads no history after the trip.
  bool get closed => _closed;

  /// Contract v0.18.5 `chat.appStorage` (owner 2026-10-30: "Never store
  /// messages between rider or driver in driver app or rider app"): the
  /// trip ended, so the chat is closed and every message leaves this
  /// phone; nothing is kept.
  void _forget() {
    _messages.clear();
    _unread = 0;
    _unreadSupport = 0;
    _lastIncoming = null;
    translations.clear();
    _loaded = true;
    _closed = true;
    notifyListeners();
  }

  /// Oldest first.
  List<TripChatMessage> get messages => List.unmodifiable(_messages);

  /// Messages from the rider (or support) the driver has not opened yet.
  int get unread => _unread;

  /// Unread messages written by Movera support (`from: support`): then the
  /// trip screen says "new messages", not "from the rider" (G9 live
  /// 2026-11-02).
  int get unreadFromSupport => _unreadSupport;

  /// A Chat screen shows this thread now.
  bool get isOpen => _open > 0;

  /// The history was read from the server once.
  bool get loaded => _loaded;

  TripChatMessage? _find(String messageId) {
    for (final message in _messages) {
      if (message.messageId == messageId) return message;
    }
    return null;
  }

  /// Puts [message] in: in place of the one with its id, or of
  /// [replacing] (this phone's copy of it), else at its time. True when
  /// the thread did not have it.
  bool _put(TripChatMessage message, {String? replacing}) {
    final known = _find(message.messageId);
    final copy = replacing == null ? null : _find(replacing);
    if (known != null) {
      _messages[_messages.indexOf(known)] = message;
      if (copy != null) _messages.remove(copy);
    } else if (copy != null) {
      _messages[_messages.indexOf(copy)] = message;
    } else {
      _messages.add(message);
    }
    _sort();
    notifyListeners();
    return known == null && copy == null;
  }

  // A stable sort: two messages at the same instant keep their order.
  void _sort() {
    final indexed = _messages.indexed.toList()
      ..sort((a, b) {
        final byTime = a.$2.at.compareTo(b.$2.at);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    _messages
      ..clear()
      ..addAll(indexed.map((e) => e.$2));
  }

  void _read() {
    if (_unread == 0) return;
    _unread = 0;
    _unreadSupport = 0;
    notifyListeners();
  }

  /// Puts a message from the server in; a new one from the rider (or
  /// support) counts as unread unless Chat shows the thread.
  void _add(TripChatMessage message, {String? replacing, bool live = false}) {
    final fresh = _put(message, replacing: replacing);
    if (fresh && live && !message.own) {
      _incoming++;
      _lastIncoming = message;
      notifyListeners();
    }
    if (fresh && !message.own && !isOpen) {
      _unread++;
      if (message.fromSupport) _unreadSupport++;
      notifyListeners();
    }
  }

  void _changed() => notifyListeners();

  void _markLoadedOptions() {
    _optionsRead = true;
    notifyListeners();
  }

  void _markLoaded() {
    _loaded = true;
    notifyListeners();
  }
}

/// The trip's chat on the server (contract v0.5.4): `POST
/// /trips/{tripId}/messages` sends, `GET /trips/{tripId}/messages` reads
/// the history, and the trip's event stream brings every new message
/// (`kind: message`, through [receive]).
///
/// A message shows as this phone's copy at once and is replaced by the
/// server's answer (or its echo on the stream, whichever comes first), so
/// it is never shown twice. A retry sends the same `Idempotency-Key`.
class LiveTripChat {
  LiveTripChat({required ApiClient api}) : _api = api;

  final ApiClient _api;

  static const _base = '/api/v1/trips';

  /// v0.18.38 §62: the same client for the in-app calls (trip_call.dart).
  ApiClient get api => _api;

  /// Messages read per history call (the contract's most).
  static const pageLimit = 200;

  final Map<String, TripChatThread> _threads = {};

  /// The trip's thread (empty until opened or a message arrives).
  TripChatThread thread(String tripId) =>
      _threads.putIfAbsent(tripId, () => TripChatThread(tripId));

  /// Messages the driver has not opened yet.
  int unreadOf(String tripId) => _threads[tripId]?.unread ?? 0;

  String _path(String tripId) =>
      '$_base/${Uri.encodeComponent(tripId)}/messages';

  /// A Chat screen opened on [tripId]: what is there counts as read, and
  /// the history is read once. False when it could not be read (the
  /// screen says so and offers [load] again).
  Future<bool> open(String tripId) async {
    final thread = this.thread(tripId);
    thread._open++;
    thread._read();
    if (thread.loaded) return true;
    return load(tripId);
  }

  /// The Chat screen closed: new messages count as unread again.
  void close(String tripId) {
    final thread = _threads[tripId];
    if (thread != null && thread._open > 0) thread._open--;
  }

  /// `GET /trips/{tripId}/messages`: the history, folded into the thread
  /// (what the stream already brought is not shown twice).
  Future<bool> load(String tripId) async {
    final thread = this.thread(tripId);
    try {
      final page = await _api.get('${_path(tripId)}?limit=$pageLimit');
      // v0.18.5 `chat.appStorage.afterTrip`: after the trip the server
      // answers `{ items: [], closed: true }`.
      if (page['closed'] == true) {
        thread._forget();
        return true;
      }
      final items = page['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            thread._add(
              TripChatMessage.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      thread._markLoaded();
      _autoTranslate(thread);
      return true;
    } on ApiError catch (error) {
      DriverLog.warn(
        'trip $tripId messages not read: ${error.code}',
        name: 'live',
      );
      return false;
    } on TypeError {
      DriverLog.warn('trip $tripId messages unreadable', name: 'live');
      return false;
    }
  }

  /// The stream came back after a drop: the history is read again, in
  /// case a message passed while it was down (once Chat was opened; its
  /// first open reads it anyway).
  Future<void> reconcile(String tripId) async {
    if (_threads[tripId]?.loaded ?? false) await load(tripId);
  }

  /// A `kind: message` event from the trip's stream. The rider's (or
  /// support's) message counts as unread unless Chat shows the thread;
  /// this phone's own echo replaces the copy still waiting for an answer.
  void receive(String tripId, RealtimeMessage message) {
    final thread = this.thread(tripId);
    var incoming = TripChatMessage.fromRealtime(message);
    String? copy;
    if (incoming.own) {
      for (final sent in thread._messages) {
        // A chip comes back in the rider's language: matched by its id.
        final same = incoming.quickReplyId != null
            ? sent.quickReplyId == incoming.quickReplyId
            : sent.text == incoming.text;
        if (sent.local && same) {
          copy = sent.messageId;
          break;
        }
      }
    }
    final prior =
        thread._find(incoming.messageId) ??
        (copy == null ? null : thread._find(copy));
    if (prior != null && prior.quickReplyId != null && incoming.own) {
      incoming = _ownText(incoming, prior);
    }
    thread._add(incoming, replacing: copy, live: true);
    _autoTranslate(thread);
  }

  /// v0.18.56 §78: `GET /trips/{tripId}/messages/options`, read once per
  /// trip; the defaults (`configDefaults.chat`) stay when it fails.
  Future<TripChatOptions> loadOptions(String tripId) async {
    final thread = this.thread(tripId);
    if (thread._optionsRead) return thread._options;
    try {
      final answer = await _api.get('${_path(tripId)}/options');
      thread._options = TripChatOptions.fromJson(answer);
      thread._optionsRead = true;
      thread._markLoadedOptions();
      _autoTranslate(thread);
    } on ApiError catch (error) {
      DriverLog.warn(
        'trip $tripId chat options not read: ${error.code}',
        name: 'live',
      );
    } on TypeError {
      DriverLog.warn('trip $tripId chat options unreadable', name: 'live');
    }
    return thread._options;
  }

  /// v0.18.56 §78: a quick-reply chip, sent as a normal message with its
  /// id; the server writes it in the rider's language. This phone shows
  /// it in the driver's own language.
  Future<LiveTripOutcome> sendQuickReply(String tripId, QuickReply reply) {
    if (thread(tripId).closed) {
      return Future.value(LiveTripOutcome.failed(tr.chatClosedAfterTrip));
    }
    final key = ApiClient.randomKey();
    thread(tripId)._put(
      TripChatMessage(
        messageId: key,
        from: 'driver',
        text: reply.textIn(DriverAppTexts.language),
        at: DateTime.now().toUtc(),
        state: TripChatSendState.sending,
        quickReplyId: reply.id,
      ),
    );
    return _post(tripId, key);
  }

  /// The language a translation goes to: the driver's own app language
  /// (owner A1), sv, fr or en.
  static String get translateTarget =>
      const ['sv', 'fr', 'en'].contains(DriverAppTexts.language)
      ? DriverAppTexts.language
      : 'en';

  /// v0.18.56 §78: `POST /trips/{tripId}/messages/translate`. 503
  /// `coming_soon` until the server has a provider; 403 `translation_off`
  /// when the admin turned it off (v0.18.64 §85: `auto_translate_off` for
  /// the app's own request, [auto]). Nothing is kept after the trip.
  Future<TranslateOutcome> translate(
    String tripId,
    String messageId, {
    bool auto = false,
  }) async {
    try {
      final answer = await _api.post(
        '${_path(tripId)}/translate',
        body: {
          'messageId': messageId,
          'to': translateTarget,
          if (auto) 'auto': true,
        },
        idempotencyKey: ApiClient.randomKey(),
      );
      final text = answer['text'];
      if (text is String && text.trim().isNotEmpty) {
        return TranslateOutcome(TranslateResult.translated, text);
      }
      return const TranslateOutcome(TranslateResult.failed);
    } on ApiError catch (error) {
      if (error.reason == 'coming_soon' || error.statusCode == 503) {
        return const TranslateOutcome(TranslateResult.comingSoon);
      }
      if (error.reason == 'translation_off' ||
          error.reason == 'auto_translate_off') {
        return const TranslateOutcome(TranslateResult.off);
      }
      DriverLog.warn('translate refused: ${error.code}', name: 'live');
      return const TranslateOutcome(TranslateResult.failed);
    } on TypeError {
      return const TranslateOutcome(TranslateResult.failed);
    }
  }

  /// v0.18.64 §85 (owner 2026-11-11): each message from the rider (or
  /// support) is translated into the driver's language once, as it
  /// arrives, when the trip's options say so (read first) and it is not
  /// already in that language. A failure leaves the original, quietly;
  /// `coming_soon` / `translation_off` / `auto_translate_off` stop it for
  /// the trip.
  void _autoTranslate(TripChatThread thread) {
    final t = thread.translations;
    if (!thread._optionsRead ||
        !thread._options.translatesByItself ||
        t.autoStopped ||
        thread.closed) {
      return;
    }
    final target = translateTarget;
    for (final message in List.of(thread._messages)) {
      final id = message.messageId;
      if (message.own || message.local || t.autoTried(id) || t.has(id)) {
        continue;
      }
      t.markAutoTried(id);
      if (message.lang == target || !t.start(id)) continue;
      unawaited(_translateInto(thread, id, auto: true));
    }
  }

  Future<TranslateOutcome> _translateInto(
    TripChatThread thread,
    String messageId, {
    required bool auto,
  }) async {
    final outcome = await translate(thread.tripId, messageId, auto: auto);
    final t = thread.translations;
    // The trip may have ended meanwhile: nothing is kept then.
    if (thread.closed) return outcome;
    t.done(messageId, outcome.text);
    if (auto &&
        (outcome.result == TranslateResult.comingSoon ||
            outcome.result == TranslateResult.off)) {
      t.stopAuto();
    }
    thread._changed();
    return outcome;
  }

  /// The link under a message from the rider: "See original" shows the
  /// text as written, "Translate to (language)" the translation again (or
  /// asks for it). The answer of a request, for the screen's one-line
  /// notice; null when nothing was asked.
  Future<TranslateOutcome?> toggleTranslation(
    String tripId,
    TripChatMessage message,
  ) async {
    final thread = this.thread(tripId);
    final t = thread.translations;
    final id = message.messageId;
    if (t.showsTranslation(id)) {
      t.showOriginal(id);
      thread._changed();
      return null;
    }
    if (t.has(id)) {
      t.showTranslation(id);
      thread._changed();
      return null;
    }
    if (!t.start(id)) return null;
    thread._changed();
    return _translateInto(thread, id, auto: false);
  }

  /// What the driver's read aloud says for [message]: its translation when
  /// it arrives within [wait] (§85), else the text as written.
  Future<String> spokenText(
    String tripId,
    TripChatMessage message, {
    Duration wait = const Duration(seconds: 3),
  }) async {
    // The stream's message reaches the alert before its translation is
    // asked for ([receive] asks right after): let that happen first.
    await Future<void>.delayed(Duration.zero);
    final thread = this.thread(tripId);
    final t = thread.translations;
    final id = message.messageId;
    if (t.has(id) || !t.busy(id)) return thread.shownText(message);
    final done = Completer<String>();
    late final VoidCallback check;
    void finish() {
      if (done.isCompleted) return;
      thread.removeListener(check);
      done.complete(thread.shownText(message));
    }

    check = () {
      if (!t.busy(id)) finish();
    };
    thread.addListener(check);
    Timer(wait, finish);
    return done.future;
  }

  /// `POST /trips/{tripId}/messages`: the message shows at once as this
  /// phone's copy; the server's `Message` replaces it. On a refusal (or
  /// no answer) it stays, marked not sent, for [retry].
  Future<LiveTripOutcome> send(String tripId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future.value(const LiveTripOutcome.ok());
    if (thread(tripId).closed) {
      return Future.value(LiveTripOutcome.failed(tr.chatClosedAfterTrip));
    }
    // The copy's id is the request's Idempotency-Key: a retry is the
    // same message to the server.
    final key = ApiClient.randomKey();
    thread(tripId)._put(
      TripChatMessage(
        messageId: key,
        from: 'driver',
        text: trimmed,
        at: DateTime.now().toUtc(),
        state: TripChatSendState.sending,
      ),
    );
    return _post(tripId, key);
  }

  /// Sends a message that was not sent again, with the same key.
  Future<LiveTripOutcome> retry(String tripId, TripChatMessage message) {
    final copy = thread(tripId)._find(message.messageId);
    if (copy == null || !copy.local) {
      return Future.value(const LiveTripOutcome.ok());
    }
    thread(tripId)._put(copy._with(TripChatSendState.sending));
    return _post(tripId, copy.messageId);
  }

  Future<LiveTripOutcome> _post(String tripId, String key) async {
    final thread = this.thread(tripId);
    final copy = thread._find(key);
    if (copy == null) return const LiveTripOutcome.ok();
    try {
      final answer = await _api.post(
        _path(tripId),
        body: {
          'text': copy.text,
          if (copy.quickReplyId != null) 'quickReplyId': copy.quickReplyId,
        },
        idempotencyKey: key,
      );
      // The stream's echo may have replaced the copy meanwhile.
      if (thread._find(key) == null) return const LiveTripOutcome.ok();
      thread._put(
        _ownText(TripChatMessage.fromJson(answer), copy),
        replacing: key,
      );
      return const LiveTripOutcome.ok();
    } on ApiError catch (error) {
      DriverLog.warn('trip message refused: ${error.detail}', name: 'live');
      return _notSent(thread, key, error);
    } on TypeError catch (error) {
      DriverLog.warn('trip message answer unreadable', name: 'live');
      return _notSent(thread, key, error);
    }
  }

  /// A chip the server wrote in the rider's language reads on this phone
  /// as the driver tapped it.
  static TripChatMessage _ownText(
    TripChatMessage answer,
    TripChatMessage copy,
  ) => copy.quickReplyId == null
      ? answer
      : TripChatMessage(
          messageId: answer.messageId,
          from: answer.from,
          text: copy.text,
          at: answer.at,
          quickReplyId: answer.quickReplyId ?? copy.quickReplyId,
          auto: answer.auto,
        );

  LiveTripOutcome _notSent(TripChatThread thread, String key, Object error) {
    // 409 invalid_transition, reason chat_closed: the trip has ended.
    if (error is ApiError && error.reason == 'chat_closed') {
      thread._forget();
      return LiveTripOutcome.failed(liveChatErrorMessage(error), error: error);
    }
    final copy = thread._find(key);
    if (copy != null) thread._put(copy._with(TripChatSendState.failed));
    return LiveTripOutcome.failed(liveChatErrorMessage(error), error: error);
  }

  /// The trip is over: its chat is closed (contract v0.13.0 §22) and,
  /// v0.18.5 `chat.appStorage`, its messages are dropped from this phone.
  void markClosed(String tripId) => thread(tripId)._forget();

  /// A trip event with a terminal status (completed, cancelled…): the
  /// chat of that trip ends here.
  void tripEnded(String tripId) {
    final thread = _threads[tripId];
    if (thread != null) thread._forget();
  }

  /// `POST /trips/{tripId}/call` (contract v0.13.0 §22): the masked number
  /// to dial, never the rider's own. Throws the `ApiError` (`503
  /// call_unavailable` while no provider is set up, `409 chat_closed`
  /// after drop-off, which also closes the chat).
  Future<String> call(String tripId) async {
    try {
      final answer = await _api.post(
        '$_base/${Uri.encodeComponent(tripId)}/call',
        body: const <String, dynamic>{},
        idempotencyKey: ApiClient.randomKey(),
      );
      final number = answer['proxyNumber'];
      if (number is! String || number.trim().isEmpty) {
        throw const FormatException('Missing proxyNumber');
      }
      return number.trim();
    } on ApiError catch (error) {
      if (error.reason == 'chat_closed') markClosed(tripId);
      rethrow;
    }
  }

  /// Sign-out: the next driver must not read these.
  void reset() => _threads.clear();
}
