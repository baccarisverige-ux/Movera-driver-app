// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations_profile.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ProfileLocalizationsEn extends ProfileLocalizations {
  ProfileLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get mppTitle => 'My profile';

  @override
  String get mppIntro => 'This is what riders see when they tap your card.';

  @override
  String get mppLanguages => 'Languages I speak';

  @override
  String get mppLanguagesHint => 'Pick up to 6.';

  @override
  String get mppShowCity => 'Show my city';

  @override
  String get mppShowYears => 'Show how long I have driven with Movera';

  @override
  String get mppCompliments => 'What riders say';

  @override
  String get mppNoCompliments => 'No compliments yet.';

  @override
  String get mppReviews => 'Reviews';

  @override
  String get mppNoReviews => 'No reviews yet.';

  @override
  String get mppReviewPending => 'Waiting for approval';

  @override
  String get mppReviewApproved => 'Shown to riders';

  @override
  String get mppReviewHidden => 'Hidden';

  @override
  String get mppAnonymous => 'Anonymous';

  @override
  String get mppViewAsRider => 'View as rider';

  @override
  String get mppProfileOff =>
      'The driver profile is off in your zone. Riders see only your name, car and rating.';

  @override
  String get mppReviewsOff => 'Written reviews are off in your zone.';

  @override
  String get mppLoadError => 'Could not load your profile.';

  @override
  String get mppSaveError => 'Could not save. Try again.';

  @override
  String get mppRetry => 'Try again';

  @override
  String get mppTrips => 'Trips';

  @override
  String get mppRating => 'Rating';

  @override
  String get mppYears => 'Years';

  @override
  String get mppLatestReview => 'Latest review';

  @override
  String get mppMilestones => 'Milestones';

  @override
  String get mppMilestoneTrips1000 => '1,000 trips';

  @override
  String get mppMilestoneTopRating => 'Top rating';

  @override
  String get complimentGreatService => 'Excellent service';

  @override
  String get complimentKnewTheWay => 'Good route';

  @override
  String get complimentFriendly => 'Nice conversation';

  @override
  String get complimentCleanCar => 'Clean car';

  @override
  String get complimentSafeDriving => 'Safe driving';

  @override
  String get complimentGoodMusic => 'Good music';

  @override
  String mppSince(String month) {
    return 'Movera driver since $month';
  }

  @override
  String get mppLanguagesMax => 'You picked 6. Remove one to pick another.';
}
