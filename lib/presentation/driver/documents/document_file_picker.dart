import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movera/core/onboarding/document_upload.dart';

/// A file the driver chose for a document upload.
class PickedDocumentFile {
  const PickedDocumentFile({
    required this.bytes,
    required this.fileName,
    required this.mediaType,
  });

  final Uint8List bytes;
  final String fileName;

  /// `image/jpeg`, `image/png`, `image/heic` or `application/pdf`.
  final String mediaType;
}

/// How the driver picks a file for a document: the camera, the photo
/// library or a file (PDF or image). Tests hand in a fake; the app uses
/// the device's pickers ([DeviceDocumentFilePicker]). A refused camera
/// throws (see `isCameraBlocked`).
abstract class DocumentFilePicker {
  Future<PickedDocumentFile?> takePhoto();
  Future<PickedDocumentFile?> choosePhoto();
  Future<PickedDocumentFile?> chooseFile();
}

class DeviceDocumentFilePicker implements DocumentFilePicker {
  const DeviceDocumentFilePicker();

  @override
  Future<PickedDocumentFile?> takePhoto() => _image(ImageSource.camera);

  @override
  Future<PickedDocumentFile?> choosePhoto() => _image(ImageSource.gallery);

  Future<PickedDocumentFile?> _image(ImageSource source) async {
    // Owner item 6: the photo is shrunk before it goes up.
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: DocumentUploadPolicy.photoQuality,
      maxWidth: DocumentUploadPolicy.photoMaxSide,
      maxHeight: DocumentUploadPolicy.photoMaxSide,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.isEmpty ? 'photo.jpg' : file.name;
    return PickedDocumentFile(
      bytes: bytes,
      fileName: name,
      mediaType: mediaTypeOf(name, fallback: file.mimeType ?? 'image/jpeg'),
    );
  }

  @override
  Future<PickedDocumentFile?> chooseFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return PickedDocumentFile(
      bytes: bytes,
      fileName: file.name,
      mediaType: mediaTypeOf(file.name, fallback: 'application/pdf'),
    );
  }

  /// The media type the server accepts for [fileName]'s extension.
  static String mediaTypeOf(String fileName, {required String fallback}) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return fallback;
  }
}
