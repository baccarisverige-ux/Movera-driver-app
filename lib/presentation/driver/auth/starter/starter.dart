import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/session/demo_features.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc.dart';
import 'package:movera/presentation/driver/auth/sign%20in/sign_in.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class DriverStarter extends StatelessWidget {
  const DriverStarter({super.key});

  @override
  Widget build(BuildContext context) {
    // Scrolls on short screens and large text instead of overflowing; on a
    // tall screen the art stays centred above the buttons (UI-11).
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  100.height,
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          AppAssets.getStartedDriver,
                          height: ResSize.h * 200,
                        ),
                        38.height,
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenHorizPadding,
                          ),
                          child: TextWidget(
                            textAlign: TextAlign.center,
                            text: tr.demoModeNoAccount,
                            color: AppColor.title,
                            fontSize: 34,
                            fontWeight: fwExtraBold,
                          ),
                        ),
                        8.height,
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenHorizPadding,
                          ),
                          child: TextWidget(
                            textAlign: TextAlign.center,
                            text: tr.starterTagline,
                            color: AppColor.subtitle,
                            fontSize: 16,
                            fontWeight: fwMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
                    child: Column(
                      children: [
                        CustomButton(
                          centerContent: legacyAuthEnabled
                              ? tr.legacySignInPreview
                              : tr.signInUnavailableDemo,
                          onPressed: legacyAuthEnabled
                              ? () {
                                  Navigator.pushReplacement(
                                    context,
                                    BottomToTopTransition(const DriverSignIn()),
                                  );
                                }
                              : null,
                        ),
                        8.height,
                        CustomButton(
                          centerContent: legacyAuthEnabled
                              ? tr.legacyRegistrationPreview
                              : tr.registrationUnavailableDemo,
                          onPressed: legacyAuthEnabled
                              ? () {
                                  Navigator.push(
                                    context,
                                    BottomToTopTransition(
                                      const DriverCreateAccount(),
                                    ),
                                  );
                                }
                              : null,
                          btncolor: Colors.transparent,
                          borderColor: AppColor.primary,
                          borderwidth: 0.5,
                          textColor: AppColor.primary,
                        ),
                        if (DriverRuntimeScope.maybeOf(context) case final runtime?)
                          TextButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => runtime.homeBuilder(),
                              ),
                            ),
                            child: Text(tr.returnToDemo),
                          ),
                        20.height,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
