import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Owner 2026-11-22 (CI log): the repository variable MOVERA_PROD_API_URL was
/// saved with a trailing line break, which split the `flutter build` command
/// ("Target file ... not found"). Every workflow step whose shell receives
/// vars.MOVERA_PROD_API_URL or vars.MOVERA_LIVE_API_URL (through the step's or
/// the job's env) must strip all whitespace and control characters from it
/// before its first use. Returns the checked steps and the failing ones.
({List<String> checked, List<String> failing}) addressStripReport(
  String file,
  String yml,
) {
  const varRefs = ['vars.MOVERA_PROD_API_URL', 'vars.MOVERA_LIVE_API_URL'];
  final envEntry = RegExp(r'^\s+([A-Z_][A-Z0-9_]*):\s*(.*)$');
  int indent(String l) => l.length - l.trimLeft().length;
  final lines = yml.split('\n');
  final checked = <String>[];
  final failing = <String>[];
  var jobVars = <String>{};

  void checkStep(List<String> step, Set<String> fromJob) {
    final name =
        RegExp(r'name:\s*(.*)$').firstMatch(step.first)?.group(1) ?? '?';
    final stepVars = <String>{};
    final overridden = <String>{};
    final run = <String>[];
    for (var i = 1; i < step.length; i++) {
      final t = step[i].trim();
      if (indent(step[i]) == 8 && t == 'env:') {
        for (var j = i + 1; j < step.length && indent(step[j]) > 8; j++) {
          final m = envEntry.firstMatch(step[j]);
          if (m == null) continue;
          (varRefs.any(m.group(2)!.contains) ? stepVars : overridden).add(
            m.group(1)!,
          );
        }
      }
      if (indent(step[i]) == 8 && t.startsWith('run:')) {
        final inline = t.substring(4).trim();
        if (!inline.startsWith('|') && !inline.startsWith('>')) run.add(inline);
        for (
          var j = i + 1;
          j < step.length && (indent(step[j]) > 8 || step[j].trim().isEmpty);
          j++
        ) {
          run.add(step[j].trim());
        }
      }
    }
    final candidates = {...stepVars, ...fromJob.difference(overridden)};
    for (final v in candidates) {
      final first = run.indexWhere(
        (l) => l.contains('\$$v') || l.contains('\${$v'),
      );
      if (first < 0) continue;
      final label = '$file: $name: $v';
      checked.add(label);
      final strip =
          '$v="\$(printf \'%s\' "\$$v" | tr -d \'[:space:][:cntrl:]\')"';
      if (run[first] != strip) failing.add('$label (first use: ${run[first]})');
    }
  }

  var inJobs = false;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.trim().isEmpty) continue;
    if (indent(l) == 0) {
      inJobs = l.startsWith('jobs:');
      continue;
    }
    if (!inJobs) continue;
    if (indent(l) == 2) jobVars = <String>{};
    if (indent(l) == 4 && l.trim() == 'env:') {
      for (
        var j = i + 1;
        j < lines.length && (indent(lines[j]) > 4 || lines[j].trim().isEmpty);
        j++
      ) {
        final m = envEntry.firstMatch(lines[j]);
        if (m != null &&
            indent(lines[j]) == 6 &&
            varRefs.any(m.group(2)!.contains)) {
          jobVars.add(m.group(1)!);
        }
      }
    }
    if (indent(l) == 6 && l.trimLeft().startsWith('- ')) {
      final step = [l];
      var j = i + 1;
      for (; j < lines.length; j++) {
        final n = lines[j];
        if (n.trim().isEmpty) {
          step.add(n);
          continue;
        }
        if (indent(n) < 6 ||
            (indent(n) == 6 && n.trimLeft().startsWith('- '))) {
          break;
        }
        step.add(n);
      }
      checkStep(step, jobVars);
      i = j - 1;
    }
  }
  return (checked: checked, failing: failing);
}

void main() {
  test('every step strips the server address variables before using them', () {
    final checked = <String>[];
    final failing = <String>[];
    final files =
        Directory('.github/workflows')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final r = addressStripReport(
        f.uri.pathSegments.last,
        f.readAsStringSync(),
      );
      checked.addAll(r.checked);
      failing.addAll(r.failing);
    }
    // The parser must still see the known steps (a silent miss would pass).
    expect(
      checked,
      containsAll(<String>[
        'deploy-pages.yml: Build live Drider web: LIVE_API',
        'deploy-pages.yml: Build and add the real driver web (new real server): PROD_API',
        'deploy-pages.yml: Build and add the real driver web (new real server): LIVE_API',
        'drider-ci.yml: Build live web: LIVE_API',
        'android-test-apk.yml: Check the server choice: PROD_API',
        'android-test-apk.yml: Build APK(s): LIVE_API',
      ]),
    );
    expect(failing, isEmpty, reason: failing.join('\n'));
  });
}
