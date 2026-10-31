import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/core/contracts/driver_app_config.dart';
import 'package:movera/core/dispatch/api_dispatch_repository.dart';
import 'package:movera/core/dispatch/dispatch_repository.dart';
import 'package:movera/core/dispatch/offer_rules.dart';
import 'package:movera/core/push/offer_push.dart';
import 'package:movera/core/push/push_platform.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/device_sound_io.dart';
import 'package:movera/core/sound/radar_offer_sound.dart';
import 'package:movera/presentation/driver/accept%20ride/accept_ride.dart';
import 'package:movera/presentation/driver/home/components/exclusive_request_sheet.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:movera/presentation/driver/settings/accessibility/accessibility.dart';
import 'package:movera/widgets/layout_viewport.dart';
import 'package:movera/widgets/radar_offer_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import '../../integration_test/headless_map_platform.dart';

/// Driver group 4 "Incoming offer & exclusive offer" (contract v0.18.6
/// §31, Rules decisions/driver-g4.md decisions 1–7 and owner answers
/// G4-E1..E7). One group per decision; each test fails on the build
/// before this job.

Map<String, dynamic> get _contract =>
    jsonDecode(File('contracts/contract.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Object? _at(Map<String, dynamic> root, String path) {
  Object? node = root;
  for (final key in path.split('.')) {
    node = (node as Map<String, dynamic>)[key];
  }
  return node;
}

/// Contract `Offer` (openapi.yaml#Offer).
Map<String, dynamic> _wire({
  String id = 'o1',
  String kind = 'exclusive',
  String status = 'open',
  int version = 1,
  Object? riderRating,
  DateTime? expiresAt,
}) => {
  'offerId': id,
  'tripId': 'trip-$id',
  'kind': kind,
  'status': status,
  'version': version,
  'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(seconds: 15)))
      .toUtc()
      .toIso8601String(),
  'fare': {'amountMinor': 8810, 'currency': 'SEK'},
  'source': 'system',
  'riderRating': ?riderRating,
  'pickup': {
    'address': 'Tegnérgatan, Stockholm',
    'lat': 59.3335,
    'lng': 18.0610,
  },
  'dropoff': {
    'address': 'Odengatan, Stockholm',
    'lat': 59.3428,
    'lng': 18.0475,
  },
  'categoryId': 'comfort',
  'paymentMethod': 'card',
  'pickupEtaSeconds': 180,
  'pickupMeters': 900,
  'tripSeconds': 720,
  'tripMeters': 5200,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// The contract adapter over a scripted server; each new Idempotency-Key
/// is a new number.
class _Api {
  _Api({
    Duration answerTimeout = const Duration(seconds: 8),
    this.checkFor = const Duration(milliseconds: 60),
    this.stopwatch,
  }) : _answerTimeout = answerTimeout;

  final Duration _answerTimeout;
  final Duration checkFor;
  final Stopwatch Function()? stopwatch;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
  final List<FutureOr<Object> Function(http.BaseRequest request)> answers = [];
  final List<Map<String, dynamic>> accepted = [];
  var _keys = 0;

  late final ApiDispatchRepository repo = ApiDispatchRepository(
    client: MockClient((request) async {
      requests.add(request);
      final answer = await answers.removeAt(0)(request);
      if (answer is http.Response) return answer;
      throw answer;
    }),
    baseUri: Uri.parse('https://api.dev.movera.invalid/api/v1'),
    accessToken: () async => 'token',
    idempotencyKey: () => 'key-${++_keys}',
    onAccepted: accepted.add,
    acceptAnswerTimeout: _answerTimeout,
    acceptCheckEvery: const Duration(milliseconds: 10),
    acceptCheckFor: checkFor,
    stopwatch: stopwatch,
  );

  Future<void> open(List<Map<String, dynamic>> offers) async {
    answers.add((_) => _json({'items': offers, 'nextCursor': null}));
    final listed = repo.watchNearbyOffers().skip(1).first;
    repo.refreshOffers();
    await listed;
    requests.clear();
  }

  List<String> get paths => [
    for (final r in requests) '${r.method} ${r.url.path}',
  ];

  List<String?> get keys => [
    for (final r in requests) r.headers['Idempotency-Key'],
  ];
}

/// A stopwatch that moves on [step] each time it is read (fake time).
class _JumpingStopwatch implements Stopwatch {
  _JumpingStopwatch(this.step);
  final Duration step;
  Duration _now = Duration.zero;
  int reads = 0;

  @override
  Duration get elapsed {
    reads++;
    return _now += step;
  }

  @override
  void start() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _accept = 'POST /api/v1/offers/o1/accept';
const _check = 'GET /api/v1/driver/offers/o1';

/// A dispatch whose Accept answers when the test says.
class _Dispatch implements DispatchRepository {
  _Dispatch(this.offers);
  final List<RideOffer> offers;
  final Completer<ClaimResult> claim = Completer<ClaimResult>();
  int claims = 0;
  int refreshes = 0;
  @override
  Stream<List<RideOffer>> watchNearbyOffers({
    bool destinationModeActive = false,
  }) => Stream.value(offers);
  @override
  Stream<List<RideOffer>> watchNextTripOffers() =>
      Stream.value(const <RideOffer>[]);
  @override
  void refreshOffers() => refreshes++;
  @override
  void releaseReservation(String reservationId) {}
  @override
  Stream<ReservationRequestPreview> watchAssignments() =>
      const Stream<ReservationRequestPreview>.empty();
  @override
  Future<ClaimResult> claimOffer(String offerId) {
    claims++;
    return claim.future;
  }

  @override
  Future<bool> declineOffer(String offerId, {String? reasonCode}) async =>
      false;
  @override
  Stream<OfferWithdrawal> watchWithdrawals() =>
      const Stream<OfferWithdrawal>.empty();
}

class _Sound implements RadarSoundPlayer {
  final calls = <String>[];
  @override
  Future<void> startLoop() async => calls.add('start');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> prime() async {}
  @override
  Future<void> dispose() async {}
}

Future<void> _until(WidgetTester tester, Finder finder, Duration limit) async {
  for (
    var t = Duration.zero;
    t < limit && finder.evaluate().isEmpty;
    t += const Duration(milliseconds: 100)
  ) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Home with [dispatch], online.
Future<void> _online(WidgetTester tester, DispatchRepository dispatch) async {
  final maps = GoogleMapsFlutterPlatform.instance;
  GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
  addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    LayoutViewport(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        useInheritedMediaQuery: true,
        builder: (_, _) => MaterialApp(
          home: DriverHome(
            sessionController: DriverSessionController(),
            dispatchRepository: dispatch,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
  tester
      .widget<GestureDetector>(
        find.byKey(const ValueKey<String>('trip-radar-touch-target')),
      )
      .onTap!
      .call();
}

Future<void> _closeHome(WidgetTester tester) async {
  tester.takeException();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

RadarOfferView _view({String rating = '4.87'}) => RadarOfferView(
  id: 'r1',
  category: 'Comfort',
  payment: 'Card',
  rating: rating,
  fare: '120,70 kr',
  pickupMinutes: 4,
  pickupKm: 1.2,
  tripMinutes: 12,
  tripKm: 5.2,
  pickup: 'Odengatan 63, Stockholm',
  dropoff: 'Solna centrum, Solna',
);

Future<void> _pumpCard(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(375, 812));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: card)),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    OfferAlertSettings.reset();
    DriverOfferRules.current = const DriverOfferRules(autoOffline: false);
  });
  tearDown(() {
    DriverOfferRules.current = const DriverOfferRules();
    RadarOfferSound.debugPlayer = null;
    OfferVibration.debugVibrate = null;
    PhoneSoundCheck.debugRead = null;
  });

  test('every v0.18.6 offer text the app shows is the contract\'s, '
      'in sv, fr, en', () {
    const keys = {
      'offerAccepting': 'driverOffers.acceptCheck.texts.accepting',
      'offerNoLongerAvailable': 'driverOffers.acceptCheck.texts.gone',
      'riderRatingLabel': 'driverOffers.riderRating.texts.label',
      'tipHighBoostNearby': 'driverSurgeMap.tipTexts',
    };
    for (final lang in ['sv', 'fr', 'en']) {
      final arb = _arb(lang);
      keys.forEach((key, path) {
        expect(
          arb[key],
          (_at(_contract, path) as Map<String, dynamic>)[lang],
          reason: '$lang $key',
        );
      });
    }
  });

  group('decision 1 + E6: offer push, sound and vibration', () {
    test('Exclusive and hand-sent ring, Radar and reservations stay quiet, '
        'as contract.json#driverOffers.push says', () {
      final push = _contract['driverOffers']['push'] as Map<String, dynamic>;
      for (final kind in ['exclusive', 'assigned', 'radar']) {
        final loud = push['sound'][kind] == 'offer';
        expect(OfferAlertRule.loudWire(kind), loud, reason: kind);
        expect(push['vibrate'][kind], loud, reason: kind);
      }
      expect(OfferAlertRule.loud(OfferKind.reservation), isFalse);
      expect(OfferAlertRule.loud(OfferKind.nextTrip), isFalse);
      expect(OfferAlertRule.loud(null), isFalse);
      expect(
        OfferAlertRule.vibratePattern,
        push['native']['webVibratePattern'],
      );
    });

    test('a new-offer push tap knows its offer; other pushes do not', () {
      expect(
        const PushOpen(
          notificationId: 'ntf_1',
          deepLink: 'movera-driver://offers/off_42',
        ).offerId,
        'off_42',
      );
      expect(
        const PushOpen(
          notificationId: 'ntf_2',
          deepLink: 'movera-driver://documents',
        ).offerId,
        isNull,
      );
      expect(const PushOpen(notificationId: 'ntf_3').offerId, isNull);
      expect(
        (_contract['driverOffers']['push']['deepLink'] as String).replaceAll(
          '{offerId}',
          'x',
        ),
        'movera-driver://offers/x',
      );
    });

    testWidgets('a tap on an offer push opens Home (the offer card shows '
        'there while open) and asks the open offers again; on a trip the '
        'screen stays', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const Text('home')),
      );
      unawaited(
        key.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Text('settings')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget);
      final dispatch = _Dispatch(const []);
      openOfferPush(
        key.currentState!,
        availableForOffers: false,
        dispatch: dispatch,
      );
      await tester.pumpAndSettle();
      expect(find.text('settings'), findsOneWidget, reason: 'on a trip');
      expect(dispatch.refreshes, 1);
      openOfferPush(
        key.currentState!,
        availableForOffers: true,
        dispatch: dispatch,
      );
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(find.text('settings'), findsNothing);
      expect(dispatch.refreshes, 2);
    });

    test('web service worker: Exclusive/hand-sent sound + vibration only '
        'with the Vibrate setting, Radar quiet, nothing on screen or after '
        'expiresAt (node tool/verify_offer_push_sw.cjs)', () async {
      final run = await Process.run('node', ['tool/verify_offer_push_sw.cjs']);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      expect('${run.stdout}', contains('offer push service worker: ok'));
    });

    test('the page script keeps the Vibrate setting where the worker reads '
        'it', () {
      final page = File('web/movera_push.js').readAsStringSync();
      final worker = File('web/firebase-messaging-sw.js').readAsStringSync();
      expect(page, contains('setOfferPrefs'));
      for (final name in ["'movera-push-prefs'", "'movera-push-prefs.json'"]) {
        expect(page, contains(name));
        expect(worker, contains(name));
      }
    });

    test('the Vibrate setting is read from Settings › Accessibility', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsRepository();
      await settings.save('accessibility', {'flash': false, 'vibration': true});
      await OfferAlertSettings.restore(repository: settings);
      expect(OfferAlertSettings.vibrate.value, isTrue);
      await settings.save('accessibility', {'vibration': false});
      await OfferAlertSettings.restore(repository: settings);
      expect(OfferAlertSettings.vibrate.value, isFalse);
    });

    testWidgets('Vibration for requests starts on for every driver (owner '
        '2026-10-31); turning it off stops the offer vibration at once', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: Accessibility()));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch).last).value, isTrue);
      expect(OfferAlertSettings.vibrate.value, isTrue);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch).last).value, isFalse);
      expect(OfferAlertSettings.vibrate.value, isFalse);
      final saved = await tester.runAsync(
        () => SettingsRepository().read('accessibility'),
      );
      expect(saved?['vibration'], isFalse);
    });

    test('nothing saved yet: the Vibrate setting is on', () async {
      SharedPreferences.setMockInitialValues({});
      OfferAlertSettings.vibrate.value = false;
      await OfferAlertSettings.restore(repository: SettingsRepository());
      expect(OfferAlertSettings.vibrate.value, isTrue);
      OfferAlertSettings.vibrate.value = false;
      OfferAlertSettings.reset();
      expect(OfferAlertSettings.vibrate.value, isTrue);
    });

    test('one vibration per new ringing offer, only with the setting on', () {
      final buzz = <List<int>>[];
      OfferVibration.debugVibrate = buzz.add;
      final sound = RadarOfferSound(
        player: _Sound(),
        onNewOffer: OfferVibration.forNewOffer,
      );
      sound.sync(['a']);
      expect(buzz, [OfferAlertRule.vibratePattern], reason: 'on by default');
      sound.sync(['a']);
      expect(buzz, hasLength(1), reason: 'once per offer');
      sound.sync(const []);
      OfferAlertSettings.vibrate.value = false;
      sound.sync(['b']);
      expect(buzz, hasLength(1), reason: 'turned off');
      sound.dispose();
    });

    testWidgets('Home: an Exclusive offer rings and vibrates (setting on); '
        'a Radar offer stays quiet', (tester) async {
      final player = _Sound();
      RadarOfferSound.debugPlayer = player;
      final buzz = <List<int>>[];
      OfferVibration.debugVibrate = buzz.add;
      OfferAlertSettings.vibrate.value = true;
      await _online(
        tester,
        _Dispatch([
          OfferWire.parse(_wire(id: 'r1', kind: 'radar')),
          OfferWire.parse(_wire(id: 'x1', kind: 'exclusive')),
        ]),
      );
      final card = find.byKey(
        const ValueKey<String>('exclusive-offer-card-x1'),
      );
      await _until(tester, card, const Duration(seconds: 5));
      expect(card, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(player.calls, ['start']);
      expect(buzz, hasLength(1));
      await _closeHome(tester);
    });
    // Radar offers on Home making no sound: test/widget_test.dart
    // 'Exclusive Radar stays separate …' (G4-E6 lines).
  });

  group('decision 2: the phone\'s sound is off while online', () {
    testWidgets('a notice at the top of Home while online; gone when the '
        'sound is back', (tester) async {
      var sound = PhoneSound.off;
      PhoneSoundCheck.debugRead = () async => sound;
      await _online(tester, _Dispatch(const []));
      const notice = ValueKey<String>('home-sound-off-notice');
      await _until(tester, find.byKey(notice), const Duration(seconds: 3));
      expect(find.byKey(notice), findsOneWidget);
      expect(find.text('Sound is off – you may miss offers'), findsOneWidget);
      // It sits at the top, under the island.
      expect(tester.getTopLeft(find.byKey(notice)).dy, lessThan(812 / 3));
      sound = PhoneSound.on;
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(find.byKey(notice), findsNothing);
      await _closeHome(tester);
    });

    testWidgets('offline, or a phone that cannot tell: no notice', (
      tester,
    ) async {
      PhoneSoundCheck.debugRead = () async => PhoneSound.unknown;
      await _online(tester, _Dispatch(const []));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.byKey(const ValueKey<String>('home-sound-off-notice')),
        findsNothing,
      );
      await _closeHome(tester);
    });

    test('the notice texts are in sv, fr and en', () {
      expect(
        _arb('sv')['soundOffNotice'],
        'Ljudet är av – du kan missa '
        'erbjudanden',
      );
      expect(
        _arb('fr')['soundOffNotice'],
        'Le son est coupé – vous risquez de manquer des offres',
      );
      expect(
        _arb('en')['soundOffNotice'],
        'Sound is off – you may miss offers',
      );
    });

    test('native ringer: silent or very low is off, normal is on, no '
        'answer is unknown', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Map<String, Object?>? answer;
      messenger.setMockMethodCallHandler(phoneSoundChannel, (call) async {
        expect(call.method, 'state');
        return answer;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(phoneSoundChannel, null),
      );
      answer = {'silent': true, 'volume': 0.8};
      expect(await deviceSoundState(), PhoneSound.off);
      answer = {'silent': false, 'volume': 0.1};
      expect(await deviceSoundState(), PhoneSound.off);
      answer = {'silent': false, 'volume': 0.6};
      expect(await deviceSoundState(), PhoneSound.on);
      answer = null;
      expect(await deviceSoundState(), PhoneSound.unknown);
      messenger.setMockMethodCallHandler(phoneSoundChannel, (call) async {
        throw PlatformException(code: 'x');
      });
      expect(await deviceSoundState(), PhoneSound.unknown);
      messenger.setMockMethodCallHandler(phoneSoundChannel, null);
      expect(await deviceSoundState(), PhoneSound.unknown);
      expect(await PhoneSoundCheck.read(), PhoneSound.unknown);
    });
  });

  group('decision 3: the rider\'s real rating, no made-up value', () {
    test('Offer.riderRating is kept; without it there is none', () {
      expect(OfferWire.parse(_wire(riderRating: 4.87)).rating, '4.87');
      expect(OfferWire.parse(_wire()).rating, '');
      expect(OfferWire.parse(_wire(riderRating: 9)).rating, '');
      expect(RadarOfferView.shownRatingOf('4.87'), '4.9');
      expect(RadarOfferView.shownRatingOf('5'), '5.0');
      expect(RadarOfferView.shownRatingOf(''), isNull);
      expect(RadarOfferView.shownRatingOf('—'), isNull);
    });

    for (final (name, build, key)
        in <(String, Widget Function(RadarOfferView), String)>[
          (
            'Radar card',
            (v) => RadarOfferCard(offer: v, onMatch: () {}),
            'radar-offer-rating-r1',
          ),
          (
            'Exclusive sheet',
            (v) => ExclusiveRequestSheet(offer: v, secondsLeft: 12),
            'exclusive-offer-rating-r1',
          ),
        ]) {
      testWidgets('$name: "★ 4.9" with a rating and the zone switch on; '
          'nothing without one or with the switch off', (tester) async {
        await _pumpCard(tester, build(_view()));
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        expect(find.text('4.9'), findsOneWidget);
        expect(find.bySemanticsLabel('Rider rating 4.9'), findsOneWidget);

        await _pumpCard(tester, build(_view(rating: '')));
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
        expect(find.text('4.9'), findsNothing);

        DriverOfferRules.current = DriverOfferRules.current.withOffers({
          'offerCard': {'riderRating': false},
        });
        await _pumpCard(tester, build(_view()));
        expect(find.byKey(ValueKey<String>(key)), findsNothing);
      });
    }

    test('the zone switch comes from offers.offerCard.riderRating '
        '(default on)', () {
      expect(const DriverOfferRules().card.riderRating, isTrue);
      final sample = jsonDecode(
        File(
          'contracts/fixtures/config/driver_app_config.json',
        ).readAsStringSync(),
      );
      expect(sample['offers']['offerCard']['riderRating'], isTrue);
      expect(
        const DriverOfferRules()
            .withOffers({
              'offerCard': {'riderRating': false},
            })
            .card
            .riderRating,
        isFalse,
      );
    });

    test('no 4.9 fallback is left in the offer code', () {
      for (final path in [
        'lib/presentation/driver/ride requests/ride_requests.dart',
        'lib/presentation/driver/accept ride/accept_ride.dart',
        'lib/core/dispatch/api_dispatch_repository.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('4.9,')),
          reason: path,
        );
        expect(File(path).readAsStringSync(), isNot(contains('?? 4.9')));
      }
    });
  });

  group('decision 3 on the trip: the rider sheet', () {
    for (final (rating, on, shown) in const [
      (4.86, true, '4.9 ★ · 3 rides'),
      (null, true, '3 rides'),
      (4.86, false, '3 rides'),
    ]) {
      testWidgets('rating $rating, zone switch $on: "$shown"', (tester) async {
        DriverOfferRules.current = DriverOfferRules.current.withOffers({
          'offerCard': {'riderRating': on},
        });
        final maps = GoogleMapsFlutterPlatform.instance;
        GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
        addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: AcceptRide(
              riderName: 'Angelica',
              riderRating: rating,
              riderTrips: 3,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 160));
        // The rider row is on the middle sheet.
        tester
            .widgetList<SlidingUpPanel>(find.byType(SlidingUpPanel))
            .last
            .controller!
            .animatePanelToSnapPoint();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 520));
        await tester.pump(const Duration(milliseconds: 300));
        final name = find.ancestor(
          of: find.text('Angelica'),
          matching: find.byType(InkWell),
        );
        tester.widget<InkWell>(name.first).onTap!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(shown), findsOneWidget);
        expect(find.textContaining('New'), findsNothing);
        tester.takeException();
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  group('decision 4: Accept on a bad connection', () {
    test('lost answer, the check says it is his: the trip opens', () async {
      final api = _Api();
      await api.open([_wire()]);
      final trip = {'tripId': 'trip-o1', 'status': 'driver_assigned'};
      api.answers
        ..add((_) => http.ClientException('connection dropped'))
        ..add(
          (_) => _json({
            'offer': _wire(status: 'claimed', version: 2),
            'trip': trip,
          }),
        );
      final result = await api.repo.claimOffer('o1');
      expect(result.isSuccess, isTrue);
      expect(result.afterCheck, isTrue);
      expect(api.accepted, [trip]);
      expect(api.paths, [_accept, _check]);
    });

    test('no answer within answerTimeoutSeconds counts as lost', () async {
      final api = _Api(answerTimeout: const Duration(milliseconds: 30));
      await api.open([_wire()]);
      api.answers
        ..add((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return _json({'tripId': 'trip-o1'});
        })
        ..add(
          (_) => _json({
            'offer': _wire(status: 'claimed'),
            'trip': {'tripId': 'trip-o1'},
          }),
        );
      expect((await api.repo.claimOffer('o1')).isSuccess, isTrue);
      expect(api.paths, [_accept, _check]);
      expect(
        _contract['driverOffers']['acceptCheck']['answerTimeoutSeconds'],
        8,
      );
    });

    test('still open: the same Accept with the same Idempotency-Key', () async {
      final api = _Api();
      await api.open([_wire()]);
      api.answers
        ..add((_) => http.ClientException('connection dropped'))
        ..add((_) => _json({'offer': _wire()}))
        ..add((_) => _json({'tripId': 'trip-o1'}));
      expect((await api.repo.claimOffer('o1')).isSuccess, isTrue);
      expect(api.paths, [_accept, _check, _accept]);
      expect(api.keys, ['key-1', null, 'key-1']);
    });

    for (final (status, outcome) in const [
      ('claimed_elsewhere', ClaimOutcome.alreadyClaimed),
      ('expired', ClaimOutcome.expired),
      ('withdrawn', ClaimOutcome.unavailable),
      ('declined', ClaimOutcome.unavailable),
    ]) {
      test('$status: gone, "Offer no longer available"', () async {
        final api = _Api();
        await api.open([_wire()]);
        final gone = api.repo.watchWithdrawals().first;
        api.answers
          ..add((_) => http.ClientException('connection dropped'))
          ..add((_) => _json({'offer': _wire(status: status)}));
        final result = await api.repo.claimOffer('o1');
        expect(result.outcome, outcome);
        expect(result.afterCheck, isTrue);
        expect((await gone).offerId, 'o1');
      });
    }

    test('an open offer past its expiresAt is gone', () async {
      final api = _Api();
      await api.open([_wire()]);
      api.answers
        ..add((_) => http.ClientException('connection dropped'))
        ..add(
          (_) => _json({
            'offer': _wire(
              expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
            ),
          }),
        );
      final result = await api.repo.claimOffer('o1');
      expect(result.outcome, ClaimOutcome.expired);
      expect(result.afterCheck, isTrue);
      expect(api.paths, [_accept, _check]);
    });

    test('404 offer_not_found: gone', () async {
      final api = _Api();
      await api.open([_wire()]);
      api.answers
        ..add((_) => http.ClientException('connection dropped'))
        ..add((_) => _json({'code': 'offer_not_found'}, 404));
      final result = await api.repo.claimOffer('o1');
      expect(result.outcome, ClaimOutcome.unavailable);
      expect(result.afterCheck, isTrue);
    });

    test('the check itself fails: asked again every checkEverySeconds, '
        'then a network error after checkForSeconds', () async {
      final api = _Api();
      await api.open([_wire()]);
      api.answers.add((_) => http.ClientException('connection dropped'));
      for (var i = 0; i < 20; i++) {
        api.answers.add(
          (_) =>
              i.isEven ? http.ClientException('still offline') : _json({}, 503),
        );
      }
      final result = await api.repo.claimOffer('o1');
      expect(result.outcome, ClaimOutcome.networkError);
      final checks = api.paths.where((p) => p == _check).length;
      expect(checks, greaterThanOrEqualTo(3));
      expect(checks, lessThanOrEqualTo(8));
      final check = _contract['driverOffers']['acceptCheck'];
      expect([check['checkEverySeconds'], check['checkForSeconds']], [2, 20]);
    });

    test('the check stops after checkForSeconds on a stopwatch, whatever '
        'the number of checks left (fake time)', () async {
      final watch = _JumpingStopwatch(const Duration(seconds: 5));
      final api = _Api(
        checkFor: const Duration(seconds: 20),
        stopwatch: () => watch,
      );
      await api.open([_wire()]);
      api.answers.add((_) => http.ClientException('connection dropped'));
      for (var i = 0; i < 50; i++) {
        api.answers.add((_) => http.ClientException('still offline'));
      }
      // 10 ms apart, 20 s would allow 2000 checks; the stopwatch says
      // 5 s pass per check, so it stops at 20 s.
      final result = await api.repo.claimOffer('o1');
      expect(result.outcome, ClaimOutcome.networkError);
      final checks = api.paths.where((p) => p == _check).length;
      expect(checks, inInclusiveRange(3, 4));
    });

    test('a check that hangs is given up when the next one is due', () async {
      final api = _Api();
      await api.open([_wire()]);
      api.answers.add((_) => http.ClientException('connection dropped'));
      for (var i = 0; i < 20; i++) {
        api.answers.add((_) => Completer<Object>().future);
      }
      final started = DateTime.now();
      final result = await api.repo.claimOffer('o1');
      expect(result.outcome, ClaimOutcome.networkError);
      expect(api.paths.where((p) => p == _check).length, greaterThan(1));
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 3)),
        reason: 'each check waits checkEverySeconds at most, not 8 s',
      );
    });

    testWidgets('Home: the first tap locks Accept and says "Accepting…"; '
        'gone after the check: "Offer no longer available", not a miss', (
      tester,
    ) async {
      DriverOfferRules.current = const DriverOfferRules(autoOfflineAfter: 1);
      ExclusiveAnswers.instance.reset();
      final dispatch = _Dispatch([OfferWire.parse(_wire(id: 'x1'))]);
      await _online(tester, dispatch);
      final card = find.byKey(
        const ValueKey<String>('exclusive-offer-card-x1'),
      );
      await _until(tester, card, const Duration(seconds: 5));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final orb = find.byKey(const ValueKey<String>('home-radar-exclusive'));
      await tester.tap(orb);
      await tester.pump(const Duration(milliseconds: 50));
      expect(dispatch.claims, 1);
      expect(find.text('Accepting…'), findsWidgets);
      await tester.tap(orb, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(dispatch.claims, 1, reason: 'locked after the first tap');
      dispatch.claim.complete(const ClaimResult.unavailable(afterCheck: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // On the island at the top of Home (decision 5), 2 s, not a miss.
      final gone = IslandMessages.posted.where(
        (m) => m.title == 'Offer no longer available',
      );
      expect(gone, hasLength(1));
      expect(gone.single.priority.duration, const Duration(seconds: 2));
      expect(IslandMessages.posted.map((m) => m.title), contains('Accepting…'));
      expect(ExclusiveAnswers.instance.missedInRow, 0);
      await _closeHome(tester);
    });
  });

  group('decision 7: no warning before auto-offline', () {
    testWidgets('the 9th missed offer of 10 shows nothing on the island; '
        'the driver stays online', (tester) async {
      DriverOfferRules.current = const DriverOfferRules();
      final answers = ExclusiveAnswers.instance..reset();
      for (var i = 0; i < 8; i++) {
        answers.missed();
      }
      final session = DriverSessionController();
      final maps = GoogleMapsFlutterPlatform.instance;
      GoogleMapsFlutterPlatform.instance = HeadlessMapPlatform();
      addTearDown(() => GoogleMapsFlutterPlatform.instance = maps);
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        LayoutViewport(
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            splitScreenMode: true,
            useInheritedMediaQuery: true,
            builder: (_, _) => MaterialApp(
              home: DriverHome(
                sessionController: session,
                dispatchRepository: _Dispatch([
                  OfferWire.parse(_wire(id: 'x1')),
                ]),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey<String>('trip-radar-touch-target')),
          )
          .onTap!
          .call();
      final card = find.byKey(
        const ValueKey<String>('exclusive-offer-card-x1'),
      );
      await _until(tester, card, const Duration(seconds: 5));
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      IslandMessages.posted.clear();
      await tester.tap(
        find.byKey(const ValueKey<String>('direct-offer-dismiss')),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(answers.missedInRow, 9);
      expect(
        IslandMessages.posted.map((m) => m.title),
        isNot(contains(contains('offline'))),
      );
      expect(session.availableForOffers, isTrue);
      expect(_arb('en').containsKey('islandLastMissed'), isFalse);
      await _closeHome(tester);
    });
  });

  group('decision 6 / E3: the phone counts like the server', () {
    test('Exclusive and hand-sent count; reservations and scheduled rides '
        'Movera assigned never; a live build leaves it to the server', () {
      expect(
        ExclusiveAnswers.counts(
          live: false,
          reservation: false,
          scheduledAssignment: false,
        ),
        isTrue,
      );
      expect(
        ExclusiveAnswers.counts(
          live: false,
          reservation: true,
          scheduledAssignment: false,
        ),
        isFalse,
      );
      expect(
        ExclusiveAnswers.counts(
          live: false,
          reservation: false,
          scheduledAssignment: true,
        ),
        isFalse,
      );
      expect(
        ExclusiveAnswers.counts(
          live: true,
          reservation: false,
          scheduledAssignment: false,
        ),
        isFalse,
      );
      expect(_contract['autoOffline']['counts'], ['exclusive', 'assigned']);
    });
  });

  group('decision 6 / E2: auto-offline after 10 in every seed zone', () {
    for (final zone in ['Z001', 'FR-PC', 'TN-TC']) {
      test('$zone seed config: 10, no exclusiveReasons', () {
        final json =
            jsonDecode(
                  File(
                    'test/fixtures/config/driver_app_config.$zone.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(json['offers']['autoOffline']['missedExclusive'], 10);
        expect((json['offers'] as Map).containsKey('exclusiveReasons'), false);
        final config = DriverAppConfig.fromJson(json);
        expect(config.missedExclusiveBeforeOffline, 10);
      });
    }
  });

  group('E7: no "why you got this trip" line', () {
    test('offers.exclusiveReasons from a zone document is ignored', () {
      final rules = const DriverOfferRules().withOffers({
        'exclusiveReasons': [
          {'id': 'nearby', 'text': 'Why you: close by', 'on': true},
        ],
      });
      expect(rules.reasonText('nearby'), isNot('Why you: close by'));
    });

    test('the Exclusive pill says "Exclusive for you", or "Assigned by '
        'Movera" for a hand-sent one', () {
      expect(ExclusiveRequestSheet.pillLabel(9), 'Exclusive for you · 9 s');
      final source = File(
        'lib/presentation/driver/home/home_offer_radar.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('offer.reasonCode')));
    });
  });

  group('self-check: no surge word in any driver text', () {
    test('sv / fr / en texts have none of driverSurgeMap.forbiddenWords', () {
      final forbidden =
          _contract['driverSurgeMap']['forbiddenWords'] as Map<String, dynamic>;
      for (final lang in ['sv', 'fr', 'en']) {
        final arb = _arb(lang);
        final words = [
          for (final word in forbidden[lang] as List) word as String,
        ];
        arb.forEach((key, value) {
          if (key.startsWith('@') || value is! String) return;
          for (final word in words) {
            expect(
              value.toLowerCase().contains(word),
              isFalse,
              reason: '$lang $key: "$value" says "$word"',
            );
          }
        });
      }
    });
  });

  group('re-check LOW: the Radar orb', () {
    test('Swedish keeps "Acceptera · TA" (owner 2026-10-31)', () {
      expect(_arb('sv')['offerAccept'], 'Acceptera');
      expect(_arb('sv')['orbMatch'], 'TA');
    });
  });
}
