import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_btn.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/custom_textfield.dart';
import 'package:movera/widgets/phone_picker.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class DriverSignInPhone extends StatefulWidget {
  const DriverSignInPhone({super.key});

  @override
  State<DriverSignInPhone> createState() => _DriverSignInPhoneState();
}

class _DriverSignInPhoneState extends State<DriverSignInPhone> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(AppAssets.phoneSigninBg),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        50.height,
                        Row(
                          children: [
                            IconButton(tooltip: tr.back, 
                              onPressed: () {
                                popOwned(context);
                              },
                              icon: Icon(
                                Icons.arrow_back_ios_rounded,
                                color: AppColor.title,
                                size: ResSize.h * 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(
                        AppAssets.phoneSigninImg,
                        height: ResSize.h * 270,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: AppColor.white,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: screenHorizPadding,
                  vertical: ResSize.h * 25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    5.height,
                    TextWidget(
                      text: tr.signInWithPhone,
                      fontSize: 22,
                      fontWeight: fwExtraBold,
                    ),
                    6.height,
                    TextWidget(
                      textAlign: TextAlign.start,
                      text:
                          tr.phoneSignInUnavailableDemo,
                      color: AppColor.subtitle,
                      fontSize: 14,
                      fontWeight: fwMedium,
                    ),
                    24.height,
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
                    40.height,
                    CustomButton(
                      centerContent: tr.navContinue,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr.phoneSignInNeedsService)),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
