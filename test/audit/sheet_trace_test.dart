import 'package:flutter_test/flutter_test.dart';
import 'package:movera/presentation/driver/sheets/sheet_trace.dart';

void main() {
  testWidgets('passive trace timers are cancelled on teardown', (tester) async {
    double position = .5;
    final trace = SheetTrace('test', () => position);
    trace.down();
    trace.up(12);
    trace.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(position, .5);
  });
}
