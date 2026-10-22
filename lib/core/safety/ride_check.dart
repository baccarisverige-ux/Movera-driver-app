/// Ride check: the safety question Movera asks when a trip looks wrong.
///
/// Domain only. The card lives in the trip screen; rules and detection in
/// [RideCheckRules] and `RideCheckDetector`.
library;

import 'dart:ui' show Locale;

import 'package:movera/core/admin/ride_check_admin_config.dart';
import 'package:movera/core/geo/driver_distance.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/l10n/app_localizations.dart';

/// Why a Ride check opened.
enum RideCheckTrigger {
  droppedFar('Finished far from drop-off'),
  longStop('Long stop'),
  offRoute('Off the route'),
  possibleCrash('Possible crash');

  const RideCheckTrigger(this.label);

  /// Short name for the trip details and the alert, e.g. "Long stop".
  final String label;
}

/// Admin-set triggers. Every trigger can be turned off; the distance and
/// stop time come from [RideCheckAdminConfig].
class RideCheckRules {
  const RideCheckRules({
    this.droppedFar = true,
    this.farDropMeters =
        RideCheckAdminConfig.defaultFinishFarFromDropoffKm * 1000,
    this.longStop = true,
    this.longStopMinutes = RideCheckAdminConfig.defaultLongStopMinutes,
    this.offRoute = true,
    this.offRouteKm = 2,
    this.longerThanPercent = 50,
    this.possibleCrash = true,
  });

  static const RideCheckRules defaults = RideCheckRules();

  /// The rules with admin's "finished far from drop-off" km and "unexpected
  /// long stop" minutes.
  factory RideCheckRules.fromAdmin(RideCheckAdminConfig config) =>
      RideCheckRules(
        farDropMeters: config.finishFarFromDropoffMeters,
        longStopMinutes: config.longStopMinutes,
      );

  /// The driver tapped Finish more than [farDropMeters] from the drop-off.
  final bool droppedFar;
  final double farDropMeters;

  /// No movement for more than [longStopMinutes] mid-trip, not at a
  /// planned stop.
  final bool longStop;
  final int longStopMinutes;

  /// More than [offRouteKm] off the planned route, or the trip
  /// [longerThanPercent] % longer than expected.
  final bool offRoute;
  final double offRouteKm;
  final int longerThanPercent;

  /// A very hard stop or impact. The card opens at once.
  final bool possibleCrash;

  /// GPS drift under this radius is not movement.
  static const double stillRadiusMeters = 30;

  /// Within this distance of the next stop or the drop-off the car is "at a
  /// planned stop", so waiting there is not a long stop.
  static const double plannedStopRadiusMeters = 150;

  bool enabled(RideCheckTrigger trigger) => switch (trigger) {
    RideCheckTrigger.droppedFar => droppedFar,
    RideCheckTrigger.longStop => longStop,
    RideCheckTrigger.offRoute => offRoute,
    RideCheckTrigger.possibleCrash => possibleCrash,
  };
}

/// What a [RideCheckReason] says.
enum RideCheckReasonKind { longStop, droppedFar, offRoute, longer, crash }

/// The line under the title, e.g. "Your car has stopped for **4 min**".
///
/// Kept as its kind and numbers, not as words: the card and the trip
/// details write it in the driver's language when shown, and the record
/// and the alert to Movera keep English (driver-u42, driver-u46).
class RideCheckReason {
  const RideCheckReason(this.kind, {this.number, this.place});

  /// "Your car has stopped for {minutes} min · {place}".
  const RideCheckReason.longStop(int minutes, String? place)
    : this(RideCheckReasonKind.longStop, number: minutes, place: place);

  /// "Your trip ended {meters} from {address}".
  RideCheckReason.droppedFar(double meters, String address)
    : this(
        RideCheckReasonKind.droppedFar,
        number: meters,
        place: rideCheckPlace(address),
      );

