// BQ-V34 (contract v0.18.101 contract.json#sosContactsSms, owner 2026-11-02
// Q2 "Use them in SOS (Recommended)", Rules decisions/driver-g14.md:12): the
// driver's SOS texts his emergency contacts. The app reads
// SosReceipt.contactsSms and adds one line to "SOS sent" (queued / sent,
// not_connected, failed); the emergency contacts screen says whether they get
// an SMS from DriverAppConfig.sosContactsSms { on, connected }. Both fields
// are optional: without them the old "SOS sent" and no line.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/live/live_driver_config.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/emergency_numbers.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/presentation/driver/safety toolkits/safety_toolkits.dart';
import 'package:movera/presentation/driver/settings/emergency_contacts.dart';

const _sent = 'Your emergency contacts got an SMS with your position.';
const _notConnected = 'SMS to your emergency contacts is not connected yet.';
const _failed = 'The SMS to your emergency contacts could not be sent.';
const _on =
    'When you press SOS during a trip, they get an SMS with your position.';
const _off =
    'SMS to emergency contacts on SOS is not on yet. Call them from this page.';
const _old = 'Trusted contacts stay on this device. Calling opens your dialer.';

class _NoContacts extends SettingsRepository {
  @override
  Future<Map<String, dynamic>> read(String section) async => {'rows': []};
}

void main() {
  setUp(() {
    EmergencyNumbers.reset();
    SosContactsSmsConfig.reset();
  });
  tearDown(() {
    EmergencyNumbers.reset();
    SosContactsSmsConfig.reset();
  });

  ApiClient api(Map<String, Object?> receipt) => ApiClient(
    client: MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'driverId': 'drv_1', 'activeTripId': 'trp_1'}),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'incidentId': 'inc_1',
          'tripId': 'trp_1',
          'receivedAt': '2026-11-14T22:00:01Z',
          ...receipt,
        }),
        200,
      );
    }),
    baseUri: Uri.parse('https://api.example.test'),
    tokens: MemoryTokenStore(),
  );

  test('the SOS answer carries contactsSms; missing or bad is null', () async {
    final result = await DriverSos(
      api: api({
        'contactsSms': {
          'status': 'not_connected',
          'contacts': 2,
          'at': '2026-11-14T22:00:01Z',
        },
      }),
    ).sendWithReceipt();
    expect(result.outcome, DriverSosOutcome.sent);
    expect(result.contactsSms?.status, SosContactsSmsStatus.notConnected);
    expect(result.contactsSms?.contacts, 2);

    final sent = await DriverSos(
      api: api({
        'contactsSms': {'status': 'sent', 'contacts': 3, 'sent': 2, 'at': 'x'},
      }),
    ).sendWithReceipt();
    expect(sent.contactsSms?.status, SosContactsSmsStatus.sent);
    expect(sent.contactsSms?.sent, 2);

    expect((await DriverSos(api: api({})).sendWithReceipt()).contactsSms, null);
    expect(
      (await DriverSos(
        api: api({
          'contactsSms': {'status': 'maybe', 'contacts': 1},
        }),
      ).sendWithReceipt()).contactsSms,
      null,
    );
    // The old call still answers the outcome only.
    expect(await DriverSos(api: api({})).send(), DriverSosOutcome.sent);
  });

  Future<void> pressSos(WidgetTester tester, SosContactsSms? sms) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafetyToolKits(
            duringTrip: true,
            dialNumber: (number) async => true,
            sendSosResult: () async =>
                DriverSosResult(DriverSosOutcome.sent, contactsSms: sms),
            web: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-sos')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safety-sos-send')));
    await tester.pumpAndSettle();
  }

  SosContactsSms sms(String status) =>
      SosContactsSms.fromJson({'status': status, 'contacts': 2})!;

  for (final (status, line) in [
    ('queued', _sent),
    ('sent', _sent),
    ('not_connected', _notConnected),
    ('failed', _failed),
  ]) {
    testWidgets('"SOS sent" + the SMS line when $status', (tester) async {
      await pressSos(tester, sms(status));
      expect(find.text('SOS sent\n$line'), findsOneWidget);
    });
  }

  for (final status in ['off', 'no_contacts', null]) {
    testWidgets('"SOS sent" alone when ${status ?? 'no field'}', (
      tester,
    ) async {
      await pressSos(tester, status == null ? null : sms(status));
      expect(find.text('SOS sent'), findsOneWidget);
      for (final line in [_sent, _notConnected, _failed]) {
        expect(find.textContaining(line), findsNothing);
      }
    });
  }

  test('DriverAppConfig.sosContactsSms { on, connected } is read', () {
    expect(SosContactsSmsConfig.current, null);
    SosContactsSmsConfig.accept({'on': true, 'connected': false});
    expect(SosContactsSmsConfig.current?.on, true);
    expect(SosContactsSmsConfig.current?.connected, false);
    expect(SosContactsSmsConfig.current?.promised, false);
    SosContactsSmsConfig.accept({'on': 'yes'});
    expect(SosContactsSmsConfig.current?.on, true, reason: 'bad kept last');
    SosContactsSmsConfig.accept({'on': true, 'connected': true});
    expect(SosContactsSmsConfig.current?.promised, true);
  });

  test('the served driver config puts sosContactsSms in use', () async {
    final config = LiveDriverConfig(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'version': 1,
            'zoneId': 'Z001',
            'currency': 'SEK',
            'timeZone': 'Europe/Stockholm',
            'sosContactsSms': {'on': true, 'connected': false},
          }),
          200,
        ),
      ),
      apiBase: Uri.parse('https://api.movera.invalid/api/v1'),
      accessToken: () async => 'token-1',
      cache: MemoryDriverConfigCache(),
    );
    addTearDown(config.dispose);
    await config.start();
    expect(SosContactsSmsConfig.current?.on, true);
    expect(SosContactsSmsConfig.current?.connected, false);
  });

  Future<void> pumpContacts(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, child) => MaterialApp(home: child),
        child: EmergencyContactsScreen(repository: _NoContacts()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('contacts screen: on and connected says they get an SMS', (
    tester,
  ) async {
    SosContactsSmsConfig.accept({'on': true, 'connected': true});
    await pumpContacts(tester);
    expect(find.text(_on), findsOneWidget);
    expect(find.text(_off), findsNothing);
    expect(find.text(_old), findsNothing);
  });

  for (final served in [
    {'on': true, 'connected': false},
    {'on': false, 'connected': true},
  ]) {
    testWidgets('contacts screen: $served says the SMS is not on yet', (
      tester,
    ) async {
      SosContactsSmsConfig.accept(served);
      await pumpContacts(tester);
      expect(find.text(_off), findsOneWidget);
      expect(find.text(_on), findsNothing);
      expect(find.text(_old), findsNothing);
    });
  }

  testWidgets('contacts screen: no config field, no SMS line and never the '
      'wrong "stay on this device"', (tester) async {
    await pumpContacts(tester);
    expect(find.text(_on), findsNothing);
    expect(find.text(_off), findsNothing);
    expect(find.text(_old), findsNothing);
  });
}
