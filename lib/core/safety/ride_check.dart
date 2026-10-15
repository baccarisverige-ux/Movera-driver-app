/// Ride check: the safety question Movera asks when a trip looks wrong.
///
/// Domain only. The card lives in the trip screen; rules and detection in
/// [RideCheckRules] and `RideCheckDetector`.
library;

/// Why a Ride check opened.
enum RideCheckTrigger {
  droppedFar('Dropped far away'),
  longStop('Long stop'),
  offRoute('Off the route'),
  possibleCrash('Possible crash');

  const RideCheckTrigger(this.label);

  /// Short name for the trip details and the alert, e.g. "Long stop".
  final String label;
}

/// Admin-set triggers. Every trigger can be turned off; the numbers are the
/// app defaults until Dispatch settings send their own.
class RideCheckRules {
  const RideCheckRules({
    this.droppedFar = true,
    this.farDropMeters = 500,
    this.longStop = true,
    this.longStopMinutes = 4,
    this.offRoute = true,
    this.offRouteKm = 2,
    this.longerThanPercent = 50,
    this.possibleCrash = true,
  });

  static const RideCheckRules defaults = RideCheckRules();

  /// The trip ended more than [farDropMeters] from the drop-off.
  final bool droppedFar;
  final double farDropMeters;

  /// No movement for [longStopMinutes] mid-trip, not at a planned stop.
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

/// The line under the title, e.g. "Your car has stopped for **4 min**".
class RideCheckReason {
  const RideCheckReason(this.lead, this.bold, [this.trail = '']);
  final String lead, bold, trail;

  String get text => '$lead$bold$trail';
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
    'at': at.toIso8601String(),
  };

  static RideCheckAnswer? fromJson(Object? data) {
    if (data is! Map) return null;
    final question = data['question'];
    final answer = data['answer'];
    final at = DateTime.tryParse('${data['at']}');
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
    required this.openedAt,
    this.answers = const <RideCheckAnswer>[],
    this.answeredAt,
    this.alertSent = false,
    this.audioSeconds,
  });

  final String id;
  final String tripId;
  final RideCheckTrigger trigger;
  final String reason;
  final DateTime openedAt;
  final List<RideCheckAnswer> answers;
  final DateTime? answeredAt;
  final bool alertSent;

  /// Length of an audio recording saved on this phone; null without one.
  final int? audioSeconds;

  bool get answered => answeredAt != null;

  RideCheckRecord copyWith({
    List<RideCheckAnswer>? answers,
    DateTime? answeredAt,
    bool? alertSent,
    int? audioSeconds,
  }) => RideCheckRecord(
    id: id,
    tripId: tripId,
    trigger: trigger,
    reason: reason,
    openedAt: openedAt,
    answers: answers ?? this.answers,
    answeredAt: answeredAt ?? this.answeredAt,
    alertSent: alertSent ?? this.alertSent,
    audioSeconds: audioSeconds ?? this.audioSeconds,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'tripId': tripId,
    'trigger': trigger.name,
    'reason': reason,
    'openedAt': openedAt.toIso8601String(),
    'answers': [for (final answer in answers) answer.toJson()],
    if (answeredAt != null) 'answeredAt': answeredAt!.toIso8601String(),
    'alertSent': alertSent,
    if (audioSeconds != null) 'audioSeconds': audioSeconds,
  };

  static RideCheckRecord? fromJson(Object? data) {
    if (data is! Map) return null;
    final id = data['id'];
    final tripId = data['tripId'];
    final reason = data['reason'];
    final openedAt = DateTime.tryParse('${data['openedAt']}');
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
      openedAt: openedAt,
      answers: answers.cast<RideCheckAnswer>(),
      answeredAt: data['answeredAt'] == null
          ? null
          : DateTime.tryParse('${data['answeredAt']}'),
      alertSent: data['alertSent'] == true,
      audioSeconds: audio is int ? audio : null,
    );
  }
}

/// "650 m", "1.2 km".
String rideCheckDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

/// "T-Centralen, Stockholm" -> "T-Centralen".
String rideCheckPlace(String address) {
  final first = address.split(',').first.trim();
  return first.isEmpty ? address.trim() : first;
}