  /// "You are {meters} off the route (to {destination})".
  RideCheckReason.offRoute(double meters, String? destination)
    : this(
        RideCheckReasonKind.offRoute,
        number: meters,
        place: destination == null ? null : rideCheckPlace(destination),
      );

  /// "This trip is {percent}% longer than expected".
  const RideCheckReason.longer(int percent)
    : this(RideCheckReasonKind.longer, number: percent);

  /// "A very hard stop was detected (· {place})".
  const RideCheckReason.crash(String? place)
    : this(RideCheckReasonKind.crash, place: place);

  final RideCheckReasonKind kind;

  /// Minutes, meters or percent, by [kind].
  final num? number;
  final String? place;

  String? get _place {
    final value = place?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The lead, bold part and trail in [l].
  (String, String, String) partsIn(AppLocalizations l) {
    final n = number ?? 0;
    final at = _place;
    return switch (kind) {
      RideCheckReasonKind.longStop => (
        l.rcStoppedLead,
        l.rcMinutes(n.round()),
        at == null ? '' : ' · $at',
      ),
      RideCheckReasonKind.droppedFar => (
        l.rcEndedLead,
        driverDistanceMeters(n.toDouble(), l),
        l.rcEndedFromTrail(at ?? ''),
      ),
      RideCheckReasonKind.offRoute => (
        l.rcOffRouteLead,
        driverDistanceMeters(n.toDouble(), l),
        at == null ? l.rcOffRouteTrail : l.rcOffRouteToTrail(at),
      ),
      RideCheckReasonKind.longer => (
        l.rcLongerLead,
        l.rcPercent(n.round()),
        l.rcLongerTrail,
      ),
      RideCheckReasonKind.crash => (
        l.rcCrashLead,
        l.rcCrashBold,
        at == null ? l.rcCrashTrail : l.rcCrashTrailAt(at),
      ),
    };
  }

  String get lead => partsIn(tr).$1;
  String get bold => partsIn(tr).$2;
  String get trail => partsIn(tr).$3;

  /// In the driver's language.
  String get text => textIn(tr);

  /// In English: what the record and the alert to Movera keep.
  String get english => textIn(lookupAppLocalizations(const Locale('en')));

  String textIn(AppLocalizations l) {
    final (lead, bold, trail) = partsIn(l);
    return '$lead$bold$trail';
  }

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (number != null) 'number': number,
    if (place != null) 'place': place,
  };

  /// Null for anything this app cannot read, e.g. a record saved before.
  static RideCheckReason? fromJson(Object? data) {
    if (data is! Map) return null;
    final kind = RideCheckReasonKind.values
        .where((value) => value.name == data['kind'])
        .firstOrNull;
    final number = data['number'];
    final place = data['place'];
    if (kind == null ||
        (number != null && number is! num) ||
        (place != null && place is! String)) {
      return null;
    }
    return RideCheckReason(kind, number: number as num?, place: place as String?);
  }
}

/// One Ride check that should open now.
class RideCheckEvent {
  const RideCheckEvent({
    required this.trigger,
    required this.reason,
    required this.at,
    this.demo = false,
  });

  final RideCheckTrigger trigger;
  final RideCheckReason reason;
  final DateTime at;

  /// Opened from the trip island's demo tools.
  final bool demo;
}

/// Something the driver can tell Movera from the card.
enum RideCheckTopic {
  accident('Accident or collision', 'Accident', red: true),
  hurt('Someone is hurt or feels ill', 'Someone hurt', red: true),
  unsafe('I feel unsafe', 'Unsafe', red: true),
  carProblem('Car problem', 'Car problem'),
  riderAskedStop('The rider asked for a stop', 'Rider stop'),
  traffic('Traffic or road works', 'Traffic'),
  riderStopHere('The rider asked to stop here', 'Rider stop'),
  riderChangedDestination('The rider changed destination', 'New destination'),
  roadClosed('Road closed or no access', 'Road closed'),
  riderOtherRoute('The rider asked for another route', 'Other route'),
  somethingElse('Something else', 'Something else');

