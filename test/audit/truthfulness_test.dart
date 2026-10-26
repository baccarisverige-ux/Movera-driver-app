import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String source(String path) =>
    File('lib/presentation/driver/$path').readAsStringSync();
void main() {
  test('obsolete withdrawal simulation cannot re-enter the graph', () {
    expect(
      File(
        'lib/presentation/driver/my wallet/components/choose_bank.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File(
        'lib/presentation/driver/my wallet/components/withdraw_sucess.dart',
      ).existsSync(),
      isFalse,
    );
    expect(
      File('lib/presentation/driver/sheets/sheet_snap_state.dart').existsSync(),
      isFalse,
    );
    expect(
      source('my bank/add new account/add_new_account.dart'),
      contains('tr.bankPreviewNotSaved'),
    );
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(english['bankPreviewNotSaved'], contains('account not saved'));
    expect(source('my wallet/wallet.dart'), isNot(contains('\$50')));
    final leftovers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final text = file.readAsStringSync();
          return text.contains('choose_bank.dart') ||
              text.contains('withdraw_sucess.dart') ||
              text.contains('sheet_snap_state.dart');
        })
        .map((file) => file.path)
        .toList();
    expect(leftovers, isEmpty);
  });
}
