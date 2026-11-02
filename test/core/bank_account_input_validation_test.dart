import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/bank_account.dart';

void main() {
  test('clearing and account validation reject letters, signs and invalid punctuation', () {
    for (final value in [
      'abc5491',
      '5491xyz',
      '+5491',
      '-5491',
      '54/91',
      '5491-',
    ]) {
      expect(BankAccountRules.bankForClearing(value), isNull, reason: value);
    }
    for (final value in [
      'abc123456',
      '+123456',
      '-123456',
      '123.456',
      '123456-',
      '123--456',
    ]) {
      expect(BankAccountRules.validAccount(value), isFalse, reason: value);
    }
  });
  test('supported whitespace and digit grouping remain accepted', () {
    expect(BankAccountRules.bankForClearing(' 8327 - 9 '), 'Swedbank');
    expect(BankAccountRules.bankForClearing(' 5491 '), 'SEB');
    expect(BankAccountRules.validAccount('123 456 789-0'), isTrue);
    expect(BankAccountRules.validAccount('123\u00a0456'), isTrue);
  });
}
