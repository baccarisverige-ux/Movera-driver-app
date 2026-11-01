import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/driver/driver_home_notices.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/page_visibility.dart';
import 'package:movera/core/location/driver_location_repository.dart';
import 'package:movera/core/location/driver_location_service.dart';
import 'package:movera/core/logging/driver_log.dart';

/// Driver group 3 "Home & going online" (owner decisions 1–3, G3-R1, R2,
/// R5; contract v0.18.4 §29), the parts below Home.
void main() {
  final origin = Uri.parse('https://api.test.movera.se');

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  late List<http.Request> requests;
  late List<FutureOr<http.Response> Function(http.Request)> answers;

  ApiClient api() => ApiClient(
    client: MockClient((request) async {
      requests.add(request);
      if (answers.isEmpty) return json(200, {'accepted': 1});
      return answers.removeAt(0)(request);
    }),
    baseUri: origin,
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );

  Map<String, dynamic> body(http.Request request) =>
      Map<String, dynamic>.from(jsonDecode(request.body) as Map);

  setUp(() {
    requests = [];
    answers = [];
    DriverAreaWatch.instance.reset();
    DriverSetOfflineNotice.instance.clear();
  });

  group('R5 position keeps being sent while online', () {
    test('live test: after the first send every one-shot read timed out '
        '(a browser waits for a NEW position); the stream\'s fix goes out '
        'every tick', () async {
      final gps = _FirstReadOnly();
      final reporter = LiveLocationReporter(
        api: api(),
        location: gps,
        every: const Duration(milliseconds: 40),
        restampHeldFix: false,
      );
      reporter.start();
      await pumpEventQueue();
      gps.stream.add(gps.fix(DateTime.now()));
      await Future<void>.delayed(const Duration(milliseconds: 190));
      reporter.stop();
      final sent = requests
          .where((r) => r.url.path == '/api/v1/driver/location')
          .length;
      expect(sent, greaterThanOrEqualTo(4), reason: 'one every 40 ms tick');
      await gps.stream.close();
    });

    test('web: a still position (no new stream event) goes out stamped now, '
        'so the server keeps the driver online', () async {
      final gps = _FirstReadOnly(firstFails: true);
      var now = DateTime.utc(2026, 10, 30, 12);
      final reporter = LiveLocationReporter(
        api: api(),
        location: gps,
        every: const Duration(hours: 1),
        now: () => now,
        restampHeldFix: true,
      );
      reporter.start();
      await pumpEventQueue();
      gps.stream.add(gps.fix(now));
      await pumpEventQueue();
      now = now.add(const Duration(minutes: 3));
      expect(await reporter.sendNow(), isTrue);
      final fix = (body(requests.last)['fixes'] as List).single as Map;
      expect(fix['measuredAt'], '2026-10-30T12:03:00.000Z');
      reporter.stop();
      await gps.stream.close();
    });

    test('a phone (no restamp): an old stream fix is not passed off as new '
        '(G5 live re-test: it is sent again with its own OS time)', () async {
      final gps = _FirstReadOnly(firstFails: true);
      var now = DateTime.utc(2026, 10, 30, 12);
      final reporter = LiveLocationReporter(
        api: api(),
        location: gps,
        every: const Duration(hours: 1),
        now: () => now,
        restampHeldFix: false,
      );
      reporter.start();
      await pumpEventQueue();
      gps.stream.add(gps.fix(now));
      await pumpEventQueue();
      now = now.add(const Duration(minutes: 3));
      requests.clear();
      expect(await reporter.sendNow(), isTrue);
      final fix = (body(requests.single)['fixes'] as List).single as Map;
      expect(fix['measuredAt'], '2026-10-30T12:00:00.000Z');
      reporter.stop();
      await gps.stream.close();
    });
  });

  group('PR #412 checker: the web re-send stops when hidden or stale', () {
    int sends() =>
        requests.where((r) => r.url.path == '/api/v1/driver/location').length;

    test('a hidden tab sends nothing after it becomes hidden', () async {
      final gps = _FirstReadOnly(firstFails: true, always: false);
      final page = _FakeVisibility();
      var now = DateTime.utc(2026, 10, 30, 12);
      final reporter = LiveLocationReporter(
        api: api(),
        location: gps,
        every: const Duration(hours: 1),
        now: () => now,
        restampHeldFix: true,
        visibility: page,
        noFixMinutes: () => 5,
      );
      reporter.start();
      await pumpEventQueue();
      gps.stream.add(gps.fix(now));
      await pumpEventQueue();
      now = now.add(const Duration(minutes: 1));
      expect(await reporter.sendNow(), isTrue);
      page.set(false);
      await pumpEventQueue();
      requests.clear();
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 10));
        expect(await reporter.sendNow(), isFalse);
      }
      expect(sends(), 0);
      reporter.stop();
      await gps.stream.close();
    });

    test('G5 live re-test round 2: a visible stationary tab keeps '
        're-sending past noFixMinutes (stamped now)', () async {
      final gps = _FirstReadOnly(firstFails: true);
      final page = _FakeVisibility();
      var now = DateTime.utc(2026, 10, 30, 12);
      final reporter = LiveLocationReporter(
        api: api(),
        location: gps,
        every: const Duration(hours: 1),
        now: () => now,
        restampHeldFix: true,
        visibility: page,
        noFixMinutes: () => 5,
      );
      reporter.start();
      await pumpEventQueue();
      gps.stream.add(gps.fix(now));
      await pumpEventQueue();
      now = now.add(const Duration(minutes: 4, seconds: 50));
      expect(await reporter.sendNow(), isTrue);
      now = now.add(const Duration(seconds: 20));
      requests.clear();
      expect(await reporter.sendNow(), isTrue);
      now = now.add(const Duration(minutes: 30));
      expect(await reporter.sendNow(), isTrue);
      expect(sends(), 2);
      reporter.stop();
      await gps.stream.close();
    });

    test('becoming visible asks for a fresh fix at once', () async {
      final gps = _FirstReadOnly(always: true);
      final page = _FakeVisibility();
      final reporter = LiveLocationReporter(
        api: api(),
        location: gps,
        every: const Duration(hours: 1),
        restampHeldFix: true,
        visibility: page,
        noFixMinutes: () => 5,
      );
      reporter.start();
      await pumpEventQueue();
      page.set(false);
      await pumpEventQueue();
      final readsBefore = gps.reads;
      requests.clear();
      page.set(true);
      await pumpEventQueue();
      expect(gps.reads, readsBefore + 1, reason: 'a one-shot read now');
      expect(sends(), 1);
      reporter.stop();
      await gps.stream.close();
    });
  });

  group('R5 a GPS timeout is not a crash report', () {
    late GeolocatorPlatform original;
    late List<DriverLogRecord> records;
    late DriverLogSink sink;
    setUp(() {
      original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = _HangingGeolocator();
      records = [];
      sink = DriverLog.sink;
      DriverLog.sink = records.add;
    });
    tearDown(() {
      GeolocatorPlatform.instance = original;
      DriverLog.sink = sink;
      DriverLocationService.resetForTesting();
    });

    testWidgets('live test: one "No recent accurate GPS fix" error report a '
        'minute; a timeout is logged as a warning only', (tester) async {
      Object? failure;
      unawaited(
        const DriverLocationService().getCurrentPosition().then(
          (_) {},
          onError: (Object e) => failure = e,
        ),
      );
      await tester.pump(const Duration(seconds: 9));
      expect(failure, isA<TimeoutException>());
      expect(
        records.where((r) => r.level == DriverLogLevel.error),
        isEmpty,
        reason: 'an error record becomes a crash report (contract v0.16.0)',
      );
      expect(records.where((r) => r.level == DriverLogLevel.warn), isNotEmpty);
    });

    test('an app fault is still reported', () {
      expect(
        DriverLocationService.isNormalGpsFailure(StateError('bug')),
        false,
      );
      expect(
        DriverLocationService.isNormalGpsFailure(TimeoutException('gps')),
        true,
      );
    });
  });

  group('decision 1 background location while online', () {
    late GeolocatorPlatform original;
    late _RecordingGeolocator fake;
    setUp(() {
      original = GeolocatorPlatform.instance;
      fake = _RecordingGeolocator();
      GeolocatorPlatform.instance = fake;
    });
    tearDown(() async {
      await DriverLocationService.setOnlineBackground(null);
      GeolocatorPlatform.instance = original;
      DriverLocationService.resetForTesting();
    });

    test('Android: the foreground service with "Movera is online"', () {
      final settings = DriverLocationService.onlineSettings(
        platform: TargetPlatform.android,
        notificationTitle: tr.backgroundLocationTitle,
        notificationText: tr.backgroundLocationBody,
      );
      expect(settings, isA<AndroidSettings>());
      final android = settings as AndroidSettings;
      expect(
        android.foregroundNotificationConfig?.notificationTitle,
        'Movera is online',
      );
      expect(android.foregroundNotificationConfig?.setOngoing, isTrue);
    });

    test('iOS: background updates on, with the blue indicator', () {
      final settings =
          DriverLocationService.onlineSettings(
                platform: TargetPlatform.iOS,
                notificationTitle: 't',
                notificationText: 'b',
              )
              as AppleSettings;
      expect(settings.allowBackgroundLocationUpdates, isTrue);
      expect(settings.showBackgroundLocationIndicator, isTrue);
      expect(settings.pauseLocationUpdatesAutomatically, isFalse);
    });

    test('going online re-opens every position stream with the background '
        'settings (Android and iOS share one native stream); offline goes '
        'back', () async {
      final positions = <DriverLocation>[];
      final sub = const DriverLocationService().watchPosition().listen(
        positions.add,
      );
      await pumpEventQueue();
      expect(fake.opened.last, isNot(isA<AndroidSettings>()));
      await DriverLocationService.setOnlineBackground((
        title: 'Movera is online',
        text: 'x',
      ));
      await pumpEventQueue();
      expect(fake.cancelled, 1);
      final online = fake.opened.last as AndroidSettings;
      expect(
        online.foregroundNotificationConfig?.notificationTitle,
        'Movera is online',
      );
      fake.controller.add(_position());
      await pumpEventQueue();
      expect(positions, hasLength(1));
      await DriverLocationService.setOnlineBackground(null);
      await pumpEventQueue();
      expect(fake.opened.last, isNot(isA<AndroidSettings>()));
      await sub.cancel();
    });

    test('Android manifest: foreground location service permissions', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android.permission.FOREGROUND_SERVICE"'));
      expect(
        manifest,
        contains('android.permission.FOREGROUND_SERVICE_LOCATION'),
      );
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });
  });

  group('availability', () {
    late LivePresence presence;
    late LiveLocationReporter reporter;
    setUp(() {
      final client = api();
      reporter = LiveLocationReporter(
        api: client,
        location: _FirstReadOnly(),
        every: const Duration(hours: 1),
      );
      presence = LivePresence(
        api: client,
        dispatch: _FakeDispatch(),
        reporter: reporter,
      );
    });
    tearDown(() => reporter.stop());

    test('decision 2: 409 location_required says "Turn on location to go '
        'online"', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 4}))
        ..add(
          (_) => json(409, {
            'code': 'invalid_transition',
            'message': 'no position',
            'requestId': 'r',
            'retryable': false,
            'reason': 'location_required',
            'projection': {'onlineStatus': 'offline', 'version': 4},
          }),
        );
      expect(await presence.goOnline(), 'Turn on location to go online');
      expect(presence.serverOnline, isFalse);
    });

    testWidgets('auth.slowStart covers going online: a sleeping server '
        'answering after 50 s is waited for', (tester) async {
      final client = ApiClient(
        client: MockClient((request) async {
          requests.add(request);
          await Future<void>.delayed(const Duration(seconds: 50));
          return request.method == 'GET'
              ? json(200, {'onlineStatus': 'offline', 'version': 1})
              : json(200, {'onlineStatus': 'online', 'version': 2});
        }),
        baseUri: origin,
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      );
      final slowReporter = LiveLocationReporter(
        api: client,
        location: _FirstReadOnly(),
        every: const Duration(hours: 1),
      );
      final slow = LivePresence(
        api: client,
        dispatch: _FakeDispatch(),
        reporter: slowReporter,
      );
      String? answer = 'pending';
      unawaited(slow.goOnline().then((value) => answer = value));
      for (var i = 0; i < 18; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      expect(answer, isNull, reason: 'online after the slow answers');
      expect(slow.serverOnline, isTrue);
      slowReporter.stop();
    });

    test('G3-R2: the go-online answer outside his zones asks for the popup '
        'with the zone names; going online still succeeds', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 4}))
        ..add(
          (_) => json(200, {
            'onlineStatus': 'online',
            'version': 5,
            'outsideArea': true,
            'areaZones': [
              {'zoneId': 'z1', 'name': 'Stockholm'},
              {'zoneId': 'z2', 'name': 'Arlanda'},
            ],
          }),
        );
      expect(await presence.goOnline(), isNull);
      expect(DriverAreaWatch.instance.take(), ['Stockholm', 'Arlanda']);
      expect(DriverAreaWatch.instance.take(), isNull);
    });

    test('G3-R2: location acks show it once per entry', () async {
      final notices = <List<String>?>[];
      void listen() => notices.add(DriverAreaWatch.instance.take());
      DriverAreaWatch.instance.addListener(listen);
      addTearDown(() => DriverAreaWatch.instance.removeListener(listen));
      Map<String, Object> ack(bool outside) => {
        'accepted': 1,
        'serverTime': '2026-10-30T12:00:00Z',
        'outsideArea': outside,
        if (outside)
          'areaZones': [
            {'zoneId': 'z1', 'name': 'Paris'},
          ],
      };
      final acks = LiveLocationReporter(
        api: api(),
        location: _FirstReadOnly(always: true),
        every: const Duration(hours: 1),
      );
      for (final outside in [true, true, false, true]) {
        answers.add((_) => json(200, ack(outside)));
        expect(await acks.sendNow(), isTrue);
      }
      expect(notices.whereType<List<String>>().toList(), [
        ['Paris'],
        ['Paris'],
      ]);
    });

    test('decision 3: a restart while online sets the driver offline and '
        'says so', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 7}))
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 8}));
      await presence.settleAfterStart();
      expect(body(requests[1])['onlineStatus'], 'offline');
      expect(DriverSetOfflineNotice.instance.value, isTrue);
      expect(
        DriverSetOfflineNotice.instance.reason,
        DriverOfflineReason.appRestart,
      );
    });

    test('G3-R1: a later profile with onlineStatus offline is the server\'s '
        'set offline; the going-online answer itself is not', () async {
      answers
        ..add((_) => json(200, {'onlineStatus': 'offline', 'version': 4}))
        ..add((_) => json(200, {'onlineStatus': 'online', 'version': 5}));
      expect(await presence.goOnline(), isNull);
      expect(
        presence.serverSetOffline(onlineStatus: 'offline', version: 4),
        isFalse,
      );
      expect(
        presence.serverSetOffline(onlineStatus: 'online', version: 6),
        isFalse,
      );
      expect(
        presence.serverSetOffline(onlineStatus: 'offline', version: 6),
        isTrue,
      );
    });
  });

  test('every new text is the contract\'s driverHome text in sv, fr, en', () {
    final contract =
        jsonDecode(File('contracts/contract.json').readAsStringSync())
            as Map<String, dynamic>;
    final home = contract['driverHome'] as Map<String, dynamic>;
    Map<String, dynamic> at(List<String> path) {
      Object? node = home;
      for (final key in path) {
        node = (node as Map<String, dynamic>)[key];
      }
      return node as Map<String, dynamic>;
    }

    final keys = <String, List<String>>{
      'backgroundLocationTitle': [
        'backgroundLocation',
        'notification',
        'title',
      ],
      'backgroundLocationBody': ['backgroundLocation', 'notification', 'body'],
      'locationRequired': ['locationRequired', 'text', 'location_required'],
      'locationOpenSettings': ['locationRequired', 'text', 'openSettings'],
      'batterySaverWarning': ['locationRequired', 'text', 'batterySaver'],
      'setOfflineLine': ['setOffline', 'text', 'line'],
      'outsideAreaTitle': ['outsideArea', 'text', 'title'],
      'outsideAreaBody': ['outsideArea', 'text', 'body'],
      'outsideAreaOk': ['outsideArea', 'text', 'ok'],
    };
    for (final lang in ['sv', 'fr', 'en']) {
      final arb =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      keys.forEach((key, path) {
        expect(arb[key], at(path)[lang], reason: '$lang $key');
      });
    }
    final slow = (contract['auth'] as Map)['slowStart'] as Map;
    expect(slow['covers'], contains('POST /driver/availability'));
    expect(ApiClient.signInTimeout.inSeconds, slow['waitSeconds']);
  });
}

