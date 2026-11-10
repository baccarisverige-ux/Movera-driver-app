import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/zones/driver_zone.dart';

/// Fix job 9 (contract v0.18.36 §60, `contract.json#airportQueue`): the
/// driver's place in an airport queue, as `GET /driver/airport-queue` sends
/// it. The server keeps the queue (the app never works out a place itself).
@immutable
class AirportQueueStatus {
  const AirportQueueStatus({
    required this.status,
    this.airportZoneId,
    this.position,
    this.ahead,
    this.waitingMin,
  });

  /// in_queue | not_in_area | off.
  final String status;
  final String? airportZoneId;
  final int? position;
  final int? ahead;
  final int? waitingMin;

  bool get inQueue => status == 'in_queue';

  /// Null when [json] is not a usable answer (in_queue needs its place).
  static AirportQueueStatus? tryParse(Object? json) {
    if (json is! Map) return null;
    final status = json['status'];
    if (status is! String ||
        !const {'in_queue', 'not_in_area', 'off'}.contains(status)) {
      return null;
    }
    int? number(String key) {
      final v = json[key];
      return v is num ? v.toInt() : null;
    }

    final position = number('position');
    final ahead = number('ahead');
    if (status == 'in_queue' && (position == null || ahead == null)) {
      return null;
    }
    return AirportQueueStatus(
      status: status,
      airportZoneId: json['airportZoneId'] as String?,
      position: position,
      ahead: ahead,
      waitingMin: number('waitingMin') ?? 0,
    );
  }
}

/// The latest answer for Home (card + island). Read every [every] while a
/// screen polls it; a failed read keeps the last answer.
class AirportQueue extends ChangeNotifier {
  AirportQueue();

  static final AirportQueue instance = AirportQueue();
  static const path = '/api/v1/driver/airport-queue';
  static const every = Duration(seconds: 20);

  AirportQueueStatus? _status;
  bool _leftNotice = false;
  Timer? _timer;
  int _pollers = 0;
  bool Function()? _relevant;

  /// How far around an airport zone's outline counts as near it
  /// (about 2 km).
  static const nearDegrees = 0.02;

  /// Owner 2026-11-10 (step 62 request budgets): the queue is read only
  /// when it can matter: the driver is [online] and either already in a
  /// queue or at/near an airport zone of [zones] ([point] = his last fix).
  static bool wanted({
    required bool online,
    required bool inQueue,
    GeoPoint? point,
    List<DriverZone>? zones,
  }) {
    if (!online) return false;
    if (inQueue) return true;
    if (point == null || zones == null) return false;
    for (final zone in zones) {
      if (!zone.isAirport) continue;
      if (zone.contains(point.latitude, point.longitude)) return true;
      final b = zone.bounds;
      if (point.latitude >= b.south - nearDegrees &&
          point.latitude <= b.north + nearDegrees &&
          point.longitude >= b.west - nearDegrees &&
          point.longitude <= b.east + nearDegrees) {
        return true;
      }
    }
    return false;
  }

  AirportQueueStatus? get status => _status;

  /// His place when he is in a queue, else null.
  int? get place => (_status?.inQueue ?? false) ? _status!.position : null;

  /// A new answer. Going from in_queue to anything else raises the
  /// "You left the airport queue" notice ([takeLeftNotice]).
  void use(AirportQueueStatus? next) {
    final wasIn = _status?.inQueue ?? false;
    _status = next;
    if (wasIn && !(next?.inQueue ?? false) && next != null) _leftNotice = true;
    if (next == null) _leftNotice = false;
    notifyListeners();
  }

  /// True once after he left the queue.
  bool takeLeftNotice() {
    final pending = _leftNotice;
    _leftNotice = false;
    return pending;
  }

  Future<void> refresh(ApiClient api) async {
    try {
      final next = AirportQueueStatus.tryParse(await api.get(path));
      if (next != null) use(next);
    } catch (error) {
      DriverLog.warn('airport_queue.fetch_failed: $error');
    }
  }

  /// Starts reading every [every] (shared by every screen that polls).
  /// With [relevant], a tick asks the server only while it answers true;
  /// otherwise the last place is dropped (he went offline or drove away).
  void startPolling(ApiClient api, {bool Function()? relevant}) {
    _pollers++;
    if (relevant != null) _relevant = relevant;
    if (_timer != null) return;
    _tick(api);
    _timer = Timer.periodic(every, (_) => _tick(api));
  }

  void _tick(ApiClient api) {
    final relevant = _relevant;
    if (relevant == null || relevant()) {
      unawaited(refresh(api));
    } else if (_status != null) {
      use(null);
    }
  }

  void stopPolling() {
    if (_pollers > 0) _pollers--;
    if (_pollers == 0) {
      _timer?.cancel();
      _timer = null;
      _relevant = null;
    }
  }
}
