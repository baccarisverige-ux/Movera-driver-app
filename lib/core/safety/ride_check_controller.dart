import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/core/safety/demo_safety_alert_repository.dart';
import 'package:movera/core/safety/driver_sos.dart';
import 'package:movera/core/safety/emergency_dial.dart';
import 'package:movera/core/safety/ride_check.dart';
import 'package:movera/core/safety/ride_check_gate.dart';
import 'package:movera/core/safety/ride_check_recorder.dart';
import 'package:movera/core/safety/ride_check_services.dart';
import 'package:movera/core/safety/safety_alert_repository.dart';

/// Where the card is: the island pulses as a pill, then grows into the card,
/// then shrinks back once the driver has answered.
enum RideCheckPhase { idle, pill, card, closing }

/// Which screen of the card is shown.
enum RideCheckStep { main, followUp, called }

enum RideCheckAudio {
  idle,
  starting,
  recording,
  saved,
  unavailable,
  denied,
  failed,
}

/// One open Ride check on the trip screen. It cannot close without an
/// answer: only [imOk], a row and its Done, or Call 112 and its Done end it.
class RideCheckController extends ChangeNotifier {
  RideCheckController({
    required this.services,
    required this.tripId,
    required this.tripDetails,
  });

  final RideCheckServices services;
  final String tripId;

  /// Trip, driver and rider details at the moment an alert is sent.
  final SafetyAlertTrip Function() tripDetails;

  static const Duration pillDuration = Duration(milliseconds: 1100);
  static const Duration closeDuration = Duration(milliseconds: 420);

  RideCheckPhase _phase = RideCheckPhase.idle;
  RideCheckEvent? _event;
  RideCheckRecord? _record;
  RideCheckStep _step = RideCheckStep.main;
  RideCheckTopic? _topic;
  final Map<String, String> _picks = <String, String>{};
  String _note = '';
  SafetyAlert? _alert;
  bool _alertFailed = false;
  bool _dialOpened = false;
  bool _dialFailed = false;
  String? _dialOutcome;
  bool _instant = false;
  Completer<RideCheckRecord>? _done;
  Timer? _phaseTimer;
  Future<void> _alertQueue = Future<void>.value();
  bool _sending = false;
  bool _closing = false;
  bool _disposed = false;
  bool _holdsGate = false;

  RideCheckRecorder? _recorder;
  RideCheckAudio _audio = RideCheckAudio.idle;
  DateTime? _audioStartedAt;
  int? _audioSeconds;
  Timer? _audioTicker;
  // The recorder was started and not yet stopped, whatever [_audio] says.
  bool _recorderRunning = false;
  bool _dropStart = false;
  bool _audioStoppedInBackground = false;

  RideCheckPhase get phase => _phase;
  bool get active => _phase != RideCheckPhase.idle;

  /// The card covers the island (it grows from it and shrinks back to it).
  bool get covering =>
      _phase == RideCheckPhase.card || _phase == RideCheckPhase.closing;
  RideCheckEvent? get event => _event;
  RideCheckStep get step => _step;
  RideCheckTopic? get topic => _topic;
  String? pick(RideCheckQuestion question) => _picks[question.text];
  String get note => _note;
  SafetyAlert? get alert => _alert;
  bool get alertSent => _alert != null;
  bool get alertFailed => _alertFailed && _alert == null;
  bool get dialOpened => _dialOpened;
  bool get dialFailed => _dialFailed;

  /// Reduced motion: no pill phase and no shrink.
  bool get instant => _instant;
  List<RideCheckTopic> get topics => _event == null
      ? const <RideCheckTopic>[]
      : RideCheckTopic.forDriver(_event!.trigger);
  RideCheckRecord? get record => _record;

  RideCheckAudio get audio => _audio;

  /// The saved recording ended because the app left the screen.
  bool get audioStoppedInBackground => _audioStoppedInBackground;
  int get audioSeconds => _audio == RideCheckAudio.recording
      ? services.now().difference(_audioStartedAt!).inSeconds
      : (_audioSeconds ?? 0);

