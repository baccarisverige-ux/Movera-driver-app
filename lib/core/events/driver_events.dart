import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Contract v0.18.6 §32 `dispatchTools.events` (owner G4-F6 "Mark small
/// premium icon in the map in the exact location of event and when clic
/// see all details"): one event of the driver's country, as
/// `GET /driver/events` sends it, its texts already in his language.
@immutable
class DriverEvent {
  const DriverEvent({
    required this.eventId,
    required this.name,
    required this.location,
    required this.startsAt,
    required this.endsAt,
    required this.running,
    required this.title,
    required this.description,
    this.pickupNote,
    this.language,
  });

  final String eventId;

  /// The admin's name of the event (the place, e.g. "Friends Arena").
  final String name;

  /// The exact point where the icon stands.
  final GeoPoint location;
  final DateTime startsAt;
  final DateTime endsAt;

  /// The server said it is on now (the app also works it out itself, see
  /// [runningAt]).
  final bool running;
  final String title;
  final String description;
  final String? pickupNote;

  /// The language of [title], [description] and [pickupNote].
  final String? language;

  /// On at [now]: started and not ended.
  bool runningAt(DateTime now) =>
      running && now.isBefore(endsAt) ||
      !now.isBefore(startsAt) && now.isBefore(endsAt);

  /// Null when [json] is not a usable `DriverEvent`.
  static DriverEvent? tryParse(Object? json) {
    if (json is! Map) return null;
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    final id = text('eventId');
    final location = json['location'];
    final starts = DateTime.tryParse(text('startsAt') ?? '');
    final ends = DateTime.tryParse(text('endsAt') ?? '');
    if (id == null ||
        location is! Map ||
        location['lat'] is! num ||
        location['lng'] is! num ||
        starts == null ||
        ends == null ||
        !ends.isAfter(starts)) {
      return null;
    }
    final title = text('title') ?? text('name');
    if (title == null) return null;
    return DriverEvent(
      eventId: id,
      name: text('name') ?? title,
      location: GeoPoint(
        (location['lat'] as num).toDouble(),
        (location['lng'] as num).toDouble(),
      ),
      startsAt: starts,
      endsAt: ends,
      running: json['running'] == true,
      title: title,
      description: text('description') ?? '',
      pickupNote: text('pickupNote'),
      language: text('language'),
    );
  }
}

/// The events the Home map shows. A live build fills it from
/// `GET /driver/events` ([LiveDriverEvents]); the demo keeps it empty (its
/// old built-in "What's happening" list is never shown as events).
class DriverEvents extends ChangeNotifier {
  DriverEvents({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// The app's one list.
  static final DriverEvents instance = DriverEvents();

  final DateTime Function() _now;
  List<DriverEvent> _all = const [];
  Timer? _endTimer;

  /// Every event of the last answer, soonest first.
  List<DriverEvent> get all => _all;

  /// The events not ended at [at] (now by default): the app hides an
  /// event itself after its `endsAt`, without waiting for the server.
  List<DriverEvent> visible([DateTime? at]) {
    final now = at ?? _now();
    return [
      for (final event in _all)
        if (now.isBefore(event.endsAt)) event,
    ];
  }

  /// The server's answer: these events, soonest first.
  void use(List<DriverEvent> events) {
    _all = List<DriverEvent>.unmodifiable(
      [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt)),
    );
    _scheduleEnd();
    notifyListeners();
  }

  /// Signed out: none.
  void clear() {
    _endTimer?.cancel();
    _endTimer = null;
    if (_all.isEmpty) return;
    _all = const [];
    notifyListeners();
  }

  /// Wakes listeners when the next event ends, so its icon goes.
  void _scheduleEnd() {
    _endTimer?.cancel();
    _endTimer = null;
    final now = _now();
    final next = visible(now)
        .map((e) => e.endsAt)
        .fold<DateTime?>(
          null,
          (soonest, end) =>
              soonest == null || end.isBefore(soonest) ? end : soonest,
        );
    if (next == null) return;
    _endTimer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      _scheduleEnd();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _endTimer?.cancel();
    super.dispose();
  }
}

/// `GET /driver/events` (contract v0.18.6 §32): read on start, when the
/// app comes back to the front and on `config_published` with doc
/// `events`; the answer goes to [events]. Never throws to its callers; a
/// failed read keeps the last answer.
class LiveDriverEvents {
  LiveDriverEvents({required ApiClient api, DriverEvents? events})
    : _api = api,
      events = events ?? DriverEvents.instance;

  static const path = '/api/v1/driver/events';

  final ApiClient _api;
  final DriverEvents events;
  Future<bool>? _inFlight;

  /// The events of an answer `{ items: DriverEvent[], at }`; null when it
  /// is not one. An item that does not parse is left out.
  static List<DriverEvent>? parse(Object? answer) {
    if (answer is! Map) return null;
    final items = answer['items'];
    if (items is! List) return null;
    return [for (final item in items) ?DriverEvent.tryParse(item)];
  }

  /// Asks the server; calls at the same time share one request. True when
  /// read.
  Future<bool> refresh() =>
      _inFlight ??= _fetch().whenComplete(() => _inFlight = null);

  Future<bool> _fetch() async {
    try {
      final list = parse(await _api.get(path));
      if (list == null) throw const FormatException('not an events answer');
      events.use(list);
      return true;
    } catch (error) {
      DriverLog.warn('driver_events.fetch_failed: $error');
      return false;
    }
  }
}