  const RideCheckTopic(this.label, this.short, {this.red = false});

  final String label;

  /// For the follow-up header, e.g. "RIDE CHECK · ACCIDENT".
  final String short;

  /// Red rows alert the Movera safety team at once.
  final bool red;

  /// Rows on the driver card. The red ones always come first.
  static List<RideCheckTopic> forDriver(RideCheckTrigger trigger) => [
    accident,
    hurt,
    unsafe,
    ...switch (trigger) {
      RideCheckTrigger.longStop || RideCheckTrigger.possibleCrash => [
        carProblem,
        riderAskedStop,
        traffic,
        somethingElse,
      ],
      RideCheckTrigger.droppedFar => [
        riderStopHere,
        riderChangedDestination,
        roadClosed,
        somethingElse,
      ],
      RideCheckTrigger.offRoute => [
        traffic,
        riderOtherRoute,
        carProblem,
        somethingElse,
      ],
    },
  ];

  /// Follow-up questions after this row, in order.
  List<RideCheckQuestion> get questions => switch (this) {
    accident => const [
      RideCheckQuestion.anyoneHurt,
      RideCheckQuestion.carSafe,
      RideCheckQuestion.otherPersonOk,
    ],
    hurt => const [RideCheckQuestion.whoNeedsHelp],
    unsafe => const [RideCheckQuestion.inDanger],
    carProblem => const [RideCheckQuestion.canContinue],
    _ => const [],
  };
}

class RideCheckQuestion {
  const RideCheckQuestion(this.text, this.options, {this.alerts = false});

  final String text;
  final List<String> options;

  /// Any answer updates the alert, not only "Yes" or "Not sure".
  final bool alerts;

  static const yes = 'Yes';
  static const no = 'No';
  static const notSure = 'Not sure';

  static const anyoneHurt = RideCheckQuestion('Is anyone hurt?', [
    yes,
    no,
    notSure,
  ]);
  static const carSafe = RideCheckQuestion('Is the car in a safe place?', [
    yes,
    no,
  ]);
  static const otherPersonOk = RideCheckQuestion('Is the other person OK?', [
    yes,
    no,
    notSure,
  ]);
  static const whoNeedsHelp = RideCheckQuestion('Who needs help?', [
    'Me',
    'The rider',
    'Someone else',
  ], alerts: true);
  static const inDanger = RideCheckQuestion('Are you in danger right now?', [
    yes,
    no,
  ]);
  static const canContinue = RideCheckQuestion('Can you continue the trip?', [
    yes,
    no,
  ]);

  /// Alert rule: "Yes" and "Not sure" update a sent alert.
  bool updatesAlert(String answer) =>
      alerts || answer == yes || answer == notSure;
}

/// One answer on the card, with when it was given.
class RideCheckAnswer {
  const RideCheckAnswer({
    required this.question,
    required this.answer,
    required this.at,
  });

  /// "Ride check" for the first answer, otherwise the follow-up question.
  final String question;
  final String answer;
  final DateTime at;

  static const first = 'Ride check';

  Map<String, Object?> toJson() => {
    'question': question,
    'answer': answer,
    'at': at.toUtc().toIso8601String(),
  };

  static RideCheckAnswer? fromJson(Object? data) {
    if (data is! Map) return null;
    final question = data['question'];
    final answer = data['answer'];
    final at = DateTime.tryParse('${data['at']}')?.toLocal();
    if (question is! String || answer is! String || at == null) return null;
    return RideCheckAnswer(question: question, answer: answer, at: at);
  }
}

/// A Ride check as the trip details show it: time, trigger and answers.
/// Kept on the phone; the alert to Movera is separate.
class RideCheckRecord {
  const RideCheckRecord({
    required this.id,
    required this.tripId,
    required this.trigger,
    required this.reason,
    this.reasonParts,
    required this.openedAt,
    this.answers = const <RideCheckAnswer>[],
    this.answeredAt,
    this.alertSent = false,
    this.alertReachedMovera = false,
    this.audioSeconds,
  });

