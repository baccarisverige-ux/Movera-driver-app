import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/live/live_public_profile.dart';
import 'package:movera/presentation/driver/profile/my_public_profile.dart';

/// v0.18.147 driver profile (owner 2026-11-20 "Now build all";
/// contract.json#driverProfile.apps.driver): Min profil lets the driver
/// pick languages, hide the city and years, see compliments and reviews,
/// and open "View as rider". The emoji are the phone's own (Text).
class _Fake implements PublicProfileApi {
  _Fake(this.state);
  OwnPublicProfile state;
  final saves = <Map<String, Object?>>[];

  @override
  Future<OwnPublicProfile> read() async => state;

  @override
  Future<OwnPublicProfile> save({
    List<String>? languages,
    bool? showCity,
    bool? showYears,
  }) async {
    saves.add({
      'languages': languages,
      'showCity': showCity,
      'showYears': showYears,
    });
    state = OwnPublicProfile(
      languages: languages ?? state.languages,
      showCity: showCity ?? state.showCity,
      showYears: showYears ?? state.showYears,
      profileOn: true,
      reviewsOn: true,
      preview: PublicProfilePreview(
        firstName: 'Ali',
        languages: languages ?? state.languages,
        city: (showCity ?? state.showCity) ? 'Stockholm' : null,
        tripCount: 1284,
        rating: 4.9,
      ),
      compliments: state.compliments,
      reviews: state.reviews,
    );
    return state;
  }
}

OwnPublicProfile _start() => const OwnPublicProfile(
  languages: ['sv'],
  showCity: true,
  showYears: true,
  profileOn: true,
  reviewsOn: true,
  preview: PublicProfilePreview(
    firstName: 'Ali',
    verified: true,
    languages: ['sv'],
    city: 'Stockholm',
    sinceMonth: '2023-03',
    years: 3,
    tripCount: 1284,
    rating: 4.9,
  ),
  compliments: [
    ProfileCompliment('great_service', 42),
    ProfileCompliment('clean_car', 31),
  ],
  reviews: [
    ProfileReview(
      text: 'Punktlig.',
      name: 'Sara',
      month: '2026-11',
      status: 'approved',
    ),
    ProfileReview(text: 'Trevlig.', month: '2026-11', status: 'pending'),
  ],
);

void main() {
  testWidgets('compliments as emoji text tiles, reviews with their status', (
    tester,
  ) async {
    final api = _Fake(_start());
    await tester.pumpWidget(MaterialApp(home: MyPublicProfileScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('⭐'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('✨'), findsOneWidget);
    expect(
      find.byType(Image),
      findsNothing,
      reason: 'no image files for the emoji',
    );
    await tester.scrollUntilVisible(find.text('“Trevlig.”'), 200);
    expect(find.text('Waiting for approval'), findsOneWidget);
    expect(find.text('Anonymous · 2026-11'), findsOneWidget);
  });

  testWidgets(
    'languages and Show my city are saved; View as rider shows the result',
    (tester) async {
      final api = _Fake(_start());
      await tester.pumpWidget(
        MaterialApp(home: MyPublicProfileScreen(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();
      expect(api.saves.last['languages'], ['sv', 'ar']);
      await tester.tap(find.byKey(const ValueKey('mpp-show-city')));
      await tester.pumpAndSettle();
      expect(api.saves.last['showCity'], false);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('mpp-view-as-rider')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('mpp-view-as-rider')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mpp-preview')), findsOneWidget);
      expect(find.textContaining('Stockholm'), findsNothing);
      expect(find.textContaining('Svenska · العربية'), findsOneWidget);
    },
  );
}
