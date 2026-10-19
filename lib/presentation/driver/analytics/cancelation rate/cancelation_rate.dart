import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/admin/driver_home_admin_content.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/expantion_tile.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/rate_rule_note.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class CancelationRate extends StatelessWidget {
  const CancelationRate({
    super.key,
    this.performance = DriverPerformanceConfig.sample,
  });

  /// Sample numbers until the driver's real rates exist: the same ones as
  /// Analytics and the Home performance sheet (UI-10).
  final DriverPerformanceConfig performance;

  /// "2.4%" of the counted offers or trips.
  String get _rateShare => performance.cancellationLabel;

  /// What is left of 100 %.
  String get _otherShare {
    final rest = 100 - performance.cancellationRate;
    return '${rest.toStringAsFixed(rest == rest.roundToDouble() ? 0 : 1)}%';
  }

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
          text: "Cancelation Rate",
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
            text: performance.cancellationLabel,
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
                color: AppColor.red,
                height: 17 * ResSize.h,
              ),
              6.width,
              TextWidget(
                text: 'Sample',
                color: AppColor.red,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
              6.width,
              TextWidget(
                text: 'not your real rate yet',
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
                text: '100%',
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
                text: _otherShare,
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
                text: _rateShare,
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ],
          ),
          16.height,
          TextWidget(
            text: 'Sample numbers for this preview, not your real rate.',
            color: AppColor.title,
            fontSize: 12,
            fontWeight: fwMedium,
          ),
          16.height,
          const RateRuleNote(
            key: ValueKey<String>('cancel-rate-rule'),
            title: 'Keep your cancel rate low to keep full access to trips',
            body: 'Every cancel counts, except reasons marked “Doesn’t count”, such as a rider no-show or a safety issue.',
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
            title: 'How your cancelation is calculated',
            child: TextWidget(
              text: 'Your cancellation rate is calculated based on the number of trips you cancel compared to the total trips you confirm. We use your last 100 confirmed trip requests to determine this percentage.',
              color: AppColor.subtitle,
              fontSize: 14,
              fontWeight: fwNormal,
            ),
          ),
          // 6.height,
          CustomExpansionTile(
            iconAsset: AppAssets.infoOutl,
            title: 'Why cancelation rate matters',
            child: TextWidget(
              text: 'A high cancellation rate affects the reliability of our service and can impact your ability to get ride requests. Maintaining a low cancellation rate helps ensure better service for all users.',
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
