import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/pickup_pay_config.dart';
import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_config_parts.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/notifications/driver_notifications.dart';

/// Owner 2026-10-27 (settings flow, contract v0.8.0): the driver app reads
/// its settings from the server, puts each newer document in use at once,
/// keeps the last good one, and follows the auto-offline rule.
void main() {
  final base = Uri.parse('https://api.movera.invalid/api/v1');
  Map<String, dynamic> document(int version, {int radarSeconds = 25}) => {
    'version': version,
    'zoneId': 'Z001',
    'currency': 'SEK',
    'timeZone': 'Europe/Stockholm',
    'offers': {
      'radarSeconds': radarSeconds,
      'exclusiveSeconds': 20,
      'exclusiveWhileDriving': {'on': true, 'count': 2},
      'autoOffline': {'on': true, 'missedExclusive': 10},
      'offerCard': {'pickupAddress': false},
      'exclusiveReasons': [
        {'id': 'nearby', 'text': 'Nära dig', 'on': true},
      ],
    },
    'pickupPay': {
      'offers': {'radar': true, 'exclusive': false},
      'byCategory': {
        'economy': {
          'enabled': true,
          'ranges': [
            {
              'fromKm': 0,
              'toKm': null,
              'perKm': {'amountMinor': 250, 'currency': 'SEK'},
              'perMin': {'amountMinor': 80, 'currency': 'SEK'},
            },
          ],
        },
      },
    },
    'rideCheck': {'stopMinutes': 4, 'finishFarFromDropoffKm': 2.5},
    'texts': {
      'byLanguage': {
        'sv': {'island.online': 'Radar på nu'},
      },
    },
    'notices': {
      'off': ['highDemand'],
    },
    'cancelFees': {'driverSharePct': 80},
  };

  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    PickupPayConfig.current = const PickupPayConfig();
    RideCheckAdminConfig.current = const RideCheckAdminConfig();
    DriverAppTexts.overrides = const DriverAppTextOverrides();
    DriverNoticeRules.current = const DriverNoticeRules();
    DriverCancelFees.current = const DriverCancelFees();
    ExclusiveAnswers.instance.reset();
  });

  test(
    'GET /driver/config is put in use at once: offers, pickup pay, ride '
    'check, texts, notices and cancel fees; an older version is ignored',
    () async {
      var version = 4;
      final cache = MemoryDriverConfigCache();
      final config = LiveDriverConfig(
        client: MockClient(
          (request) async => http.Response(jsonEncode(document(version)), 200),
        ),
        apiBase: base,
        accessToken: () async => 'token-1',
        cache: cache,
      );
      await config.start();
      expect(config.current?.version, 4);
      final rules = DriverOfferRules.current;
      expect(rules.radarTime, const Duration(seconds: 25));
      expect(rules.exclusiveAcceptTime, const Duration(seconds: 20));
      expect(rules.exclusiveWhileDrivingCount, 2);
      expect(rules.autoOfflineAfter, 10);
      expect(rules.card.pickupAddress, isFalse);
      expect(rules.reasonText('nearby'), 'Nära dig');
      expect(PickupPayConfig.current.categories['economy']?.krPerKm, 2.5);
      expect(PickupPayConfig.current.kinds, {PickupPayOfferKind.radar});
      expect(RideCheckAdminConfig.current.longStopMinutes, 4);
      expect(RideCheckAdminConfig.current.finishFarFromDropoffKm, 2.5);
      expect(
        DriverAppTexts.overrides.byLanguage['sv']?['island.online'],
        'Radar på nu',
      );
      expect(
        DriverNoticeRules.current.allows(DriverNoticeKind.highDemand),
        isFalse,
      );
      expect(DriverCancelFees.current.driverPartOf(6500), 5200);
      expect(cache.document?['version'], 4);

      version = 3;
      await config.refresh();
      expect(config.current?.version, 4);
      config.dispose();
    },
  );

  test('no server: the last document kept on the device is used', () async {
    final cache = MemoryDriverConfigCache()
      ..document = document(7, radarSeconds: 30);
    final config = LiveDriverConfig(
      client: MockClient((_) async => throw http.ClientException('offline')),
      apiBase: base,
      accessToken: () async => null,
      cache: cache,
    );
    await config.start();
    expect(config.current?.version, 7);
    expect(DriverOfferRules.current.radarTime, const Duration(seconds: 30));
    config.dispose();
  });

  test(
    'config_published on /driver/config/stream fetches the new document',
    () async {
      var version = 4;
      final events = StreamController<List<int>>();
      final config = LiveDriverConfig(
        client: MockClient.streaming((request, _) async {
          if (request.url.path.endsWith('/stream')) {
            return http.StreamedResponse(events.stream, 200);
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(document(version)))),
            200,
          );
        }),
        apiBase: base,
        accessToken: () async => 'token-1',
        cache: MemoryDriverConfigCache(),
      );
      await config.start();
      await config.watch();
      final changed = Completer<void>();
      config.addListener(() {
        if (!changed.isCompleted) changed.complete();
      });
      version = 5;
      events.add(
        utf8.encode(
          'data: {"kind":"config_published","doc":"driver_app_config","zoneId":"Z001","version":5}\n\n',
        ),
      );
      await changed.future.timeout(const Duration(seconds: 2));
      expect(config.current?.version, 5);
      config.dispose();
      await events.close();
    },
  );

  test(
    'the server set the driver offline (driverOffline): the app follows',
    () {
      var offline = 0;
      final dispatch = ApiDispatchRepository(
        client: MockClient((_) async => http.Response('{}', 200)),
        baseUri: base,
        accessToken: () async => null,
      )..onDriverOffline = () => offline++;
      dispatch.ingest({
        'eventId': 'evt_1',
        'sequence': 1,
        'kind': 'offer_updated',
        'occurredAt': '2026-10-27T10:00:00Z',
        'serverTime': '2026-10-27T10:00:00Z',
        'driverOffline': true,
        'offer': {
          'offerId': 'ofr_1',
          'tripId': 'trp_1',
          'kind': 'exclusive',
          'status': 'declined',
        },
      });
      expect(offline, 1);
    },
  );

  test(
    'an accepted offer (Radar too) and going online start the row again',
    () {
      final answers = ExclusiveAnswers.instance;
      const rules = DriverOfferRules(autoOfflineAfter: 3);
      expect(answers.missed(rules), isFalse);
      expect(answers.missed(rules), isFalse);
      answers.accepted();
      expect(answers.missed(rules), isFalse);
      expect(answers.missed(rules), isFalse);
      expect(answers.missed(rules), isTrue);
    },
  );
}
