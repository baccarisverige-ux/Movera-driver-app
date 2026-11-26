import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';

/// Contract v0.18.166 (`signupV2.scanner`, owner 2026-11-26 "I approve it"):
/// "Scanner" in the Ajouter sheet. The system document scanner finds the
/// edges, takes the photo by itself when it is sharp (a manual button too),
/// straightens and crops it: VisionKit on iOS, the ML Kit document scanner
/// on Android (plugin `cunning_document_scanner`, MIT). On the web and on
/// other platforms [available] is false and the sheet shows only "Choisir
/// une photo ou un fichier".
abstract class DocumentScanner {
  bool get available;

  /// One scanned page as a JPEG, or null when the driver closed the scanner.
  /// Throws when the camera is refused or the scanner fails.
  Future<PickedDocumentFile?> scanOnePage();
}

class DeviceDocumentScanner implements DocumentScanner {
  const DeviceDocumentScanner();

  @override
  bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<PickedDocumentFile?> scanOnePage() async {
    final result = await CunningDocumentScanner.scanDocuments(
      noOfPages: 1,
      androidScannerMode: AndroidScannerMode.full,
    );
    final path = result?.images.firstOrNull;
    if (path == null) return null;
    final bytes = await XFile(path).readAsBytes();
    // The scanner's pages are large; the same shrink as a camera photo.
    final shrunk = await compute(_shrinkJpeg, bytes);
    return PickedDocumentFile(
      bytes: shrunk,
      fileName: 'scan.jpg',
      mediaType: 'image/jpeg',
    );
  }
}

/// The largest side of a page sent to the server (as a camera photo).
const int documentMaxSide = 2000;

Uint8List _shrinkJpeg(Uint8List bytes) {
  final page = img.decodeImage(bytes);
  if (page == null) return bytes;
  final resized = _fit(page, documentMaxSide);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
}

img.Image _fit(img.Image page, int maxSide) {
  final side = page.width > page.height ? page.width : page.height;
  if (side <= maxSide) return page;
  return page.width >= page.height
      ? img.copyResize(page, width: maxSide)
      : img.copyResize(page, height: maxSide);
}

/// Contract v0.18.166 (`signupV2.twoSided.upload`): the recto and the verso
/// joined into ONE JPEG, the recto above the verso, so the server keeps one
/// document with one file. Throws [UnsupportedSidesError] when one side is
/// not a picture the app can read (a PDF or HEIC): the driver then picks
/// a JPEG or PNG, or one PDF of both sides.
Future<PickedDocumentFile> joinSides(
  PickedDocumentFile front,
  PickedDocumentFile back,
) async {
  final joined = await compute(_join, [front.bytes, back.bytes]);
  if (joined == null) throw const UnsupportedSidesError();
  return PickedDocumentFile(
    bytes: joined,
    fileName: 'recto-verso.jpg',
    mediaType: 'image/jpeg',
  );
}

/// [joinSides] without the background isolate (tests, tiny files).
Future<PickedDocumentFile> joinSidesHere(
  PickedDocumentFile front,
  PickedDocumentFile back,
) async {
  final joined = _join([front.bytes, back.bytes]);
  if (joined == null) throw const UnsupportedSidesError();
  return PickedDocumentFile(
    bytes: joined,
    fileName: 'recto-verso.jpg',
    mediaType: 'image/jpeg',
  );
}

class UnsupportedSidesError implements Exception {
  const UnsupportedSidesError();
}

Uint8List? _join(List<Uint8List> sides) {
  final pages = [for (final side in sides) img.decodeImage(side)];
  if (pages.any((page) => page == null)) return null;
  final width = 1400;
  final scaled = [
    for (final page in pages) img.copyResize(page!, width: width),
  ];
  const gap = 24;
  final height = scaled.fold<int>(0, (sum, page) => sum + page.height) + gap;
  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  var y = 0;
  for (final page in scaled) {
    img.compositeImage(canvas, page, dstY: y);
    y += page.height + gap;
  }
  return Uint8List.fromList(img.encodeJpg(canvas, quality: 85));
}
