import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc.dart';
import 'package:movera/presentation/driver/auth/sign%20in%20phone/sign_in_phone.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class DriverSignIn extends StatelessWidget {
  const DriverSignIn({super.key});

  /// driver-u106: no Apple or Google sign-in is connected, so the buttons
  /// say so, as phone sign-in does, instead of opening onboarding as if
  /// the driver had signed in.
  static void _socialSignInUnavailable(BuildContext context) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr.socialSignInNeedsService)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            56.height,
            TextWidget(text: tr.signIn, fontSize: 24, fontWeight: fwExtraBold),
            9.height,
            TextWidget(
              text: tr.welcomeBackRiding,
              color: AppColor.subtitle,
              fontSize: 16,
              fontWeight: fwMedium,
            ),
            50.height,
            CustomButton(
              icon: Padding(
                padding: EdgeInsets.only(right: ResSize.w * 12),
                child: Image.asset(AppAssets.mobile, height: ResSize.h * 24),
              ),
              centerContent: tr.continueWithPhone,
              onPressed: () {
                Navigator.push(
                  context,
                  BottomToTopTransition(const DriverSignInPhone()),
                );
              },
              borderColor: AppColor.border,
              borderwidth: 0.5,
              textColor: AppColor.title,
              btncolor: Colors.transparent,
              fontSize: 16,
            ),
            16.height,
            Row(
              children: [
                Expanded(
                  child: Divider(color: AppColor.border, thickness: 0.5),
                ),
                10.width,
                TextWidget(
                  text: "or",
                  color: AppColor.title,
                  fontSize: 16,
                  fontWeight: fwMedium,
                ),
                10.width,
                Expanded(
                  child: Divider(color: AppColor.border, thickness: 0.5),
                ),
              ],
            ),
            16.height,
            CustomButton(
              icon: Padding(
                padding: EdgeInsets.only(right: ResSize.w * 12),
                child: Image.asset(AppAssets.apple, height: ResSize.h * 24),
              ),
              centerContent: tr.continueWithApple,
              onPressed: () => _socialSignInUnavailable(context),
              borderColor: AppColor.border,
              borderwidth: 0.5,
              textColor: AppColor.title,
              btncolor: Colors.transparent,
              fontSize: 16,
            ),
            16.height,
            CustomButton(
              icon: Padding(
                padding: EdgeInsets.only(right: ResSize.w * 12),
                child: Image.asset(AppAssets.google, height: ResSize.h * 24),
              ),
              centerContent: tr.continueWithGoogle,
              onPressed: () => _socialSignInUnavailable(context),
              borderColor: AppColor.border,
              borderwidth: 0.5,
              textColor: AppColor.title,
              btncolor: Colors.transparent,
              fontSize: 16,
            ),
          ],
        ),
      ),
      // Grows and wraps when a longer language or large text needs it.
      bottomNavigationBar: ConstrainedBox(
        constraints: BoxConstraints(minHeight: ResSize.h * 60),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextWidget(
                    text: tr.dontHaveAccount,
                    color: AppColor.subtitle,
                    fontSize: 16,
                    fontWeight: fwMedium,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        RightToLeftTransition(DriverCreateAccount()),
                      );
                    },
                    child: TextWidget(
                      text: tr.signUp,
                      color: AppColor.primary,
                      fontSize: 16,
                      fontWeight: fwMedium,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
