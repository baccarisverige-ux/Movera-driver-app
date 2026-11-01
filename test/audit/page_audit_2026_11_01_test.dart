import 'package:flutter_test/flutter_test.dart';
import 'package:movera/widgets/color_picker.dart';

/// Page audit 2026-11-01: car colours stored in English are shown in the
/// app language (here the test default, English) and unknown words as
/// stored.
void main() {
  test('stored car colours map to the app language', () {
    expect(localizedCarColor('Black'), 'Black');
    expect(localizedCarColor('grey'), 'Gray');
    expect(localizedCarColor('Svart'), 'Black');
    expect(localizedCarColor('Turquoise'), 'Turquoise');
    expect(localizedCarColor(''), '');
  });
}
