import 'package:movera/core/l10n/driver_l10n.dart';
enum DriverDocumentType {
  license,
  insurance,
  vehicleVerification,
  nationalId,
}

enum DriverDocumentStatus { valid, expiring, expired, rejected }

class DriverDocument {
  const DriverDocument({
    required this.documentId,
    required this.type,
    required this.expiresOn,
    required this.status,
  });

  final String documentId;
  final DriverDocumentType type;
  final DateTime expiresOn;
  final DriverDocumentStatus status;

  String get label => switch (type) {
        DriverDocumentType.license => tr.docDriversLicense,
        DriverDocumentType.insurance => tr.insurance,
        DriverDocumentType.vehicleVerification => tr.docVehicleVerification,
        DriverDocumentType.nationalId => tr.docDriversId,
      };
}

abstract interface class DriverDocumentRepository {
  List<DriverDocument> get all;

  Future<List<DriverDocument>> load();

  Future<void> upsert(DriverDocument document);
}

class InMemoryDriverDocumentRepository implements DriverDocumentRepository {
  InMemoryDriverDocumentRepository({List<DriverDocument>? seed})
      : _documents = List<DriverDocument>.from(seed ?? const []);

  final List<DriverDocument> _documents;

  @override
  List<DriverDocument> get all => List.unmodifiable(_documents);

  @override
  Future<List<DriverDocument>> load() async {
    if (_documents.isEmpty) {
      _documents.addAll([
        DriverDocument(
          documentId: 'DOC-LIC-418',
          type: DriverDocumentType.license,
          expiresOn: DateTime(2027, 6, 15),
          status: DriverDocumentStatus.valid,
        ),
        DriverDocument(
          documentId: 'DOC-INS-418',
          type: DriverDocumentType.insurance,
          expiresOn: DateTime(2026, 3, 20),
          status: DriverDocumentStatus.expiring,
        ),
        DriverDocument(
          documentId: 'DOC-VEH-418',
          type: DriverDocumentType.vehicleVerification,
          expiresOn: DateTime(2027, 1, 1),
          status: DriverDocumentStatus.valid,
        ),
        DriverDocument(
          documentId: 'DOC-ID-418',
          type: DriverDocumentType.nationalId,
          expiresOn: DateTime(2031, 9, 1),
          status: DriverDocumentStatus.valid,
        ),
      ]);
    }
    return all;
  }

  @override
  Future<void> upsert(DriverDocument document) async {
    final index = _documents
        .indexWhere((item) => item.documentId == document.documentId);
    if (index >= 0) {
      _documents[index] = document;
    } else {
      _documents.add(document);
    }
  }
}
