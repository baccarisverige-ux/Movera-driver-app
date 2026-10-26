import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class AdditionDetailUploadId extends StatefulWidget {
  final Widget Function(int, int) circleProgress;
  const AdditionDetailUploadId({super.key, required this.circleProgress});

  @override
  // ignore: library_private_types_in_public_api
  _AdditionDetailUploadIdState createState() => _AdditionDetailUploadIdState();
}

class _AdditionDetailUploadIdState extends State<AdditionDetailUploadId> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: tr.uploadId,
                      color: AppColor.title,
                      fontSize: 24,
                      fontWeight: fwExtraBold,
                    ),
                    TextWidget(
                      text: tr.weNeedToVerifyYourId,
                      color: AppColor.subtitle,
                      fontSize: 16,
                      fontWeight: fwMedium,
                    ),
                  ],
                ),
              ),
              widget.circleProgress(3, 4),
            ],
          ),

          56.height,
          Center(
            child: Image.asset(AppAssets.scanCard, height: ResSize.h * 130),
          ),
          24.height,
          Center(
            child: TextWidget(
              textAlign: TextAlign.center,
              text: tr.approveAccountIdentityReason,
              color: AppColor.subtitle,
              fontSize: 14,
              fontWeight: fwNormal,
            ),
          ),
        ],
      ),
    );
  }
}
