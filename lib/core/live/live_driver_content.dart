import 'dart:async';

import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Contract v0.10.0 §19: `GET /driver/content?zoneId` on start and on each
/// `config_published` with doc `content` ([LiveDriverConfig] hears it);
/// the last answer is kept ([DriverContentStore]). `POST
/// /account/terms/accept { contentVersion }` when the driver accepts.
/// Never throws to its callers.
class LiveDriverContent {
  LiveDriverContent({
    required ApiClient api,
    required String? Function() zoneId,
    DriverContentStore? store,
  }) : _api = api,
       _zoneId = zoneId,
       _store = store;

  static const contentPath = '/api/v1/driver/content';
  static const acceptPath = '/api/v1/account/terms/accept';

  final ApiClient _api;
  final String? Function() _zoneId;
  final DriverContentStore? _store;
  Future<void>? _inFlight;

  DriverContentStore get store => _store ?? DriverContentStore.instance;

  /// The kept answer, then the server's (the app start).
  Future<void> start() async {
    await store.restore();
    await refresh(atStart: true);
  }

  /// Asks the server again; concurrent calls share one request.
  Future<void> refresh({bool atStart = false}) =>
      _inFlight ??= _fetch(atStart).whenComplete(() => _inFlight = null);

  Future<void> _fetch(bool atStart) async {
    try {
      final zone = _zoneId();
      final path = zone == null || zone.isEmpty
          ? contentPath
          : '$contentPath?zoneId=${Uri.encodeQueryComponent(zone)}';
      final answer = await _api.get(path);
      if (answer['items'] is! List) return;
      await store.use(DriverContent.fromJson(answer), atStart: atStart);
    } catch (error) {
      DriverLog.warn('driver_content.fetch_failed: $error');
    }
  }

  /// Accepts the terms of [version]. False when the server did not take it.
  Future<bool> acceptTerms(int version) async {
    try {
      await _api.post(acceptPath, body: {'contentVersion': version});
      await store.accepted(version);
      return true;
    } catch (error) {
      DriverLog.warn('driver_content.accept_failed: $error');
      return false;
    }
  }
}
