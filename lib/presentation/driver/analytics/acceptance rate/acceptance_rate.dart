import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/expantion_tile.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/rate_rule_note.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class AcceptanceRate extends StatelessWidget {
  const AcceptanceRate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        actionsPadding: EdgeInsets.all(0),
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.white,
        clipBehavior: Clip.none,
        foregroundColor: AppColor.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            popOwned(context);
          },
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColor.title,
            size: ResSize.h * 18,
          ),
        ),
        centerTitle: true,
        title: TextWidget(
          text: "Acceptance Rate",
          color: AppColor.title,
          fontSize: 16,
          fontWeight: fwMedium,
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _metricHero(),
            _tripsConfirmedSection(),
            _moreInformation(),
            24.height,
          ],
        ),
      ),
    );
  }

  Widget _metricHero() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF7F7F7),
      padding: EdgeInsets.symmetric(vertical: 50 * ResSize.h),
      child: Column(
        children: [
          TextWidget(
            text: '%90',
            color: AppColor.black,
            fontSize: 36,
            fontWeight: fwSemiBold,
          ),
          4.height,
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Image.asset(
                AppAssets.triangle,
                color: AppColor.green,
                height: 17 * ResSize.h,
              ),
              6.width,
              TextWidget(
                text: '9/10',
                color: AppColor.green,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
              6.width,
              TextWidget(
                text: 'last 10 confirmed trips',
                color: AppColor.subtitle,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tripsConfirmedSection() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16 * ResSize.w,
        vertical: 18 * ResSize.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextWidget(
                  text: 'Trips confirmed',
                  color: AppColor.title,
                  fontSize: 20,
                  fontWeight: fwSemiBold,
                ),
              ),
              TextWidget(
                text: '100',
                color: AppColor.title,
                fontSize: 20,
                fontWeight: fwSemiBold,
              ),
            ],
          ),
          14.height,
          Divider(color: AppColor.subtitle, height: 0, thickness: 0.2),
          14.height,
          Row(
            children: [
              Icon(
                Icons.check_rounded,
                color: AppColor.green,
                size: 22 * ResSize.h,
              ),
              12.width,
              Expanded(
                child: TextWidget(
                  text: 'completed trips',
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwMedium,
                ),
              ),
              TextWidget(
                text: '95',
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
          12.height,
          Row(
            children: [
              Icon(
                Icons.close_rounded,
                color: const Color(0xFFED6C30),
                size: 22 * ResSize.h,
              ),
              12.width,
              Expanded(
                child: TextWidget(
                  text: 'Canceled trips',
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwMedium,
                ),
              ),
              TextWidget(
                text: '5',
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
          16.height,
          TextWidget(
            text: 'Based on your last 100 requests',
            color: AppColor.title,
            fontSize: 12,
            fontWeight: fwMedium,
          ),
          16.height,
          const RateRuleNote(
            key: ValueKey<String>('acceptance-rate-rule'),
            title: 'Only Exclusive offers count',
            body: 'Exclusive offers and other offers sent only to you count. Radar trips never count.',
          ),
          16.height,
          Divider(color: AppColor.subtitle, height: 0, thickness: 0.2),
        ],
      ),
    );
  }

  Widget _moreInformation() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * ResSize.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextWidget(
            text: 'More Information',
            color: AppColor.title,
            fontSize: 20,
            fontWeight: fwSemiBold,
          ),
          14.height,
          CustomExpansionTile(
            iconAsset: AppAssets.calculator,
            title: 'How your acceptance rate is calculated',
            child: TextWidget(
              text: 'Your acceptance rate is the Exclusive offers you accept compared with all the Exclusive offers you receive. Radar trips never count. We use your last 100 Exclusive offers.',
              color: AppColor.subtitle,
              fontSize: 14,
              fontWeight: fwNormal,
            ),
          ),
          CustomExpansionTile(
            iconAsset: AppAssets.infoOutl,
            title: 'Why acceptance rate matters',
            child: TextWidget(
              text: 'A low acceptance rate reduces your chances of receiving ride requests and may affect your standing on the platform. Maintaining a high acceptance rate helps you get more trips and ensures a reliable experience for riders.',
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
