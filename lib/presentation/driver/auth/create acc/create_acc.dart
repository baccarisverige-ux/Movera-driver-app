import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/driver/auth/create%20acc/create_acc_phone.dart';
import 'package:movera/widgets/checkbox.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/custom_textfield.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class DriverCreateAccount extends StatefulWidget {
  const DriverCreateAccount({super.key});

  @override
  State<DriverCreateAccount> createState() => _DriverCreateAccountState();
}

class _DriverCreateAccountState extends State<DriverCreateAccount> {
  String selectedCountryCode = '+92';
  Country? selectedCountry; // Add this to store the selected country

  @override
  void initState() {
    super.initState();
    // Set default country (United States)
    selectedCountry = CountryPickerUtils.getCountryByIsoCode('US');
    selectedCountryCode = '+1';
  }

  void updateCountryCode(String newCode, Country country) {
    setState(() {
      selectedCountryCode = newCode;
      selectedCountry = country;
    });
  }

  bool isAccept = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            56.height,
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
            18.height,
            TextWidget(
              text: tr.createAccount,
              fontSize: 24,
              fontWeight: fwExtraBold,
            ),
            9.height,
            TextWidget(
              textAlign: TextAlign.start,
              text: tr.enterValidPhoneForCode,
              color: AppColor.subtitle,
              fontSize: 16,
              fontWeight: fwMedium,
            ),
            14.height,
            customTextfield(
              hint: tr.fullName,
              prefixWidget: Icon(
                Icons.person_outline_rounded,
                size: ResSize.h * 25,
                color: AppColor.hintText,
              ),
            ),
            16.height,
            customTextfield(
              hint: tr.emailAddress,
              prefixWidget: Icon(
                Icons.email_outlined,
                size: ResSize.h * 25,
                color: AppColor.hintText,
              ),
            ),
            13.height,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.translate(
                  offset: Offset(ResSize.w * -10, -7),
                  child: CustomCheckBox(
                    value: isAccept,
                    semanticLabel: tr.acceptTermsAndPrivacy,
                    onPressed: () {
                      setState(() {
                        isAccept = !isAccept;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Transform.translate(
                    offset: Offset(ResSize.w * -10, 0),
                    child: RichText(
                      textAlign: TextAlign.start,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: tr.byContinuingIAgreeTo,
                            style: GoogleFonts.poppins(
                              fontSize: ResSize.setSp(14),
                              fontWeight: fwNormal,
                              color: AppColor.subtitle,
                            ),
                          ),
                          TextSpan(
                            text: tr.termsOfUse,
                            style: GoogleFonts.poppins(
                              decoration: TextDecoration.underline,
                              fontSize: ResSize.setSp(14),
                              fontWeight: fwNormal,
                              color: AppColor.title,
                            ),
                          ),
                          TextSpan(
                            text: tr.andWord,
                            style: GoogleFonts.poppins(
                              fontSize: ResSize.setSp(14),
                              fontWeight: fwNormal,
                              color: AppColor.subtitle,
                            ),
                          ),
                          TextSpan(
                            text: tr.privacyPolicy,
                            style: GoogleFonts.poppins(
                              decoration: TextDecoration.underline,
                              fontSize: ResSize.setSp(14),
                              fontWeight: fwNormal,
                              color: AppColor.title,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.symmetric(vertical: 12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomButton(
                centerContent: tr.navContinue,
                onPressed: () {
                  Navigator.push(
                    context,
                    BottomToTopTransition(const DriverCreateAccountPhone()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