  /// Opens the card; completes with the answered record. While a check is
  /// already open, a new one is not stacked on top of it.
  ///
  /// [serverCheckId] (contract v0.18.9, G7 decision 1): the server asked
  /// ("srv_…"): its id is the check's id for the answer, and no "shown"
  /// report is sent (the server already knows).
  Future<RideCheckRecord> open(
    RideCheckEvent event, {
    bool instant = false,
    String? serverCheckId,
  }) {
    if (_disposed) {
      return Future<RideCheckRecord>.error(StateError('Ride check closed'));
    }
    final current = _done;
    if (active && current != null) return current.future;
    final done = Completer<RideCheckRecord>();
    _done = done;
    _event = event;
    _instant = instant;
    _step = RideCheckStep.main;
    _topic = null;
    _picks.clear();
    _note = '';
    _alert = null;
    _alertFailed = false;
    _dialOpened = false;
    _dialFailed = false;
    _dialOutcome = null;
    // driver-28: never leave a recorder running behind a new check.
    if (_recorderRunning) _stopRecorderQuietly();
    _audio = RideCheckAudio.idle;
    _audioStoppedInBackground = false;
    _audioSeconds = null;
    _audioStartedAt = null;
    _alertQueue = Future<void>.value();
    _sending = false;
    _closing = false;
    _record = RideCheckRecord(
      id:
          serverCheckId ??
          'ride-check-$tripId-${event.at.microsecondsSinceEpoch}',
      tripId: tripId,
      trigger: event.trigger,
      reason: event.reason.english,
      reasonParts: event.reason,
      openedAt: event.at,
    );
    _save();
    if (serverCheckId == null) {
      _report(
        'shown',
        () => services.alerts.shown(
          checkId: _record!.id,
          tripId: tripId,
          trigger: event.trigger,
          at: event.at,
        ),
      );
    }
    // A possible crash opens at once, with Call 112 on top.
    final now = instant || event.trigger == RideCheckTrigger.possibleCrash;
    _phase = now ? RideCheckPhase.card : RideCheckPhase.pill;
    _phaseTimer?.cancel();
    if (!now) {
      _phaseTimer = Timer(pillDuration, () {
        if (_disposed || _phase != RideCheckPhase.pill) return;
        _phase = RideCheckPhase.card;
        notifyListeners();
      });
    }
    notifyListeners();
    return done.future;
  }

  bool get _answerable =>
      !_disposed &&
      !_closing &&
      (_phase == RideCheckPhase.card || _phase == RideCheckPhase.pill);

  /// The question under which the dialer's outcome is saved and sent.
  static const String dialerQuestion = '112 dialer';
  static const String dialerOpened = 'Opened';
  static const String dialerDidNotOpen = 'Did not open';

  /// "Call 112": the phone dialer opens with 112; the driver calls. Movera
  /// is alerted at the same time.
  ///
  /// driver-u43: the app only opens the dialer, and that can fail. The
  /// answer and the alert topic say "Call 112" (what the driver chose);
  /// whether the dialer opened follows as its own answer and alert update.
  bool _sosSent = false;
  DriverSosOutcome? _sosOutcome;

  /// What the SOS sent with Call 112 came to; null before it has an answer.
  DriverSosOutcome? get sosOutcome => _sosOutcome;

  Future<void> callEmergency() async {
    if (!_answerable) return;
    switch (_step) {
      case RideCheckStep.main:
        _addAnswer(RideCheckAnswer.first, 'Call 112');
        _step = RideCheckStep.called;
        _phase = RideCheckPhase.card;
      case RideCheckStep.followUp:
      case RideCheckStep.called:
        // The dialer's outcome below is the answer.
        break;
    }
    _dialFailed = false;
    notifyListeners();
    _ensureAlert('Call 112');
    // Owner decision 2026-10-27: no 112 button without the SOS to Movera.
    // Once per check; the dialer does not wait for it.
    if (!_sosSent) {
      _sosSent = true;
      unawaited(
        services.sos().catchError((_) => DriverSosOutcome.failed).then((
          outcome,
        ) {
          if (_disposed) return;
          _sosOutcome = outcome;
          notifyListeners();
        }),
      );
    }
    final result = await handoffEmergencyDial(
      () => services.launch(RideCheckServices.emergencyNumber),
    );
    if (_disposed) return;
    _dialOpened = result == EmergencyDialResult.opened;
    _dialFailed = !_dialOpened;
    final outcome = _dialOpened ? dialerOpened : dialerDidNotOpen;
    // Opening the dialer again adds an answer only when the outcome changed.
    if (_dialOutcome != outcome) {
      _dialOutcome = outcome;
      final answer = _addAnswer(dialerQuestion, outcome);
      _queueAlert((alert) => services.alerts.update(alert.id, answer));
    }
    notifyListeners();
  }

  /// "I'm OK" closes the card and saves the answer.
  Future<void> imOk() async {
    if (!_answerable || _step != RideCheckStep.main) return;
    _addAnswer(RideCheckAnswer.first, "I'm OK");
    _reportOk();
    await _close();
  }

