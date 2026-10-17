import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/geo/geo_point.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_controller.dart';
import 'package:movera/core/safety/ride_check_detector.dart';
import 'package:movera/core/safety/ride_check_log.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dropoff = GeoPoint(59.3326, 18.0649);
final _t0 = DateTime(2026, 10, 15, 14, 30);

/// About [meters] north of [from].
GeoPoint _north(GeoPoint from, double meters) =>
    GeoPoint(from.latitude + meters / 111195, from.longitude);

const _trip = SafetyAlertTrip(
  tripId: 'trip-1',
  riderName: 'Angelica',
  riderRating: 4.9,
  pickup: 'Odlarvägen 22',
  dropoff: 'T-Centralen, Stockholm',
  fare: '126 kr',
  category: 'Comfort',
  driverName: 'Movera Driver',
  vehicle: 'Volvo XC60',
  plate: 'ABC 123',
);

class _Recorder implements RideCheckRecorder {
  var started = 0;
  var stopped = 0;
  @override
  bool get supported => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(String recordingId) async => started++;
  @override
  Future<String?> stop() async {
    stopped++;
    return '/phone/ride_check_audio/$stopped.m4a';
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  group('rules', () {
    test('app defaults match the owner spec and every trigger is on', () {
      const rules = RideCheckRules.defaults;
      expect(rules.farDropMeters, 3000);
      expect(rules.longStopMinutes, 5);
      expect(rules.offRouteKm, 2);
      expect(rules.longerThanPercent, 50);
      for (final trigger in RideCheckTrigger.values) {
        expect(rules.enabled(trigger), isTrue, reason: trigger.name);
      }
    });

    test('driver rows: red first, then the rows of each trigger', () {
      List<String> rows(RideCheckTrigger trigger) => [
        for (final topic in RideCheckTopic.forDriver(trigger)) topic.label,
      ];
      const red = [
        'Accident or collision',
        'Someone is hurt or feels ill',
        'I feel unsafe',
      ];
      expect(rows(RideCheckTrigger.longStop), [
        ...red,
        'Car problem',
        'The rider asked for a stop',
        'Traffic or road works',
        'Something else',
      ]);
      expect(rows(RideCheckTrigger.droppedFar), [
        ...red,
        'The rider asked to stop here',
        'The rider changed destination',
        'Road closed or no access',
        'Something else',
      ]);
      expect(rows(RideCheckTrigger.offRoute), [
        ...red,
        'Traffic or road works',
        'The rider asked for another route',
        'Car problem',
        'Something else',
      ]);
      expect(
        rows(RideCheckTrigger.possibleCrash),
        rows(RideCheckTrigger.longStop),
      );
    });
  });

  group('detector', () {
    test('finished far: more than 3 km from the drop-off', () {
      final detector = RideCheckDetector();
      expect(
        detector.finish(
          driver: _north(_dropoff, 2900),
          dropoff: _dropoff,
          dropoffAddress: 'T-Centralen, Stockholm',
          at: _t0,
        ),
        isNull,
      );
      final event = detector.finish(
        driver: _north(_dropoff, 4200),
        dropoff: _dropoff,
        dropoffAddress: 'T-Centralen, Stockholm',
        at: _t0,
      )!;
      expect(event.trigger, RideCheckTrigger.droppedFar);
      expect(event.reason.text, 'Your trip ended 4.2 km from T-Centralen');
      expect(event.reason.bold, '4.2 km');
    });

    test('a trigger that is off never opens', () {
      final detector = RideCheckDetector(
        rules: const RideCheckRules(droppedFar: false, possibleCrash: false),
      );
      expect(
        detector.finish(
          driver: _north(_dropoff, 3000),
          dropoff: _dropoff,
          dropoffAddress: 'T-Centralen',
          at: _t0,
        ),
        isNull,
      );
      expect(detector.hardStop(_t0), isNull);
    });

    test('long stop: no movement for more than 5 min mid-trip, once', () {
      final detector = RideCheckDetector()..startTrip(_t0);
      final car = _north(_dropoff, 1000);
      expect(detector.observe(car, _t0), isNull);
      // GPS drift is not movement.
      expect(
        detector.observe(_north(car, 10), _t0.add(const Duration(minutes: 3))),
        isNull,
      );
      final event = detector.observe(
        car,
        _t0.add(const Duration(minutes: 6)),
        place: 'Odenplan',
      )!;
      expect(event.trigger, RideCheckTrigger.longStop);
      expect(event.reason.text, 'Your car has stopped for 6 min · Odenplan');
      expect(
        detector.observe(car, _t0.add(const Duration(minutes: 9))),
        isNull,
      );
    });

    test('long stop: moving, or waiting at a planned stop, resets it', () {
      final detector = RideCheckDetector()..startTrip(_t0);
      final car = _north(_dropoff, 1000);
      detector.observe(car, _t0);
      detector.observe(
        _north(car, 200),
        _t0.add(const Duration(minutes: 3)),
      );
      expect(
        detector.observe(
          _north(car, 200),
          _t0.add(const Duration(minutes: 6)),
        ),
        isNull,
      );
      expect(
        detector.observe(
          _north(car, 200),
          _t0.add(const Duration(minutes: 20)),
          atPlannedStop: true,
        ),
        isNull,
      );
      expect(
        detector.tick(_t0.add(const Duration(minutes: 25))),
        isNull,
      );
      expect(
        detector.tick(_t0.add(const Duration(minutes: 26)))?.trigger,
        RideCheckTrigger.longStop,
      );
    });

    test('quiet GPS: the tick finds a long stop, but not without GPS', () {
      final detector = RideCheckDetector()..startTrip(_t0);
      detector.observe(_north(_dropoff, 1000), _t0);
      expect(
        detector.tick(_t0.add(const Duration(minutes: 6)), gps: false),
        isNull,
      );
      expect(
        detector.tick(_t0.add(const Duration(minutes: 6)))?.reason.bold,
        '6 min',
      );
    });

    test('off route: more than 2 km from the planned route', () {
      final detector = RideCheckDetector()..startTrip(_t0);
      final start = _north(_dropoff, -5000);
      detector.planLeg('0', [start, _dropoff], 600, wholeTrip: true);
      // A reroute is not the plan.
      detector.planLeg('0', [start, const GeoPoint(59.4, 18.2)], 900, wholeTrip: true);
      final east1km = GeoPoint(start.latitude + .02, start.longitude + .0177);
      expect(detector.observe(east1km, _t0), isNull);
      final east3km = GeoPoint(start.latitude + .02, start.longitude + .053);
      final event = detector.observe(
        east3km,
        _t0.add(const Duration(minutes: 1)),
        destination: 'T-Centralen, Stockholm',
      )!;
      expect(event.trigger, RideCheckTrigger.offRoute);
      expect(event.reason.text, startsWith('You are 3.0 km off the route'));
      expect(event.reason.text, endsWith('to T-Centralen'));
    });

    test('off route: the trip 50 % longer than expected', () {
      final detector = RideCheckDetector()..startTrip(_t0);
      detector.planLeg('0', [_north(_dropoff, -5000), _dropoff], 600, wholeTrip: true);
      expect(detector.tick(_t0.add(const Duration(seconds: 900))), isNull);
      final event = detector.tick(_t0.add(const Duration(seconds: 960)))!;
      expect(event.trigger, RideCheckTrigger.offRoute);
      expect(event.reason.text, 'This trip is 60% longer than expected');
    });

    test('a trip with stops has no expected time from its first leg', () {
      final detector = RideCheckDetector()..startTrip(_t0);
      detector.planLeg('0', [_north(_dropoff, -5000), _dropoff], 60, wholeTrip: false);
      expect(detector.tick(_t0.add(const Duration(hours: 1)), gps: false), isNull);
    });

    test('possible crash: the hook opens it; demo always opens', () {
      final detector = RideCheckDetector();
      expect(detector.hardStop(_t0)!.trigger, RideCheckTrigger.possibleCrash);
      expect(detector.hardStop(_t0), isNull);
      for (final trigger in RideCheckTrigger.values) {
        final demo = detector.demo(trigger, _t0, destination: 'Solna centrum');
        expect(demo.trigger, trigger);
        expect(demo.demo, isTrue);
      }
    });

    group('admin settings decide the trigger', () {
      const admin = RideCheckAdminConfig(
        finishFarFromDropoffKm: 5,
        longStopMinutes: 10,
      );
      RideCheckEvent? finishAt(double meters, RideCheckRules rules) =>
          RideCheckDetector(rules: rules).finish(
            driver: _north(_dropoff, meters),
            dropoff: _dropoff,
            dropoffAddress: 'T-Centralen',
            at: _t0,
          );
      RideCheckEvent? stoppedFor(Duration stopped, RideCheckRules rules) {
        final detector = RideCheckDetector(rules: rules)..startTrip(_t0);
        final car = _north(_dropoff, 1000);
        detector.observe(car, _t0);
        return detector.observe(car, _t0.add(stopped));
      }

      test('defaults: 3 km and 5 min', () {
        const config = RideCheckAdminConfig();
        expect(config.finishFarFromDropoffKm, 3);
        expect(config.longStopMinutes, 5);
        final rules = RideCheckRules.fromAdmin(config);
        expect(rules.farDropMeters, 3000);
        expect(rules.longStopMinutes, 5);
      });

      test('Finish just over / under the admin distance', () {
        final rules = RideCheckRules.fromAdmin(admin);
        expect(finishAt(4950, rules), isNull);
        expect(finishAt(5050, rules)?.trigger, RideCheckTrigger.droppedFar);
        final defaults = RideCheckRules.fromAdmin(const RideCheckAdminConfig());
        expect(finishAt(2950, defaults), isNull);
        expect(finishAt(3050, defaults)?.trigger, RideCheckTrigger.droppedFar);
      });

      test('stop just over / under the admin minutes', () {
        final rules = RideCheckRules.fromAdmin(admin);
        expect(stoppedFor(const Duration(minutes: 9, seconds: 50), rules), isNull);
        expect(stoppedFor(const Duration(minutes: 10), rules), isNull);
        expect(
          stoppedFor(const Duration(minutes: 10, seconds: 10), rules)?.trigger,
          RideCheckTrigger.longStop,
        );
        final defaults = RideCheckRules.fromAdmin(const RideCheckAdminConfig());
        expect(stoppedFor(const Duration(minutes: 4, seconds: 50), defaults), isNull);
        expect(
          stoppedFor(const Duration(minutes: 5, seconds: 10), defaults)?.reason.bold,
          '5 min',
        );
      });

      test('services read the current admin config', () {
        final previous = RideCheckAdminConfig.current;
        addTearDown(() => RideCheckAdminConfig.current = previous);
        RideCheckAdminConfig.current = admin;
        final services = RideCheckServices(
          alerts: DemoSafetyAlertRepository(),
          log: MemoryRideCheckLog(),
        );
        expect(services.rules.farDropMeters, 5000);
        expect(services.rules.longStopMinutes, 10);
        final demo = RideCheckDetector(rules: services.rules)
            .demo(RideCheckTrigger.longStop, _t0, destination: 'Solna');
        expect(demo.reason.bold, '10 min');
      });
    });

    test('distance to a route is measured to its nearest segment', () {
      const a = GeoPoint(59.30, 18.00);
      const b = GeoPoint(59.40, 18.00);
      final d = RideCheckDetector.distanceToRouteMeters(
        const GeoPoint(59.35, 18.01),
        const [a, b],
      );
      expect(d, closeTo(569, 5));
    });
  });

  group('controller', () {
    late DemoSafetyAlertRepository alerts;
    late MemoryRideCheckLog log;
    late List<Uri> dialed;
    late _Recorder recorder;
    late RideCheckController controller;
    var now = _t0;

    setUp(() {
      alerts = DemoSafetyAlertRepository(now: () => now);
      log = MemoryRideCheckLog();
      dialed = <Uri>[];
      recorder = _Recorder();
      now = _t0;
      controller = RideCheckController(
        services: RideCheckServices(
          alerts: alerts,
          log: log,
          now: () => now,
          recorder: () => recorder,
          launch: (uri) async {
            dialed.add(uri);
            return true;
          },
        ),
        tripId: 'trip-1',
        tripDetails: () => _trip,
      );
    });
    tearDown(() {
      controller.dispose();
      alerts.dispose();
    });

    RideCheckEvent event([RideCheckTrigger t = RideCheckTrigger.longStop]) =>
        RideCheckDetector().demo(t, now, destination: 'T-Centralen');

    test("I'm OK closes it and saves the answer to the trip", () async {
      final done = controller.open(event(), instant: true);
      expect(controller.phase, RideCheckPhase.card);
      await controller.imOk();
      final record = await done;
      expect(controller.active, isFalse);
      expect(record.answers.single.answer, "I'm OK");
      expect(record.answered, isTrue);
      expect(log.rows.single.answers.single.answer, "I'm OK");
      expect(log.rows.single.trigger, RideCheckTrigger.longStop);
      expect(alerts.alerts, isEmpty);
    });

    test('a red row alerts admin and Dispatch at once with all details', () async {
      controller.open(event(), instant: true);
      controller.choose(RideCheckTopic.accident);
      await controller.settleAlerts();
      final alert = alerts.alerts.single;
      expect(controller.alertSent, isTrue);
      expect(alert.recipients, ['admin', 'dispatch']);
      expect(alert.topic, 'Accident or collision');
      expect(alert.trip.riderName, 'Angelica');
      expect(alert.trip.driverName, 'Movera Driver');
      expect(alert.trip.plate, 'ABC 123');
      expect(alert.trip.tripId, 'trip-1');
      expect(alert.trigger, RideCheckTrigger.longStop);
      expect(log.rows.single.alertSent, isTrue);
    });

    test('Yes and Not sure update the alert; No does not', () async {
      controller.open(event(), instant: true);
      controller.choose(RideCheckTopic.accident);
      controller.answer(RideCheckQuestion.anyoneHurt, 'Yes');
      controller.answer(RideCheckQuestion.carSafe, 'No');
      controller.answer(RideCheckQuestion.otherPersonOk, 'Not sure');
      await controller.settleAlerts();
      final alert = alerts.alerts.single;
      expect(alert.updates, 2);
      expect(
        [for (final a in alert.answers) a.answer],
        ['Accident or collision', 'Yes', 'Not sure'],
      );
      expect(
        [for (final entry in alerts.journal) entry.kind],
        ['sent', 'updated', 'updated'],
      );
      // Every answer is still saved to the trip.
      expect(log.rows.single.answers.length, 4);
    });

    test('a non-red row sends no alert, even with Yes', () async {
      controller.open(event(), instant: true);
      controller.choose(RideCheckTopic.carProblem);
      controller.answer(RideCheckQuestion.canContinue, 'Yes');
      await controller.settleAlerts();
      expect(alerts.alerts, isEmpty);
      await controller.done();
      expect(controller.active, isFalse);
    });

    test('Call 112 opens tel:112 and alerts Movera', () async {
      controller.open(event(RideCheckTrigger.possibleCrash));
      // A possible crash opens at once.
      expect(controller.phase, RideCheckPhase.card);
      await controller.callEmergency();
      await controller.settleAlerts();
      expect(dialed, [Uri.parse('tel:112')]);
      expect(controller.step, RideCheckStep.called);
      expect(controller.dialOpened, isTrue);
      expect(alerts.alerts.single.topic, 'Called 112');
      // The dialer again: no second alert.
      await controller.callEmergency();
      await controller.settleAlerts();
      expect(dialed, hasLength(2));
      expect(alerts.alerts, hasLength(1));
    });

    test('a failed dialer says to dial 112 manually', () async {
      final failing = RideCheckController(
        services: RideCheckServices(
          alerts: alerts,
          log: log,
          launch: (_) async => throw StateError('no dialer'),
        ),
        tripId: 'trip-2',
        tripDetails: () => _trip,
      );
      failing.open(event(), instant: true);
      await failing.callEmergency();
      expect(failing.dialFailed, isTrue);
      failing.dispose();
    });

    test('Something else saves the short text', () async {
      final done = controller.open(event(), instant: true);
      controller.choose(RideCheckTopic.somethingElse);
      controller.setNote('  Rider left a bag  ');
      await controller.done();
      final record = await done;
      expect(record.answers.last.answer, 'Rider left a bag');
    });

    test('audio is saved only on the phone; the alert never carries it', () async {
      final done = controller.open(event(), instant: true);
      await controller.toggleRecording();
      expect(controller.audio, RideCheckAudio.recording);
      now = now.add(const Duration(seconds: 42));
      expect(controller.audioSeconds, 42);
      controller.choose(RideCheckTopic.unsafe);
      await controller.done();
      final record = await done;
      expect(recorder.started, 1);
      expect(recorder.stopped, 1);
      expect(record.audioSeconds, 42);
      expect(alerts.alerts.single.answers.map((a) => a.answer),
          isNot(contains(contains('m4a'))));
    });

    test('recording is unavailable without a recorder for this platform', () async {
      final plain = RideCheckController(
        services: RideCheckServices(
          alerts: alerts,
          log: log,
          recorder: () => const UnsupportedRideCheckRecorder(),
        ),
        tripId: 'trip-3',
        tripDetails: () => _trip,
      );
      plain.open(event(), instant: true);
      await plain.toggleRecording();
      expect(plain.audio, RideCheckAudio.unavailable);
      plain.dispose();
    });

    test('a double tap on Done while audio saves closes once', () async {
      final done = controller.open(event(), instant: true);
      await controller.toggleRecording();
      controller.choose(RideCheckTopic.traffic);
      final first = controller.done();
      final second = controller.done();
      await Future.wait([first, second]);
      expect(recorder.stopped, 1);
      expect((await done).answers.map((a) => a.answer), ['Traffic or road works']);
    });

    test('a second check is not stacked on an open one', () async {
      final first = controller.open(event(), instant: true);
      final second = controller.open(event(RideCheckTrigger.offRoute));
      expect(controller.event!.trigger, RideCheckTrigger.longStop);
      await controller.imOk();
      expect(identical((await first).id, (await second).id), isTrue);
    });
  });

  group('log', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('Ride checks are saved per trip on the phone', () async {
      final log = PrefsRideCheckLog();
      final record = RideCheckRecord(
        id: 'rc-1',
        tripId: 'trip-1',
        trigger: RideCheckTrigger.droppedFar,
        reason: 'Your trip ended 1.2 km from Solna centrum',
        openedAt: _t0,
      );
      await log.save(record);
      await log.save(
        record.copyWith(
          answers: [
            RideCheckAnswer(
              question: RideCheckAnswer.first,
              answer: "I'm OK",
              at: _t0,
            ),
          ],
          answeredAt: _t0,
        ),
      );
      await log.save(
        RideCheckRecord(
          id: 'rc-2',
          tripId: 'trip-2',
          trigger: RideCheckTrigger.longStop,
          reason: 'x',
          openedAt: _t0,
        ),
      );
      final rows = await PrefsRideCheckLog().forTrip('trip-1');
      expect(rows, hasLength(1));
      expect(rows.single.trigger, RideCheckTrigger.droppedFar);
      expect(rows.single.answers.single.answer, "I'm OK");
      expect(rows.single.answered, isTrue);
    });
  });
}
