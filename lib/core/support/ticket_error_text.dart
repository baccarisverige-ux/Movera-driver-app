import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// FIX JOB 7 (contract v0.18.32, `contract.json#smallFixes.ticketReasons`):
/// the server names why a new ticket was refused. An empty or too long
/// subject / message (`invalid_ticket_body`) asks for a message; anything
/// else (including `invalid_ticket_category`, which the app's own topic list
/// never sends) stays "Could not send. Try again.". Existing texts only: the
/// l10n files are over the rule-25 size limit.
String ticketErrorText(Object error, AppLocalizations strings) {
  if (error is ApiError && error.reason == 'invalid_ticket_body') {
    return strings.enterMessage;
  }
  return strings.supportSendFailed;
}
