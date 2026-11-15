/// Movera's support contact, shown under "Need help?" before sign-in
/// (owner 2026-10-29: "Add help and add email and phone and details for
/// company, we add missing info later"). BQ-V14: the admin's Content ›
/// Legal company details are shown; the built-in values below are only the
/// fallback. While all are empty the box says "Contact details coming soon".
class SupportDetails {
  const SupportDetails({this.email = '', this.phone = '', this.company = ''});

  /// Support e-mail, e.g. "support@example.com".
  final String email;

  /// Support phone in international form, e.g. "+46 8 123 45 67".
  final String phone;

  /// Company details as they should read: name, org. number, address.
  final String company;

  /// BQ-V14: from the admin's `LegalCompany` (Content › Legal), as the
  /// rider app does.
  factory SupportDetails.fromLegalCompany(Map<String, String> c) =>
      SupportDetails(
        email: c['supportEmail'] ?? '',
        phone: c['supportPhone'] ?? '',
        company: [
          c['companyName'],
          c['orgNumber'],
          c['address'],
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n'),
      );

  bool get isEmpty =>
      email.trim().isEmpty && phone.trim().isEmpty && company.trim().isEmpty;
}

/// The built-in fallback, used while no admin details were ever read
/// (BQ-V14: the admin's Content › Legal company details win).
const moveraSupportDetails = SupportDetails(email: '', phone: '', company: '');
