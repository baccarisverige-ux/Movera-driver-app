import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/models/onboarding.dart';
import 'package:movera/presentation/driver/auth/additional%20detail/screens/upload%20document/take%20id%20photo/take_id_photo.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class SelectDocumentType extends StatefulWidget {
  const SelectDocumentType({super.key});

  @override
  State<SelectDocumentType> createState() => _SelectDocumentTypeState();
}

class _SelectDocumentTypeState extends State<SelectDocumentType> {
  List<OnBoardingModel> items = [
    OnBoardingModel(
      image: AppAssets.verify,
      title: tr.docPassport,
      subTitle: tr.scanYourPassportPhoto,
    ),
    OnBoardingModel(
      image: AppAssets.verifyCrntSession,
      title: tr.docDrivingLicense,
      subTitle: tr.scanYourDrivingLicense,
    ),
    OnBoardingModel(
      image: AppAssets.dontVerify,
      title: tr.docNationalId,
      subTitle: tr.scanYourNationalId,
    ),
  ];
  int selectedTab = 2;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            46.height,
            Transform.translate(
              offset: Offset(ResSize.w * -10, 0),
              child: IconButton(
                tooltip: tr.back,
                onPressed: () {
                  popOwned(context);
                },
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColor.title,
                  size: ResSize.h * 22,
                ),
              ),
            ),
            16.height,
            TextWidget(
              text: tr.selectDocumentTypeToScan,
              color: AppColor.title,
              fontSize: 24,
              fontWeight: fwSemiBold,
            ),
            16.height,
            TextWidget(
              text: tr.weNeedToDetermineDocument,
              color: AppColor.subtitle,
              fontSize: 16,
              fontWeight: fwMedium,
            ),
            24.height,
            ...List.generate(items.length, (index) {
              return Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : ResSize.h * 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedTab = index;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResSize.w * 12,
                      vertical: ResSize.h * 13,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: selectedTab == index
                          // ignore: deprecated_member_use
                          ? Color(0xff215277).withValues(alpha: 0.10)
                          : Colors.transparent,
                      border: selectedTab == index
                          ? Border.all(color: Colors.transparent, width: 0)
                          : Border.all(color: Color(0xffD5D5D5), width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: ResSize.h * 6),
                          child: Container(
                            height: ResSize.h * 18,
                            width: ResSize.w * 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedTab == index
                                    ? AppColor.primary
                                    : AppColor.border,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Container(
                                height: ResSize.h * 18,
                                width: ResSize.w * 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selectedTab == index
                                      ? AppColor.primary
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                        12.width,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextWidget(
                                text: items[index].title,
                                fontSize: 16,
                                fontWeight: fwMedium,
                                color: AppColor.title,
                              ),
                              4.width,
                              TextWidget(
                                text: items[index].subTitle,
                                fontSize: 13,
                                fontWeight: fwMedium,
                                color: AppColor.subtitle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenHorizPadding,
          vertical: ResSize.h * 20,
        ),
        child: CustomButton(
          centerContent: tr.navContinue,
          onPressed: () {
            Navigator.push(context, BottomToTopTransition(TakeIdPhoto()));
          },
        ),
      ),
    );
  }
}
