import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/account/driver_account_repository.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/presentation/driver/documents/live_documents_screen.dart';

/// Round 4: the live Documents screen lists what the server requires and
/// uploads a chosen file.
class _FakePicker implements DocumentFilePicker {
  _FakePicker(this.file);
  final PickedDocumentFile? file;
  final List<String> calls = [];

  @override
  Future<PickedDocumentFile?> takePhoto() async {
    calls.add('camera');
    return file;
  }

  @override
  Future<PickedDocumentFile?> choosePhoto() async {
    calls.add('gallery');
    return file;
  }

  @override
  Future<PickedDocumentFile?> choosePdf() async {
    calls.add('pdf');
    return file;
  }
}

const _profile = {
  'driverId': 'drv_1',
  'accountStatus': 'on_hold',
  'onlineStatus': 'offline',
  'firstName': 'Eva',
  'accountType': 'fleet',
  'country': 'SE',
  'zoneIds': ['Z001'],
  'categoryIds': [],
  'fleet': {
    'fleetId': 'flt_1',
    'name': 'Nord AB',
    'role': 'owner',
    'status': 'pending',
  },
  'documents': [
    {'documentId': 'doc_t', 'type': 'terms', 'status': 'approved'},
    {'documentId': 'doc_dl', 'type': 'driving_license', 'status': 'rejected'},
  ],
  'requiredDocuments': [
    'terms',
    'info_session',
    'driving_license',
    'profile_photo',
  ],
  'requiredFleetDocuments': ['company_registration', 'bank_statement'],
  'version': 2,
};

class _Server {
  final List<http.Request> uploads = [];

  http.Client get client => MockClient((request) async {
    http.Response json(int status, Object map) => http.Response(
      jsonEncode(map),
      status,
      headers: {'content-type': 'application/json'},
    );
    switch (request.url.path) {
      case DriverAccountRepository.profilePath:
        return json(200, _profile);
      case DriverAccountRepository.vehiclesPath:
        return json(200, {
          'items': [
            {
              'vehicleId': 'veh_1',
              'make': 'Volvo',
              'model': 'XC60',
              'year': 2022,
              'color': 'Black',
              'plate': 'ABC123',
              'seats': 4,
              'categoryIds': ['comfort'],
              'status': 'pending',
              'version': 1,
              'fleetId': 'flt_1',
              'documents': [
                {
                  'documentId': 'doc_v',
                  'type': 'insurance',
                  'status': 'in_review',
                },
              ],
              'requiredDocuments': ['vehicle_registration', 'insurance'],
            },
          ],
        });
      case DriverAccountRepository.documentsPath when request.method == 'GET':
        return json(200, {
          'items': [
            {
              'documentId': 'doc_dl',
              'ownerId': 'drv_1',
              'type': 'driving_license',
              'status': 'rejected',
              'reviewNote': 'Blurry photo',
              'version': 2,
            },
          ],
        });
      case DriverAccountRepository.documentsPath:
        uploads.add(request);
        final type = RegExp(
          r'name="type"\r\n\r\n(\w+)',
        ).firstMatch(latin1.decode(request.bodyBytes))!.group(1);
        final owner = RegExp(
          r'name="ownerId"\r\n\r\n(\w+)',
        ).firstMatch(latin1.decode(request.bodyBytes))?.group(1);
        return json(201, {
          'documentId': 'doc_new',
          'ownerId': owner ?? 'drv_1',
          'type': type,
          'status': 'in_review',
          'fileName': 'photo.jpg',
          'version': 1,
        });
    }
    return json(404, {'code': 'not_found', 'message': 'x'});
  });
}

Future<_Server> _pump(WidgetTester tester, _FakePicker picker) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final server = _Server();
  final api = ApiClient(
    client: server.client,
    baseUri: Uri.parse('https://api.test.movera.se'),
    tokens: MemoryTokenStore()..save(access: 'a', refresh: 'r'),
  );
  final session = DriverAccountSession(
    repository: DriverAccountRepository(api),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: LiveDocumentsScreen(account: session, filePicker: picker),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return server;
}

void main() {
  testWidgets('the rows follow the server lists: You, Company and the car, '
      'with the status chips and the rejection note', (tester) async {
    await _pump(tester, _FakePicker(null));
    expect(find.text(tr.docYou.toUpperCase()), findsOneWidget);
    expect(find.text(tr.docCompany.toUpperCase()), findsOneWidget);
    expect(find.text(tr.docCar('ABC123').toUpperCase()), findsOneWidget);
    // Names from the contract copy, in English.
    expect(find.text('Driving licence'), findsOneWidget);
    expect(find.text('Company registration'), findsOneWidget);
    expect(find.text('Registration certificate'), findsOneWidget);
    // terms is approved at sign-up; the information session is Movera's.
    final terms = find.byKey(const ValueKey('doc-row-drv_1-terms'));
    expect(
      find.descendant(
        of: terms,
        matching: find.text(tr.swDocumentStatusApproved),
      ),
      findsOneWidget,
    );
    expect(find.text(tr.docMoveraBooks), findsOneWidget);
    expect(find.text('Blurry photo'), findsOneWidget);
    expect(find.text(tr.swDocumentStatusRejected), findsOneWidget);
    expect(find.text(tr.swDocumentStatusInReview), findsOneWidget);
    expect(find.text(tr.swDocumentStatusNeeded), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tap a needed car document, choose a photo: multipart upload '
      'with the vehicle as owner, the row turns In review', (tester) async {
    final picker = _FakePicker(
      PickedDocumentFile(
        bytes: Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]),
        fileName: 'photo.jpg',
        mediaType: 'image/jpeg',
      ),
    );
    final server = await _pump(tester, picker);
    final row = find.byKey(
      const ValueKey('doc-row-veh_1-vehicle_registration'),
    );
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    expect(find.text(tr.docChooseHow), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doc-pick-gallery')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(picker.calls, ['gallery']);
    final upload = server.uploads.single;
    expect(upload.headers['content-type'], startsWith('multipart/form-data'));
    expect(
      latin1.decode(upload.bodyBytes),
      contains('name="type"\r\n\r\nvehicle_registration'),
    );
    expect(
      latin1.decode(upload.bodyBytes),
      contains('name="ownerId"\r\n\r\nveh_1'),
    );
    expect(latin1.decode(upload.bodyBytes), contains('filename="photo.jpg"'));
    expect(
      find.descendant(
        of: row,
        matching: find.text(tr.swDocumentStatusInReview),
      ),
      findsOneWidget,
    );
    expect(find.text(tr.docUploaded), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a file over 10 MB is refused before it is sent', (tester) async {
    final picker = _FakePicker(
      PickedDocumentFile(
        bytes: Uint8List(10485761),
        fileName: 'big.pdf',
        mediaType: 'application/pdf',
      ),
    );
    final server = await _pump(tester, picker);
    final row = find.byKey(const ValueKey('doc-row-drv_1-profile_photo'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('doc-pick-pdf')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(server.uploads, isEmpty);
    expect(find.text(tr.docFileTooLarge), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
