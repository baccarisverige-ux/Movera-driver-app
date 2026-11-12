import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Where a check ended.
enum CheckOutcome { pass, fail, skip }

class CheckResult {
  CheckResult(this.id, this.title, this.outcome, this.detail);

  final String id;
  final String title;
  final CheckOutcome outcome;
  final String detail;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'title': title,
    'outcome': outcome.name,
    'detail': detail,
  };
}

/// The device run's checks. Every line goes to logcat with the prefix
/// [prefix] (tool/testlab_summary.py reads it) and, at the end, to
/// `summary.json` in the run's output folder (pulled by Test Lab).
///
/// Never pass a phone number, a code, a token or a request body here.
class CheckLog {
  CheckLog({required this.binding, required this.outDir, required this.shots});

  static const prefix = 'MOVERA-TL';

  final IntegrationTestWidgetsFlutterBinding binding;

  /// MOVERA_TL_OUT from the JUnit runner (app's external files folder).
  final String? outDir;

  final bool shots;

  final List<CheckResult> results = <CheckResult>[];
  bool _surfaceConverted = false;
  int _shotNumber = 0;

  static void say(String line) {
    // ignore: avoid_print
    print('$prefix $line');
  }

  void step(String line) => say('STEP $line');

  void pass(String id, String title, String detail) =>
      _add(CheckResult(id, title, CheckOutcome.pass, detail));

  void fail(String id, String title, String detail) =>
      _add(CheckResult(id, title, CheckOutcome.fail, detail));

  void skip(String id, String title, String detail) =>
      _add(CheckResult(id, title, CheckOutcome.skip, detail));

  void _add(CheckResult result) {
    results.add(result);
    say(
      'CHECK ${result.id} ${result.outcome.name.toUpperCase()} '
      '${result.title}: ${result.detail}',
    );
  }

  List<CheckResult> get failures =>
      results.where((r) => r.outcome == CheckOutcome.fail).toList();

  /// A PNG of the screen into the output folder. Never call it on a
  /// screen that shows the phone number (sign-in, code, profile).
  Future<void> screenshot(WidgetTester tester, String name) async {
    final dir = outDir;
    if (!shots || dir == null) return;
    try {
      if (!_surfaceConverted) {
        await binding.convertFlutterSurfaceToImage();
        _surfaceConverted = true;
      }
      await tester.pump(const Duration(milliseconds: 300));
      final bytes = await binding
          .takeScreenshot(name)
          .timeout(const Duration(seconds: 15));
      _shotNumber++;
      final file = File(
        '$dir/shot-${_shotNumber.toString().padLeft(2, '0')}-$name.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      step('screenshot $name');
    } catch (error) {
      // A missing picture never fails a check.
      step('screenshot $name not taken (${error.runtimeType})');
    }
  }

  /// Writes summary.json and the request log next to the screenshots.
  Future<void> write({required List<String> requestLog}) async {
    final passed = results.where((r) => r.outcome == CheckOutcome.pass);
    final skipped = results.where((r) => r.outcome == CheckOutcome.skip);
    say(
      'SUMMARY passed=${passed.length} failed=${failures.length} '
      'skipped=${skipped.length}',
    );
    say('SUMMARY-JSON ${jsonEncode([for (final r in results) r.toJson()])}');
    final dir = outDir;
    if (dir == null) return;
    try {
      await File('$dir/summary.json').writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert([for (final r in results) r.toJson()]),
        flush: true,
      );
      await File(
        '$dir/requests.txt',
      ).writeAsString('${requestLog.join('\n')}\n', flush: true);
    } catch (error) {
      step('summary file not written (${error.runtimeType})');
    }
  }
}
