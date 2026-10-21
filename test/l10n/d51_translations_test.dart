import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Wave 5 D5.1 (parts a and b): texts that stayed in English, or in the
/// language a trip opened in, now follow the driver's language.
void speak(String code) => DriverAppTexts.language = code;

void main() {
  test('driver-33: French plurals take the singular for 0 and 1', () {
    speak('fr');
    expect(tr.tripsCount(0), '0 course');
    expect(tr.tripsCount(1), '1 course');
    expect(tr.tripsCount(2), '2 courses');
    expect(tr.stopsCount(0), '0 arrêt');
    expect(tr.riderBags(0), 'Le passager a 0 bagage');
    expect(tr.inDaysCount(0), 'dans 0 jour');
    expect(tr.schedRidesHidden(0), '0 course masquée');
    expect(tr.ratingAndRides('4,9', 0), '4,9 ★ · 0 course');
    speak('sv');
    expect(tr.tripsCount(0), '0 resor');
    expect(tr.tripsCount(1), '1 resa');
  });
}