  /// A row: red rows alert the Movera safety team at once.
  void choose(RideCheckTopic topic) {
    if (!_answerable || _step != RideCheckStep.main) return;
    _addAnswer(RideCheckAnswer.first, topic.label);
    _topic = topic;
    _step = RideCheckStep.followUp;
    _phase = RideCheckPhase.card;
    if (topic.red) _ensureAlert(topic.label);
    notifyListeners();
  }

  /// A follow-up answer. "Yes" or "Not sure" updates a sent alert.
  void answer(RideCheckQuestion question, String option) {
    if (!_answerable || _step != RideCheckStep.followUp) return;
    if (_picks[question.text] == option) return;
    _picks[question.text] = option;
    final answer = _addAnswer(question.text, option);
    if (_topic?.red == true && question.updatesAlert(option)) {
      _queueAlert((alert) => services.alerts.update(alert.id, answer));
    }
    notifyListeners();
  }

  void setNote(String text) {
    _note = text;
  }

  /// Done on a follow-up screen.
  Future<void> done() async {
    if (!_answerable || _step == RideCheckStep.main) return;
    final note = _note.trim();
    if (_topic == RideCheckTopic.somethingElse && note.isNotEmpty) {
      _addAnswer('What happened', note);
    }
    // A non-red row without an alert is an "I'm OK" for Movera.
    if (_alert == null && !_sending) _reportOk();
    await _close();
  }

  Future<void> toggleRecording() async {
    if (!_answerable) return;
    switch (_audio) {
      case RideCheckAudio.starting:
        return;
      case RideCheckAudio.recording:
        await _stopRecording();
        return;
      case RideCheckAudio.idle:
      case RideCheckAudio.saved:
      case RideCheckAudio.unavailable:
      case RideCheckAudio.denied:
      case RideCheckAudio.failed:
        break;
    }
    final recorder = _recorder ??= services.createRecorder();
    if (!recorder.supported) {
      _audio = RideCheckAudio.unavailable;
      notifyListeners();
      return;
    }
    _audio = RideCheckAudio.starting;
    _dropStart = false;
    _audioStoppedInBackground = false;
    notifyListeners();
    try {
      if (!await recorder.requestPermission()) {
        if (!_disposed) {
          _audio = RideCheckAudio.denied;
          notifyListeners();
        }
        return;
      }
      if (_disposed || !_answerable) return;
      await recorder.start(
        '${_record!.id}-${services.now().millisecondsSinceEpoch}',
      );
    } catch (error) {
      DriverLog.warn('Ride check recording failed to start: $error');
      if (!_disposed) {
        _audio = RideCheckAudio.failed;
        notifyListeners();
      }
      return;
    }
    // driver-28: the card may have closed (I'm OK, Done) or the trip screen
    // gone while the start was in flight. Nothing on screen could show or
    // stop this recording, so drop it.
    if (_disposed || !_answerable || _dropStart) {
      unawaited(recorder.cancel().catchError((Object _) {}));
      if (!_disposed) {
        _audio = RideCheckAudio.idle;
        notifyListeners();
      }
      return;
    }
    _recorderRunning = true;
    _audio = RideCheckAudio.recording;
    _audioStartedAt = services.now();
    _audioTicker?.cancel();
    _audioTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed) notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _stopRecording() async {
    final recorder = _recorder;
    // A stop already in flight (hidden, then paused) is not repeated.
    if (recorder == null ||
        _audio != RideCheckAudio.recording ||
        !_recorderRunning) {
      return;
    }
    _audioTicker?.cancel();
    final seconds = audioSeconds;
    _recorderRunning = false;
    String? path;
    try {
      path = await recorder.stop();
    } catch (error) {
      DriverLog.warn('Ride check recording failed to stop: $error');
    }
    _audioSeconds = path == null ? null : seconds;
    _audio = path == null ? RideCheckAudio.failed : RideCheckAudio.saved;
    if (path != null) {
      _record = _record?.copyWith(audioSeconds: seconds);
      _save();
    }
    if (!_disposed) notifyListeners();
  }

  /// driver-u41: the app left the screen (dialer, lock screen, another
  /// app). Without background audio the phone stops capturing (iOS) or
  /// records silence (Android), so stop and save now: the saved length is
  /// what was really captured, and the card says why it stopped.
  Future<void> appBackgrounded() async {
    switch (_audio) {
      case RideCheckAudio.starting:
        _dropStart = true;
      case RideCheckAudio.recording:
        await _stopRecording();
        if (_audio == RideCheckAudio.saved) {
          _audioStoppedInBackground = true;
          if (!_disposed) notifyListeners();
        }
      case RideCheckAudio.idle:
      case RideCheckAudio.saved:
      case RideCheckAudio.unavailable:
      case RideCheckAudio.denied:
      case RideCheckAudio.failed:
        break;
    }
  }

