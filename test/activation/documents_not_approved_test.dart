import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/api/api_error.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/presentation/driver/account/fleet_car_card.dart';

/// Contract v0.14.0 (owner 2026-10-28): a car whose required documents are
/// not all approved can't be picked or driven; the app names what is missing.
void main() {
  tearDown(() => DriverAppTexts.language = 'en');

  const carRefused = ApiError(
    code: 'documents_not_approved',
    message: 'Required documents are not approved',
    reason: 'vehicle_documents_not_approved',
    statusCode: 409,
    details: ['vehicle:vehicle_registration', 'vehicle:insurance'],
  );

  test('going online with a car missing documents names them (en/sv/fr)', () {
    expect(
      liveAvailabilityErrorMessage(carRefused, online: true),
      "This car can't be driven until its documents are approved. Missing: Registration certificate, Vehicle insurance",
    );
    DriverAppTexts.language = 'sv';
    expect(
      liveAvailabilityErrorMessage(carRefused, online: true),
      contains('Registreringsbevis, Försäkringsbrev'),
    );
    DriverAppTexts.language = 'fr';
    expect(
      accountErrorMessage(carRefused, fallback: 'x'),
      contains('Assurance transport de personnes'),
    );
  });

  test('the account documents get their own message', () {
    const refused = ApiError(
      code: 'documents_not_approved',
      message: 'x',
      statusCode: 409,
      details: ['driver:terms', 'fleet:company_registration'],
    );
    expect(
      accountErrorMessage(refused, fallback: 'x'),
      "Your account can't be used until these documents are approved: Terms and conditions, Company registration",
    );
    expect(refused.missingDocumentTypes, ['terms', 'company_registration']);
  });

  FleetVehicle car(String status) => FleetVehicle(
    vehicleId: 'V1',
    make: 'Volvo',
    model: 'V90',
    year: 2022,
    color: 'black',
    plate: 'ABC 123',
    seats: 4,
    categoryIds: const ['standard'],
    status: 'approved',
    version: 1,
    documents: [
      DocumentSummary(
        documentId: 'd1',
        type: 'vehicle_registration',
        status: status,
      ),
      const DocumentSummary(
        documentId: 'd2',
        type: 'insurance',
        status: 'approved',
      ),
    ],
    requiredDocuments: const ['vehicle_registration', 'insurance'],
  );

  testWidgets(
    'a car with unapproved documents shows why and has no pick button',
    (tester) async {
      final blocked = car('in_review');
      expect(blocked.canBeDriven, isFalse);
      expect(blocked.missingDocuments, ['vehicle_registration']);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetCarCard(
              vehicle: blocked,
              myDriverId: 'D1',
              onPick: () {},
            ),
          ),
        ),
      );
      expect(find.text("Can't be driven – upload documents"), findsOneWidget);
      expect(find.text('Registration certificate'), findsOneWidget);
      expect(find.byKey(const ValueKey('car-pick-V1')), findsNothing);

      final ready = car('approved');
      expect(ready.canBeDriven, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FleetCarCard(vehicle: ready, myDriverId: 'D1', onPick: () {}),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('car-docs-missing-V1')), findsNothing);
      expect(find.byKey(const ValueKey('car-pick-V1')), findsOneWidget);
    },
  );

  // Page audit round 2 (2026-11-01): Fordon showed "…Prioritet · " when a
  // category id was empty; the category line never ends with " · ".
  testWidgets('the category line has no stray separator', (tester) async {
    final base = car('approved');
    final vehicle = FleetVehicle(
      vehicleId: base.vehicleId,
      make: base.make,
      model: base.model,
      year: base.year,
      color: base.color,
      plate: base.plate,
      seats: base.seats,
      categoryIds: const ['standard', 'priority', '', ' '],
      status: base.status,
      version: base.version,
      documents: base.documents,
      requiredDocuments: base.requiredDocuments,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FleetCarCard(vehicle: vehicle, myDriverId: 'D1', onPick: () {}),
        ),
      ),
    );
    expect(find.text('standard · Priority'), findsOneWidget);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '');
    expect(texts.where((t) => t.trimRight().endsWith('·')), isEmpty);
  });
}
