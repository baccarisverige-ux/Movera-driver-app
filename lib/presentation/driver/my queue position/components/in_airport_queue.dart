import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/driver/my%20queue%20position/my_queue_pos.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class InAirportQueue extends StatelessWidget {
  const InAirportQueue({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            showMyQueuePositionSheet(context);
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResSize.w * 16,
              vertical: ResSize.h * 11,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColor.white,
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: Color(0xff262626).withValues(alpha: 0.12),
                  blurRadius: 30,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(AppAssets.flight, height: ResSize.h * 42),
                    16.width,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextWidget(
                            text: tr.queueAirportPreview,
                            fontSize: 16,
                            fontWeight: fwSemiBold,
                            color: AppColor.title,
                          ),
                          4.height,
                          TextWidget(
                            text: tr.queueSample10Ahead,
                            fontSize: 12,
                            fontWeight: fwMedium,
                            color: AppColor.subtitle,
                          ),
                          4.height,
                          TextWidget(
                            text: tr.queueViewSampleDetails,
                            fontSize: 12,
                            fontWeight: fwMedium,
                            color: Color(0xff0088FF),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: ResSize.h * 24,
                      width: ResSize.w * 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColor.title, width: 2),
                      ),
                      child: Center(
                        child: Icon(Icons.close_rounded, size: ResSize.h * 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
