/// Round 4b: a company's registration number, checked per country before
/// the details are sent. Sweden: an organisationsnummer of 10 digits
/// (`556677-8899`); France: a SIREN of 9 digits or a SIRET of 14. Spaces
/// and dashes are allowed on entry; only the digits count.
abstract final class OrgNumber {
  /// The digits of [typed], nothing else.
  static String digitsOf(String typed) => typed.replaceAll(RegExp(r'\D'), '');

  /// The digit counts [country] accepts.
  static List<int> lengthsFor(String country) => switch (country) {
    'SE' => const [10],
    'FR' => const [9, 14],
    _ => const [],
  };

  /// True when [typed] is a well-formed number for [country]. A country
  /// without a rule accepts any non-empty entry.
  static bool isValid(String typed, String country) {
    final digits = digitsOf(typed);
    final lengths = lengthsFor(country);
    if (lengths.isEmpty) return typed.trim().isNotEmpty;
    return lengths.contains(digits.length);
  }

  /// The most digits the field takes for [country] (with separators).
  static int maxLengthFor(String country) {
    final lengths = lengthsFor(country);
    return lengths.isEmpty ? 32 : lengths.last + 4;
  }

  /// The hint shown in the empty field.
  static String hintFor(String country) => switch (country) {
    'SE' => '556677-8899',
    'FR' => '123 456 789',
    _ => '',
  };
}