  void _stopRecorderQuietly() {
    _recorderRunning = false;
    _audioTicker?.cancel();
    unawaited(_recorder?.stop().catchError((Object _) => null));
  }

  RideCheckAnswer _addAnswer(String question, String text) {
    final answer = RideCheckAnswer(
      question: question,
      answer: text,
      at: services.now(),
    );
    _record = _record?.copyWith(answers: [..._record!.answers, answer]);
    _save();
    return answer;
  }

  void _ensureAlert(String topic) {
    if (_alert != null || _sending) return;
    _sending = true;
    // What is known right now; later answers follow as updates.
    final trip = tripDetails();
    final event = _event!;
    final answers = List<RideCheckAnswer>.of(
      _record?.answers ?? const <RideCheckAnswer>[],
    );
    _alertQueue = _alertQueue.then((_) async {
      try {
        final sent = await services.alerts.send(
          trip: trip,
          trigger: event.trigger,
          reason: event.reason.english,
          topic: topic,
          answers: answers,
          checkId: _record?.id,
        );
        if (_disposed) return;
        _alert = sent;
        _alertFailed = false;
        _record = _record?.copyWith(
          alertSent: true,
          alertReachedMovera: services.alerts is! DemoSafetyAlertRepository,
        );
        _save();
      } catch (error) {
        DriverLog.warn('Ride check alert failed: $error');
        _alertFailed = true;
      } finally {
        _sending = false;
        if (!_disposed) notifyListeners();
      }
    });
  }

  void _queueAlert(Future<SafetyAlert> Function(SafetyAlert alert) action) {
    _alertQueue = _alertQueue.then((_) async {
      final alert = _alert;
      if (alert == null) return;
      try {
        final next = await action(alert);
        if (!_disposed) _alert = next;
      } catch (error) {
        DriverLog.warn('Ride check alert update failed: $error');
      }
      if (!_disposed) notifyListeners();
    });
  }

  void _reportOk() {
    final record = _record;
    final event = _event;
    if (record == null || event == null) return;
    _report(
      'ok',
      () => services.alerts.answeredOk(
        checkId: record.id,
        tripId: tripId,
        trigger: event.trigger,
      ),
    );
  }

  /// Reports run in the alert queue, so the shown report goes first.
  void _report(String what, Future<void> Function() action) {
    _alertQueue = _alertQueue.then((_) async {
      try {
        await action();
      } catch (error) {
        DriverLog.warn('Ride check $what report failed: $error');
      }
    });
  }

  /// Completes once every alert send and update queued so far is done.
  Future<void> settleAlerts() => _alertQueue;

  Future<void> _close() async {
    if (_closing ||
        _phase == RideCheckPhase.closing ||
        _phase == RideCheckPhase.idle) {
      return;
    }
    // A second tap while a recording is being saved adds nothing.
    _closing = true;
    _phaseTimer?.cancel();
    await _stopRecording();
    if (_disposed) return;
    _record = _record?.copyWith(answeredAt: services.now());
    _save();
    final record = _record!;
    _phase = _instant ? RideCheckPhase.idle : RideCheckPhase.closing;
    notifyListeners();
    if (!_instant) {
      _phaseTimer = Timer(closeDuration, () {
        if (_disposed) return;
        _phase = RideCheckPhase.idle;
        notifyListeners();
      });
    }
    final done = _done;
    _done = null;
    if (done != null && !done.isCompleted) done.complete(record);
  }

  void _save() {
    final record = _record;
    if (record == null) return;
    services.log.save(record).catchError((Object error) {
      DriverLog.warn('Ride check could not be saved: $error');
    });
  }

  /// Every phase change notifies: keep [RideCheckGate] open from the pill
  /// until the driver has answered.
  @override
  void notifyListeners() {
    _syncGate(_phase == RideCheckPhase.pill || _phase == RideCheckPhase.card);
    super.notifyListeners();
  }

  void _syncGate(bool open) {
    if (open == _holdsGate) return;
    _holdsGate = open;
    RideCheckGate.set(open);
  }

  @override
  void dispose() {
    _disposed = true;
    _syncGate(false);
    _phaseTimer?.cancel();
    _audioTicker?.cancel();
    // The trip screen left: keep what was recorded on the phone.
    if (_recorderRunning) _stopRecorderQuietly();
    final done = _done;
    _done = null;
    final record = _record;
    if (done != null && !done.isCompleted && record != null) {
      done.complete(record);
    }
    super.dispose();
  }
}
