import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'vehicle_document_upload.dart';

class AdditionDetailVehicleInsurance extends StatelessWidget {
  const AdditionDetailVehicleInsurance({
    super.key,
    required this.circleProgress,
    this.selectFile,
    this.capturePhoto,
  });
  final Widget Function(int, int) circleProgress;
  final Future<PlatformFile?> Function()? selectFile;
  final Future<XFile?> Function()? capturePhoto;

  @override
  Widget build(BuildContext context) => VehicleDocumentUpload(
    title: tr.insurance,
    subtitle: tr.uploadCarInsurance,
    progressIndex: 2,
    circleProgress: circleProgress,
    selectFile: selectFile,
    capturePhoto: capturePhoto,
  );
}
