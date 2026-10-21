import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/widgets/color_picker.dart';
import 'package:movera/widgets/dropdown.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/custom_textfield.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:movera/widgets/sizedbox_extention.dart';

class AdditionDetailAddVehicle extends StatefulWidget {
  final Widget Function(int, int) circleProgress;
  const AdditionDetailAddVehicle({super.key, required this.circleProgress});

  @override
  State<AdditionDetailAddVehicle> createState() =>
      _AdditionDetailAddVehicleState();
}

class _AdditionDetailAddVehicleState extends State<AdditionDetailAddVehicle> {
  // Empty: the examples are hints only, so nobody keeps them as their
  // vehicle (driver-u99).
  final TextEditingController _makeController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _vehicleTypePrimaryController =
      TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  /// The ride categories of the contract, by their driver names.
  final List<String> vehicleTypes = [
    for (final id in CategoryCatalog.seed) CategoryCatalog.labelOf(id),
  ];

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _vehicleTypePrimaryController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenHorizPadding),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWidget(
                      text: tr.authAddVehicle,
                      color: AppColor.title,
                      fontSize: 22,
                      fontWeight: fwExtraBold,
                    ),
                    9.height,
                    TextWidget(
                      text: tr.authAddVehicleDetails,
                      color: AppColor.subtitle,
                      fontSize: 14,
                      fontWeight: fwMedium,
                    ),
                  ],
                ),
              ),
              widget.circleProgress(0, 4),
            ],
          ),
          28.height,
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(tr.vehicleMake),
                  8.height,
                  customTextfield(
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fillColor: Color(0xffF6F8FA),
                    controller: _makeController,
                    hint: 'Toyota',
                    suffixWidget: Padding(
                      padding: EdgeInsets.all(12),
                      child: Transform.scale(
                        scale: 0.7,
                        child: Image.asset(
                          AppAssets.vehicle,
                          height: ResSize.h * 18,
                        ),
                      ),
                    ),
                  ),
                  16.height,
                  _buildLabel(tr.vehicleModel),
                  8.height,
                  customTextfield(
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fillColor: Color(0xffF6F8FA),
                    controller: _modelController,
                    hint: 'Mark X',
                    suffixWidget: Padding(
                      padding: EdgeInsets.all(12),
                      child: Transform.scale(
                        scale: 0.7,
                        child: Image.asset(
                          AppAssets.vehicle,
                          height: ResSize.h * 18,
                        ),
                      ),
                    ),
                  ),
                  16.height,
                  _buildLabel(tr.vehicleYear),
                  8.height,
                  customTextfield(
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fillColor: Color(0xffF6F8FA),
                    controller: _yearController,
                    hint: tr.enterModelYear,
                    keyboardType: TextInputType.number,
                    suffixWidget: Padding(
                      padding: EdgeInsets.all(12),
                      child: Transform.scale(
                        scale: 0.8,
                        child: Image.asset(
                          AppAssets.model,
                          height: ResSize.h * 22,
                        ),
                      ),
                    ),
                  ),
                  16.height,
                  _buildLabel(tr.licensePlateNumber),
                  8.height,
                  customTextfield(
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fillColor: Color(0xffF6F8FA),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.characters,
                    controller: _plateController,
                    hint: 'AQS - 140',
                  ),
                  16.height,
                  _buildLabel(tr.vehicleType),
                  8.height,
                  AppDropdownField(
                    controller: _vehicleTypePrimaryController,
                    hint: tr.selectEllipsis,
                    items: vehicleTypes,
                  ),
                  16.height,
                  _buildLabel(tr.vehicleColor),
                  8.height,
                  customTextfield(
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                    fillColor: Color(0xffF6F8FA),
                    controller: _colorController,
                    hint: tr.selectColor,
                    readOnly: true,
                    ontap: () {
                      ColorPickerDialog.show(context, (selectedColor) {
                        _colorController.text = selectedColor;
                      });
                    },
                    suffixWidget: Padding(
                      padding: EdgeInsets.only(right: ResSize.w * 12),
                      child: Icon(
                        Icons.color_lens_outlined,
                        size: ResSize.h * 22,
                        color: AppColor.hintText,
                      ),
                    ),
                  ),
                  50.height,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return TextWidget(
      text: text,
      color: AppColor.title,
      fontSize: 16,
      fontWeight: fwMedium,
    );
  }
}

// Reusable dropdown field styled to match customTextfield
