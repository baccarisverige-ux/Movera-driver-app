import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:country_pickers/country.dart';
import 'package:country_pickers/country_pickers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';

class PhoneNumberPicker extends StatefulWidget {
  final Function(String, Country)?
  onCountryCodeSelected; // Updated to pass both code and country
  final Function(String, String)?
  onCountrySelected; // For country selection (card dialog)
  final bool
  isForPhoneCode; // true for signup (phone code), false for card (country name)
  final String? title; // Customizable title; null: "Select Country"

  const PhoneNumberPicker({
    super.key,
    this.onCountryCodeSelected, // Used for signup screen
    this.onCountrySelected, // Used for card dialog
    this.isForPhoneCode = true, // Default to phone code selection
    this.title,
  });

  @override
  State<PhoneNumberPicker> createState() => _PhoneNumberPickerState();
}

class _PhoneNumberPickerState extends State<PhoneNumberPicker> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 500,
        height: MediaQuery.of(context).size.height * 0.7,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CountryPickerDialog(
            isSearchable: true,
            searchFilter: (Country country, String searchWord) {
              return country.name.toLowerCase().contains(
                    searchWord.toLowerCase(),
                  ) ||
                  country.phoneCode.contains(searchWord);
            },
            title: Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: TextWidget(
                text: widget.title ?? tr.selectCountry,
                fontSize: 16,
                fontWeight: fwMedium,
                color: AppColor.black,
              ),
            ),
            searchInputDecoration: InputDecoration(
              constraints: BoxConstraints.tight(const Size.fromHeight(50)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColor.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColor.border, width: 1),
              ),
              labelText: tr.searchCountry,
              labelStyle: GoogleFonts.poppins(
                fontSize: ResSize.setSp(14),
                color: AppColor.hintText,
                fontWeight: fwBold,
              ),
            ),
            onValuePicked: (Country country) {
              if (widget.isForPhoneCode) {
                // For signup screen - return phone code and country
                widget.onCountryCodeSelected?.call(
                  '+${country.phoneCode}',
                  country,
                );
              } else {
                // For card dialog - return both code and name
                widget.onCountrySelected?.call(
                  '+${country.phoneCode}',
                  country.name,
                );
              }
            },
            itemBuilder: (Country country) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CountryPickerUtils.getDefaultFlagImage(country),
                  const SizedBox(width: 8.0),

                  // Show phone code only when selecting for phone code (signup)
                  if (widget.isForPhoneCode) ...[
                    TextWidget(
                      text: '+${country.phoneCode}',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColor.black,
                    ),
                    const SizedBox(width: 8.0),
                  ],

                  Expanded(
                    child: TextWidget(
                      text: country.name,
                      fontSize: 13,
                      fontWeight: fwMedium,
                      color: AppColor.black,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
