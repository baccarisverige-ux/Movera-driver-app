import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/live/live_trip_commands.dart';
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
  });

  factory TripChatMessage.fromJson(Map<String, dynamic> json) =>
      TripChatMessage(
        messageId: json['messageId'] as String,
        from: json['from'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String).toUtc(),
      );

  factory TripChatMessage.fromRealtime(RealtimeMessage message) =>
      TripChatMessage(
        messageId: message.messageId,
        from: message.from,
        text: message.text,
        at: message.at ?? DateTime.now().toUtc(),
      );

  /// The server's id; this phone's own copy carries its `Idempotency-Key`
  /// until the server answers.
  final String messageId;

  /// `rider`, `driver` or `support`.
  final String from;
  final String text;
  final DateTime at;
  final TripChatSendState state;

  /// Written on this phone.
  bool get own => from == 'driver';

  /// Still this phone's copy, not the server's.
  bool get local => state != TripChatSendState.sent;

  TripChatMessage _with(TripChatSendState state) => TripChatMessage(
    messageId: messageId,
    from: from,
    text: text,
    at: at,
    state: state,
  );
}

/// One trip's chat as the screens read it: the messages in time order and
/// how many the driver has not seen. Chat and the trip screen listen.
class TripChatThread extends ChangeNotifier {
  TripChatThread(this.tripId);

  final String tripId;
  final List<TripChatMessage> _messages = [];
  int _unread = 0;
  int _open = 0;
  bool _loaded = false;
  bool _closed = false;

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
    _loaded = true;
    _closed = true;
    notifyListeners();
  }

  /// Oldest first.
  List<TripChatMessage> get messages => List.unmodifiable(_messages);

  /// Messages from the rider (or support) the driver has not opened yet.
  int get unread => _unread;

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
    notifyListeners();
  }

  /// Puts a message from the server in; a new one from the rider (or
  /// support) counts as unread unless Chat shows the thread.
  void _add(TripChatMessage message, {String? replacing}) {
    final fresh = _put(message, replacing: replacing);
    if (fresh && !message.own && !isOpen) {
      _unread++;
      notifyListeners();
    }
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
    final incoming = TripChatMessage.fromRealtime(message);
    String? copy;
    if (incoming.own) {
      for (final sent in thread._messages) {
        if (sent.local && sent.text == incoming.text) {
          copy = sent.messageId;
          break;
        }
      }
    }
    thread._add(incoming, replacing: copy);
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
        body: {'text': copy.text},
        idempotencyKey: key,
      );
      // The stream's echo may have replaced the copy meanwhile.
      if (thread._find(key) == null) return const LiveTripOutcome.ok();
      thread._put(TripChatMessage.fromJson(answer), replacing: key);
      return const LiveTripOutcome.ok();
    } on ApiError catch (error) {
      DriverLog.warn('trip message refused: ${error.detail}', name: 'live');
      return _notSent(thread, key, error);
    } on TypeError catch (error) {
      DriverLog.warn('trip message answer unreadable', name: 'live');
      return _notSent(thread, key, error);
    }
  }

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
