import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/safety/ride_check.dart';

/// Ride check words in the driver's language. The values in
/// [RideCheckTopic], [RideCheckTrigger] and [RideCheckQuestion] stay in
/// English: they are what the trip record and the alert to Movera keep.
extension RideCheckTriggerText on RideCheckTrigger {
  /// "Long stop", "Arrêt prolongé", "Långt stopp".
  String get text => switch (this) {
    RideCheckTrigger.droppedFar => tr.rcTriggerDroppedFar,
    RideCheckTrigger.longStop => tr.rcTriggerLongStop,
    RideCheckTrigger.offRoute => tr.rcTriggerOffRoute,
    RideCheckTrigger.possibleCrash => tr.rcTriggerPossibleCrash,
  };
}

extension RideCheckTopicText on RideCheckTopic {
  /// The row on the card.
  String get text => switch (this) {
    RideCheckTopic.accident => tr.rcTopicAccident,
    RideCheckTopic.hurt => tr.rcTopicHurt,
    RideCheckTopic.unsafe => tr.rcTopicUnsafe,
    RideCheckTopic.carProblem => tr.rcTopicCarProblem,
    RideCheckTopic.riderAskedStop => tr.rcTopicRiderAskedStop,
    RideCheckTopic.traffic => tr.rcTopicTraffic,
    RideCheckTopic.riderStopHere => tr.rcTopicRiderStopHere,
    RideCheckTopic.riderChangedDestination => tr.rcTopicRiderChangedDestination,
    RideCheckTopic.roadClosed => tr.rcTopicRoadClosed,
    RideCheckTopic.riderOtherRoute => tr.rcTopicRiderOtherRoute,
    RideCheckTopic.somethingElse => tr.cancelReasonSomethingElse,
  };

  /// For the follow-up header, e.g. "RIDE CHECK · ACCIDENT".
  String get shortText => switch (this) {
    RideCheckTopic.accident => tr.rcShortAccident,
    RideCheckTopic.hurt => tr.rcShortHurt,
    RideCheckTopic.unsafe => tr.rcShortUnsafe,
    RideCheckTopic.carProblem => tr.rcTopicCarProblem,
    RideCheckTopic.riderAskedStop ||
    RideCheckTopic.riderStopHere => tr.rcShortRiderStop,
    RideCheckTopic.traffic => tr.rcShortTraffic,
    RideCheckTopic.riderChangedDestination => tr.rcShortNewDestination,
    RideCheckTopic.roadClosed => tr.rcShortRoadClosed,
    RideCheckTopic.riderOtherRoute => tr.rcShortOtherRoute,
    RideCheckTopic.somethingElse => tr.cancelReasonSomethingElse,
  };
}

extension RideCheckQuestionText on RideCheckQuestion {
  /// The question in the driver's language.
  String get shown => rideCheckQuestionWords(text);

  /// An answer button: "Yes" -> "Oui", "Ja".
  static String option(String answer) => rideCheckAnswerWords(answer);
}

/// A saved question ([RideCheckQuestion.text]) in the driver's language.
String rideCheckQuestionWords(String text) => switch (text) {
    'Is anyone hurt?' => tr.rcQuestionAnyoneHurt,
    'Is the car in a safe place?' => tr.rcQuestionCarSafe,
    'Is the other person OK?' => tr.rcQuestionOtherPersonOk,
    'Who needs help?' => tr.rcQuestionWhoNeedsHelp,
    'Are you in danger right now?' => tr.rcQuestionInDanger,
    'Can you continue the trip?' => tr.rcQuestionCanContinue,
    'Call 112' => tr.call112,
    '112 dialer' => tr.rcDialer112,
    'What happened' => tr.rcWhatHappened,
    _ => text,
  };

/// A saved answer (an option or a topic row) in the driver's language.
String rideCheckAnswerWords(String answer) {
  for (final topic in RideCheckTopic.values) {
    if (topic.label == answer) return topic.text;
  }
  return switch (answer) {
    RideCheckQuestion.yes => tr.rcAnswerYes,
    RideCheckQuestion.no => tr.rcAnswerNo,
    RideCheckQuestion.notSure => tr.rcAnswerNotSure,
    'Me' => tr.rcAnswerMe,
    'The rider' => tr.rcAnswerTheRider,
    'Someone else' => tr.rcAnswerSomeoneElse,
    // Saved before driver-u43; new checks save 'Call 112' and the outcome.
    'Called 112' => tr.rcCalled112,
    'Call 112' => tr.call112,
    'Opened' => tr.rcDialerOpened,
    'Did not open' => tr.rcDialerDidNotOpen,
    "I'm OK" => tr.iMOk,
    _ => answer,
  };
}
