import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/support/local_support_repository.dart';

void main() {
  test('draft and local conversation survive repository recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalSupportRepository();
    await repo.update('draft', {'subject': 'Help', 'message': 'Local only'});
    await repo.update('tickets', [
      {
        'subject': 'Question',
        'preview': 'Draft',
        'messages': [
          {'text': 'Draft', 'support': false},
        ],
      },
    ]);

    final restored = await LocalSupportRepository().read();
    expect((restored['draft'] as Map)['subject'], 'Help');
    expect((restored['tickets'] as List).length, 1);
  });

  test(
    'malformed support storage fails closed instead of inventing drafts',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalSupportRepository.key: '{broken-json',
      });

      await expectLater(
        LocalSupportRepository().read(),
        throwsA(isA<SupportDataUnreadable>()),
      );
    },
  );
}
