// Driver group 2 "Onboarding" (owner decisions of 2026-10-29): the
// behaviour that was wrong before, written only against APIs main already
// had, so it fails on main and passes with this change (SE and FR).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/contracts/zone_settings.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/l10n/driver_language.dart';
import 'package:movera/core/live/live_error_message.dart';

DriverAccountRepository _repository(
  Future<http.Response> Function(http.Request) answer,
) => DriverAccountRepository(
  ApiClient(
    client: MockClient(answer),
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  ),
);

void main() {
  for (final country in ['SE', 'FR']) {
    group(country, () {
      setUp(() => DriverLanguage.applyZone(AppLanguages.forCountry(country)));

      // Item 6: "wait up to 60 s". Main cut every upload at 15 s.
      testWidgets('a document upload that takes 40 s arrives', (tester) async {
        final repository = _repository((_) async {
          await Future<void>.delayed(const Duration(seconds: 40));
          return http.Response(
            '{"documentId":"d","ownerId":"drv_1","type":"driving_license",'
            '"status":"in_review","version":1}',
            201,
            headers: {'content-type': 'application/json'},
          );
        });
        AccountDocument? done;
        Object? failed;
        unawaited(
          repository
              .uploadDocument(
                type: 'driving_license',
                bytes: Uint8List.fromList([1, 2, 3]),
                fileName: 'a.jpg',
                mediaType: 'image/jpeg',
              )
              .then((d) => done = d, onError: (Object e) => failed = e),
        );
        await tester.pump(const Duration(seconds: 41));
        expect(failed, isNull);
        expect(done?.status, 'in_review');
      });

      // Items 1 and 3: an expired document names the document and says
      // to upload the new one (main said "not approved").
      test('going online refused for an expired document says so', () {
        final message = liveAvailabilityErrorMessage(
          const ApiError(
            statusCode: 409,
            code: 'documents_not_approved',
            message: 'x',
            reason: 'documents_expired',
            details: ['driver:driving_license'],
          ),
          online: true,
        );
        // "has expired" in the driver's language, with the document.
        expect(message, contains(country == 'FR' ? 'expiré' : 'gått ut'));
        expect(
          message,
          contains(
            DriverOnboardingRules.documentName(
              'driving_license',
              tr.localeName,
            ),
          ),
        );
        expect(message, isNot(tr.liveOnlineFailed));
      });

      // Item 9: a fleet with no approved car (main fell back to "could not
      // go online").
      test('a fleet with no approved car is said plainly', () {
        final message = liveAvailabilityErrorMessage(
          const ApiError(
            statusCode: 409,
            code: 'invalid_transition',
            message: 'x',
            reason: 'fleet_no_approved_car',
          ),
          online: true,
        );
        expect(message, isNot(tr.liveOnlineFailed));
      });

      // Item 11: the four car photos have names (main showed
      // "vehicle_photo_front").
      test('the car photo types have names in sv / fr / en', () {
        for (final type in [
          'vehicle_photo_front',
          'vehicle_photo_back',
          'vehicle_photo_side',
          'vehicle_photo_inside',
        ]) {
          expect(
            DriverOnboardingRules.documentName(type, tr.localeName),
            isNot(type),
          );
        }
      });

      // Items 8 and 13: the info session's "How to book" text is read
      // (main dropped the slot).
      test('the driver-info-session content slot is kept', () {
        final item = DriverContentItem.tryParse({
          'slot': 'driver-info-session',
          'zoneId': country == 'FR' ? 'FR-PC' : 'Z001',
          'version': 1,
          'title': 'Info',
          'text': {'sv': 'Boka', 'fr': 'Réserver', 'en': 'Book'},
        });
        expect(item, isNotNull);
      });
    });
  }
}
