import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/auth_error_message.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// v0.18.134 (`contract.json#accountDeletion.closeAtOnce`): sign-in of a
/// closed (being deleted) account answers 403 `account_closed`.
void main() {
  test('403 account_closed is told plainly', () {
    const error = ApiError(
      code: 'forbidden',
      message: 'x',
      statusCode: 403,
      reason: 'account_closed',
    );
    expect(authErrorMessage(error, AuthAction.verifyCode), tr.acctClosedSignIn);
  });
}
