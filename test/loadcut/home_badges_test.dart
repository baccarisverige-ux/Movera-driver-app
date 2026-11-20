import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';

import '../onboarding/g2_fixtures.dart';

/// Contract v0.18.145 (`contract.json#loadCut.homeBadges`, S4c load cut):
/// Home's badges come from ONE `GET /driver/home-badges` instead of the four
/// reads (profile, unread notifications, reminders, onboarding settings);
/// an older server's 404 falls back to the four.
void main() {
  late List<String> sent;

  final reminder = {
    'kind': 'document_expiring',
    'level': 'due_soon',
    'title': 'Licence expires soon',
    'body': 'Upload a new one.',
  };
  final notice = {
    'notificationId': 'ntf_1',
    'kind': 'document_approved',
    'title': 'Approved',
    'body': 'Your document was approved.',
    'createdAt': '2026-11-20T09:00:00Z',
  };

  DriverAccountSession sessionWith(
    http.Response Function(String path) answer,
  ) => DriverAccountSession(
    repository: DriverAccountRepository(
      ApiClient(
        client: MockClient((request) async {
          sent.add(request.url.path);
          return answer(request.url.path);
        }),
        baseUri: Uri.parse('https://api.test.movera.se'),
        tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
      ),
    ),
  );

  http.Response oldServer(String path) => switch (path) {
    '/api/v1/driver/home-badges' => jsonResponse(404, {
      'code': 'not_found',
      'message': 'Not found.',
      'retryable': false,
    }),
    '/api/v1/driver/profile' => jsonResponse(200, profileJson()),
    '/api/v1/notifications' => jsonResponse(200, {
      'items': [notice],
      'nextCursor': null,
    }),
    '/api/v1/driver/reminders' => jsonResponse(200, {
      'items': [reminder],
      'blocksOnline': 0,
    }),
    '/api/v1/driver/onboarding/settings' => jsonResponse(
      200,
      settingsJson('SE'),
    ),
    _ => jsonResponse(404, {'code': 'not_found', 'message': 'x'}),
  };

  setUp(() {
    sent = [];
    homeBadgesMissing = false;
    DriverRemindersStore.instance = DriverRemindersStore();
    OnboardingSettingsStore.instance = OnboardingSettingsStore();
  });

  test('one GET /driver/home-badges fills all four badges', () async {
    final session = sessionWith(
      (path) => path == '/api/v1/driver/home-badges'
          ? jsonResponse(200, {
              'profile': profileJson(country: 'FR'),
              'notifications': {
                'items': [notice, notice],
                'nextCursor': null,
              },
              'reminders': {
                'items': [reminder],
                'blocksOnline': 0,
              },
              'onboardingSettings': settingsJson('FR'),
            })
          : jsonResponse(500, {'code': 'internal', 'message': 'x'}),
    );
    var after = 0;
    await refreshHomeBadges(session, afterProfile: () => after++);
    expect(sent, ['/api/v1/driver/home-badges']);
    expect(after, 1);
    expect(session.account?.country, 'FR');
    expect(session.unreadNotifications.value, 2);
    expect(DriverRemindersStore.instance.items, hasLength(1));
    expect(OnboardingSettingsStore.instance.settings, isNotNull);
    expect(OnboardingSettingsStore.instance.country, 'FR');
  });

  test('no country yet (onboardingSettings null): the other three are '
      'used, nothing else is asked', () async {
    final session = sessionWith(
      (_) => jsonResponse(200, {
        'profile': profileJson(),
        'notifications': {'items': <Object>[], 'nextCursor': null},
        'reminders': {'items': <Object>[], 'blocksOnline': 0},
        'onboardingSettings': null,
      }),
    );
    await refreshHomeBadges(session);
    expect(sent, ['/api/v1/driver/home-badges']);
    expect(session.account, isNotNull);
    expect(OnboardingSettingsStore.instance.settings, isNull);
  });

  test('an older server (404): the four reads, and home-badges is not '
      'asked again', () async {
    final session = sessionWith(oldServer);
    var after = 0;
    await refreshHomeBadges(session, afterProfile: () => after++);
    expect(sent.first, '/api/v1/driver/home-badges');
    expect(sent.skip(1).toSet(), {
      '/api/v1/driver/profile',
      '/api/v1/notifications',
      '/api/v1/driver/reminders',
      '/api/v1/driver/onboarding/settings',
    });
    expect(after, 1);
    expect(session.unreadNotifications.value, 1);
    expect(DriverRemindersStore.instance.items, hasLength(1));
    sent.clear();
    await refreshHomeBadges(session);
    expect(sent, isNot(contains('/api/v1/driver/home-badges')));
    expect(sent, hasLength(4));
  });

  test(
    'a server fault keeps every badge as it was (no burst of the four)',
    () async {
      final session = sessionWith(
        (_) => jsonResponse(503, {
          'code': 'unavailable',
          'message': 'Busy.',
          'retryable': true,
        }),
      );
      session.unreadNotifications.value = 3;
      var after = 0;
      await refreshHomeBadges(session, afterProfile: () => after++);
      expect(sent, ['/api/v1/driver/home-badges']);
      expect(session.unreadNotifications.value, 3);
      expect(after, 1);
      expect(homeBadgesMissing, isFalse);
    },
  );

  test('the answer reads as the four reads read: hidden kinds are not '
      'counted', () async {
    final hidden = {
      ...notice,
      'notificationId': 'ntf_2',
      'kind': 'surge_started',
    };
    final session = sessionWith(
      (_) => jsonResponse(200, {
        'profile': profileJson(),
        'notifications': {
          'items': [notice, hidden],
          'nextCursor': null,
        },
        'reminders': {'items': <Object>[], 'blocksOnline': 0},
        'onboardingSettings': null,
      }),
    );
    final badges = await session.repository.homeBadges();
    expect(badges.unread.map((n) => n.notificationId), ['ntf_1']);
    expect(jsonEncode(badges.profile.driverId), '"drv_1"');
    expect(
      DriverAccountRepository.homeBadgesPath,
      '/api/v1/driver/home-badges',
    );
  });
}