  final String id;
  final String tripId;
  final RideCheckTrigger trigger;
  /// In English, as the alert to Movera has it.
  final String reason;

  /// What [reason] says, so the trip details can write it in the driver's
  /// language (driver-u42); null for records saved before.
  final RideCheckReason? reasonParts;

  /// [reason] in the driver's language.
  String get reasonText => reasonParts?.text ?? reason;
  final DateTime openedAt;
  final List<RideCheckAnswer> answers;
  final DateTime? answeredAt;
  final bool alertSent;

  /// The alert went to a Movera service, not only to the demo outbox on
  /// this phone (driver-u156). False for records saved before.
  final bool alertReachedMovera;

  /// Length of an audio recording saved on this phone; null without one.
  final int? audioSeconds;

  bool get answered => answeredAt != null;

  RideCheckRecord copyWith({
    List<RideCheckAnswer>? answers,
    DateTime? answeredAt,
    bool? alertSent,
    bool? alertReachedMovera,
    int? audioSeconds,
  }) => RideCheckRecord(
    id: id,
    tripId: tripId,
    trigger: trigger,
    reason: reason,
    reasonParts: reasonParts,
    openedAt: openedAt,
    answers: answers ?? this.answers,
    answeredAt: answeredAt ?? this.answeredAt,
    alertSent: alertSent ?? this.alertSent,
    alertReachedMovera: alertReachedMovera ?? this.alertReachedMovera,
    audioSeconds: audioSeconds ?? this.audioSeconds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'tripId': tripId,
    'trigger': trigger.name,
    'reason': reason,
    if (reasonParts != null) 'reasonParts': reasonParts!.toJson(),
    // UTC, as local time has no offset (driver-r4-14); older records
    // saved local time and read the same.
    'openedAt': openedAt.toUtc().toIso8601String(),
    'answers': [for (final answer in answers) answer.toJson()],
    if (answeredAt != null)
      'answeredAt': answeredAt!.toUtc().toIso8601String(),
    'alertSent': alertSent,
    if (alertReachedMovera) 'alertReachedMovera': true,
    if (audioSeconds != null) 'audioSeconds': audioSeconds,
  };

  static RideCheckRecord? fromJson(Object? data) {
    if (data is! Map) return null;
    final id = data['id'];
    final tripId = data['tripId'];
    final reason = data['reason'];
    final openedAt = DateTime.tryParse('${data['openedAt']}')?.toLocal();
    final trigger = RideCheckTrigger.values
        .where((value) => value.name == data['trigger'])
        .firstOrNull;
    final rawAnswers = data['answers'];
    if (id is! String ||
        tripId is! String ||
        reason is! String ||
        openedAt == null ||
        trigger == null ||
        rawAnswers is! List) {
      return null;
    }
    final answers = [
      for (final raw in rawAnswers) RideCheckAnswer.fromJson(raw),
    ];
    if (answers.any((answer) => answer == null)) return null;
    final audio = data['audioSeconds'];
    return RideCheckRecord(
      id: id,
      tripId: tripId,
      trigger: trigger,
      reason: reason,
      reasonParts: RideCheckReason.fromJson(data['reasonParts']),
      openedAt: openedAt,
      answers: answers.cast<RideCheckAnswer>(),
      answeredAt: data['answeredAt'] == null
          ? null
          : DateTime.tryParse('${data['answeredAt']}')?.toLocal(),
      alertSent: data['alertSent'] == true,
      alertReachedMovera: data['alertReachedMovera'] == true,
      audioSeconds: audio is int ? audio : null,
    );
  }
}

/// "650 m", "1.2 km".
String rideCheckDistance(double meters) => driverDistanceMeters(meters);

/// "T-Centralen, Stockholm" -> "T-Centralen".
String rideCheckPlace(String address) {
  final first = address.split(',').first.trim();
  return first.isEmpty ? address.trim() : first;
}