/// The phone answers the first one-shot read only (like a browser asked
/// for a brand-new position); the stream gives what [stream] gets.
class _FirstReadOnly implements DriverLocationRepository {
  _FirstReadOnly({this.firstFails = false, this.always = false});

  final bool firstFails;

  /// Every read answers (a phone outdoors).
  final bool always;
  final StreamController<DriverLocation> stream =
      StreamController<DriverLocation>.broadcast();
  int reads = 0;

  DriverLocation fix(DateTime at) => DriverLocation(
    point: const GeoPoint(59.3326, 18.0649),
    accuracyMeters: 20,
    measuredAt: at,
  );

  @override
  Future<DriverLocation> getCurrentPosition() async {
    reads++;
    if (!always && (firstFails || reads > 1)) {
      throw TimeoutException('No new position');
    }
    return fix(DateTime.now());
  }

  @override
  Stream<DriverLocation> watchPosition({int distanceFilterMeters = 8}) =>
      stream.stream;
}

class _HangingGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      Completer<Position>().future;
  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) =>
      Future.value(null);
}

class _RecordingGeolocator extends GeolocatorPlatform {
  final opened = <LocationSettings?>[];
  int cancelled = 0;
  final controller = StreamController<Position>.broadcast();

  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    opened.add(locationSettings);
    late StreamController<Position> out;
    StreamSubscription<Position>? inner;
    out = StreamController<Position>(
      onListen: () => inner = controller.stream.listen(out.add),
      onCancel: () {
        cancelled++;
        return inner?.cancel();
      },
    );
    return out.stream;
  }
}

Position _position() => Position(
  latitude: 59.33,
  longitude: 18.06,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeDispatch implements ApiDispatchRepository {
  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  void refreshOffers() {}

  @override
  void markOnline() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVisibility implements PageVisibility {
  bool _visible = true;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  void set(bool visible) {
    _visible = visible;
    _changes.add(visible);
  }

  @override
  bool get visible => _visible;

  @override
  Stream<bool> get changes => _changes.stream;
}
