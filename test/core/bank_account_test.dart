import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/money/bank_account.dart';

void main() {
  test('clearing numbers name the bank; Swedbank 8xxxx needs five digits', () {
    expect(BankAccountRules.bankForClearing('8327-9'), 'Swedbank');
    expect(BankAccountRules.bankForClearing('8327'), isNull);
    expect(BankAccountRules.bankForClearing('5491'), 'SEB');
    expect(BankAccountRules.bankForClearing('6789'), 'Handelsbanken');
    expect(BankAccountRules.bankForClearing('3300'), 'Nordea');
    expect(BankAccountRules.bankForClearing('12'), isNull);
  });

  test('account numbers are 6 to 10 digits', () {
    expect(BankAccountRules.validAccount('123 456 789-0'), isTrue);
    expect(BankAccountRules.validAccount('12345'), isFalse);
    expect(BankAccountRules.validAccount('12345678901'), isFalse);
  });

  test('IBAN uses mod 97 and Swedish length; BIC is 8 or 11', () {
    expect(BankAccountRules.validIban('SE45 5000 0000 0583 9825 7466'), isTrue);
    expect(
      BankAccountRules.bankForIban('SE45 5000 0000 0583 9825 7466'),
      'SEB',
    );
    expect(
      BankAccountRules.validIban('SE46 5000 0000 0583 9825 7466'),
      isFalse,
    );
    expect(BankAccountRules.validIban('SE45 5000 0000 0583 9825'), isFalse);
    expect(BankAccountRules.validIban('DE89 3704 0044 0532 0130 00'), isTrue);
    expect(BankAccountRules.validBic('ESSESESS'), isTrue);
    expect(BankAccountRules.validBic('ESSESESSXXX'), isTrue);
    expect(BankAccountRules.validBic('ESSE'), isFalse);
  });
}
