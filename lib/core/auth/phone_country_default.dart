import 'package:flutter/widgets.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/auth/phone_country.dart';

/// The phone field's starting country: the driver's market
/// ([DriverAccountRules.country], Sweden and +46 in the demo), else the
/// device's region, else Sweden. No location prompt for it.
PhoneCountry defaultPhoneCountry({
  String? marketCountry,
  String? localeRegion,
}) => PhoneCountries.defaultFor(
  marketCountry: marketCountry ?? DriverAccountRules.current.country,
  localeRegion: localeRegion ?? _deviceRegion(),
);

/// The country of the device's locale ("SE" in sv-SE or en-SE), or null.
String? _deviceRegion() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale.countryCode;
  } catch (_) {
    return null;
  }
}
