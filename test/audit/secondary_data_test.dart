import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movera/core/money/money.dart';
import 'package:movera/core/vehicle/local_vehicle_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'vehicle drafts survive reload and actual removal stays removed',
    () async {
      final first = LocalVehicleStore();
      await first.upsert({
        'id': 'test',
        'make': 'M',
        'model': 'C',
        'year': '2026',
        'plate': 'ABC123',
        'registrationPhoto': 'AQID',
      });
      final reloaded = LocalVehicleStore();
      expect(
        (await reloaded.list())
            .where((v) => v['id'] == 'test')
            .single['registrationPhoto'],
        'AQID',
      );
      await reloaded.remove('test');
      expect((await first.list()).where((v) => v['id'] == 'test'), isEmpty);
      await first.remove('demo-V418');
      expect(await LocalVehicleStore().list(), isEmpty);
    },
  );
  test(
    'legacy SEK labels migrate to exact minor units and unknown stays unknown',
    () {
      expect(Money.parseSekLabel('1 234,56 kr')!.minorUnits, 123456);
      expect(Money.parseSekLabel('1.234,56 kr')!.minorUnits, 123456);
      expect(Money.parseSekLabel('1,234.56 SEK')!.minorUnits, 123456);
      expect(Money.parseSekLabel('−12,50 kr')!.minorUnits, -1250);
      expect(Money.parseSekLabel('—'), isNull);
      expect(Money.parseSekLabel('12 USD'), isNull);
      expect(Money.parseSekLabel('12.34.56 kr'), isNull);
    },
  );
}
