import 'package:movera/core/l10n/driver_l10n.dart';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mobkit_dashed_border/mobkit_dashed_border.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/logging/driver_log.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class VehicleDocumentUpload extends StatefulWidget {
  final Widget Function(int, int) circleProgress;
  const VehicleDocumentUpload({
    super.key,
    required this.circleProgress,
    required this.title,
    required this.subtitle,
    required this.progressIndex,
    this.selectFile,
    this.capturePhoto,
  });

  final String title;
  final String subtitle;
  final int progressIndex;
  final Future<PlatformFile?> Function()? selectFile;
  final Future<XFile?> Function()? capturePhoto;

  @override
  State<VehicleDocumentUpload> createState() => _VehicleDocumentUploadState();
}

class _VehicleDocumentUploadState extends State<VehicleDocumentUpload> {
  String? selectedFileName;
  Uint8List? selectedFileBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;
  bool get _ownsRoute => mounted && ModalRoute.of(context)?.isCurrent == true;
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextWidget(
                        text: widget.title,
                        color: AppColor.title,
                        fontSize: 24,
                        fontWeight: fwExtraBold,
                      ),
                      TextWidget(
                        text: widget.subtitle,
                        color: AppColor.subtitle,
                        fontSize: 16,
                        fontWeight: fwMedium,
                      ),
                    ],
                  ),
                ),
                widget.circleProgress(widget.progressIndex, 4),
              ],
            ),
            30.height,
            selectedFileName != null ? _buildFilePreview() : _buildUploadArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResSize.w * 32),
      decoration: BoxDecoration(
        border: DashedBorder.fromBorderSide(
          dashLength: ResSize.w * 4,
          spaceLength: ResSize.w * 7,
          side: BorderSide(color: AppColor.border, width: ResSize.w * 2),
        ),
        borderRadius: BorderRadius.circular(ResSize.w * 12),
      ),
      child: Column(
        children: [
          // Upload icon
          Container(
            width: ResSize.w * 80,
            height: ResSize.h * 80,
            decoration: BoxDecoration(
              color: AppColor.liteBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              color: AppColor.primary,
              size: ResSize.w * 32,
            ),
          ),

          24.height,

          // Tap to upload text
          TextButton(
            onPressed: _isPicking ? null : _pickAnyFile,
            child: TextWidget(
              text: tr.tapToUpload,
              color: Color(0xff30A1F7),
              fontSize: 16,
              fontWeight: fwMedium,
            ),
          ),

          7.height,

          // File format info
          TextWidget(
            text: "PNG, JPG, PDF",
            color: AppColor.subtitle,
            fontSize: 16,
            fontWeight: fwMedium,
            textAlign: TextAlign.center,
          ),
          14.height,
          // OR divider
          Row(
            children: [
              Expanded(child: Container(height: 0.5, color: AppColor.border)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ResSize.w * 16),
                child: TextWidget(
                  text: "OR",
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwMedium,
                ),
              ),
              Expanded(child: Container(height: 0.5, color: AppColor.border)),
            ],
          ),
          14.height,

          // Open Camera button
          TextButton(
            onPressed: _isPicking ? null : _openCamera,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResSize.w * 32,
                vertical: ResSize.h * 12,
              ),
              decoration: BoxDecoration(
                color: _isPicking ? Colors.grey[300] : Color(0xffD9D9D9),
                borderRadius: BorderRadius.circular(ResSize.w * 8),
              ),
              child: Center(
                child: TextWidget(
                  text: _isPicking ? tr.openingEllipsis : tr.openCamera,
                  color: AppColor.title,
                  fontSize: 14,
                  fontWeight: fwMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    String fileName = selectedFileName ?? 'document';
    String extension = fileName.split('.').last.toLowerCase();

    bool isImage = ['png', 'jpg', 'jpeg'].contains(extension);
    final bytes = selectedFileBytes;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // File preview
          isImage && bytes != null
              ? Image.memory(bytes, height: 60, width: 60, fit: BoxFit.cover)
              : const Icon(Icons.picture_as_pdf, size: 50, color: Colors.red),

          const SizedBox(width: 12),

          // File name
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Remove button
          IconButton(
            tooltip: tr.close,
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                selectedFileName = null;
                selectedFileBytes = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAnyFile() async {
    if (!_ownsRoute || _isPicking) return;
    setState(() => _isPicking = true);
    try {
      PlatformFile? file;
      if (widget.selectFile != null) {
        file = await widget.selectFile!();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
          withData: true,
        );
        file = result?.files.single;
      }
      if (!_ownsRoute || file == null) return;
      var bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await XFile(file.path!).readAsBytes();
      }
      if (!_ownsRoute) return;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('Document bytes are unavailable');
      }
      final fileName = file.name;
      setState(() {
        selectedFileName = fileName;
        selectedFileBytes = bytes;
      });
      _showSuccessMessage(tr.fileSelectedSuccessfully);
    } catch (error, stack) {
      DriverLog.error(tr.vehicleDocumentSelectionFailed, error, stack);
      _showErrorMessage(tr.couldNotReadSelectedFile);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _openCamera() async {
    if (!_ownsRoute || _isPicking) return;
    setState(() => _isPicking = true);

    try {
      final XFile? image =
          await (widget.capturePhoto?.call() ??
              _picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 800,
                maxHeight: 400,
              ));

      if (image != null && _ownsRoute) {
        final bytes = await image.readAsBytes();
        if (!_ownsRoute) return;
        if (bytes.isEmpty) {
          throw const FormatException('Photo bytes are unavailable');
        }
        setState(() {
          selectedFileName = image.name;
          selectedFileBytes = bytes;
        });
        _showSuccessMessage(tr.photoCapturedSuccessfully);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(
          tr.couldNotReadCapturedPhoto,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false); // ✅ Reset state properly
      }
    }
  }

  void _showSuccessMessage(String message) {
    if (!_ownsRoute) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!_ownsRoute) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
