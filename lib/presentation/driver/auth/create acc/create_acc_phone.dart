import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/presentation/driver/auth/phone%20verification/phone_verify.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/custom_textfield.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/phone_picker.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class DriverCreateAccountPhone extends StatefulWidget {
  const DriverCreateAccountPhone({super.key});

  @override
  State<DriverCreateAccountPhone> createState() =>
      _DriverCreateAccountPhoneState();
}

class _DriverCreateAccountPhoneState extends State<DriverCreateAccountPhone> {
  late String selectedCountryCode;
  Country? selectedCountry; // Add this to store the selected country

  @override
  void initState() {
    super.initState();
    // The driver's market country (Sweden, +46) until they pick another.
    final market = marketPhoneCountry();
    selectedCountry = market;
    selectedCountryCode = '+${market.phoneCode}';
  }

  void updateCountryCode(String newCode, Country country) {
    setState(() {
      selectedCountryCode = newCode;
      selectedCountry = country;
    });
  }

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
              text: tr.phoneNumber,
              fontSize: 24,
              fontWeight: fwExtraBold,
            ),
            9.height,
            TextWidget(
              textAlign: TextAlign.start,
              text: tr.enterValidPhoneWeWillSend,
              color: AppColor.subtitle,
              fontSize: 16,
              fontWeight: fwMedium,
            ),
            14.height,
            customTextfield(
              contentHorizPadding: 0,
              hint: tr.phoneNumber,
              keyboardType: TextInputType.phone,
              prefixWidget: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return PhoneNumberPicker(
                        onCountryCodeSelected: updateCountryCode,
                      );
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 5,
                    top: 7,
                    bottom: 7,
                    right: 0,
                  ),
                  child: SizedBox(
                    width: ResSize.w * 75,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Display country flag instead of country code
                        if (selectedCountry != null)
                          CountryPickerUtils.getDefaultFlagImage(
                            selectedCountry!,
                          ),
                        5.width,

                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColor.hintText,
                          size: ResSize.h * 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
                    BottomToTopTransition(const DriverPhoneVerification()),
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
