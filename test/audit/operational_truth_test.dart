import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('static operational screens are clearly preview data', () {
    final earning = File(
      'lib/presentation/driver/earning stats/earning_stats.dart',
    ).readAsStringSync();
    final driving = File(
      'lib/presentation/driver/driving logs/driving_logs.dart',
    ).readAsStringSync();
    final promotions = File(
      'lib/presentation/driver/promotions/promotions.dart',
    ).readAsStringSync();
    final airport = File(
      'lib/presentation/driver/my queue position/components/in_airport_queue.dart',
    ).readAsStringSync();
    final analytics = File(
      'lib/presentation/driver/analytics/analytics.dart',
    ).readAsStringSync();

    expect(earning.contains(r'$12.00'), isFalse);
    expect(earning.contains('Skypulse solution pvt'), isFalse);
    expect(earning.contains('Pakistan'), isFalse);
    expect(driving.contains('after 4.5 hours of driving'), isFalse);
    expect(promotions.contains("_tabChip('Live', 0)"), isFalse);
    // The words are in the app's texts (lib/l10n), English as the source.
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(promotions.contains("_tabChip(tr.preview, 0)"), isTrue);
    expect(english['preview'], 'Preview');
    expect(airport.contains('tr.queueAirportPreview'), isTrue);
    expect(english['queueAirportPreview'], 'Airport queue preview');
    expect(analytics.contains('tr.anaPreview'), isTrue);
    expect(english['anaPreview'], 'Analytics preview');
  });
}
