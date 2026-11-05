import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/support/ticket_error_text.dart';
import 'package:movera/l10n/app_localizations.dart';

/// FIX JOB 7 (contract v0.18.30): the ticket form tells the driver why the
/// server refused a new ticket.
void main() {
  for (final lang in ['sv', 'fr', 'en']) {
    test(
      '$lang: invalid_ticket_body asks for a message; other refusals stay generic',
      () {
        final strings = lookupAppLocalizations(Locale(lang));
        const body = ApiError(
          code: 'invalid_request',
          message: 'x',
          reason: 'invalid_ticket_body',
        );
        const category = ApiError(
          code: 'invalid_request',
          message: 'x',
          reason: 'invalid_ticket_category',
        );
        expect(ticketErrorText(body, strings), strings.enterMessage);
        expect(ticketErrorText(category, strings), strings.supportSendFailed);
        expect(
          ticketErrorText(StateError('offline'), strings),
          strings.supportSendFailed,
        );
      },
    );
  }
}
