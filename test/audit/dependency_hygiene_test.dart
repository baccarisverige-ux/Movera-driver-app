import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the unused sliding panel package is not referenced', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter_sliding_up_panel')));
    expect(pubspec, contains('sliding_up_panel:'));
    final hits = Directory('lib')
        .listSync(recursive: true)
        .followedBy(Directory('test').listSync(recursive: true))
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.endsWith('dependency_hygiene_test.dart'))
        .where(
          (file) =>
              file.readAsStringSync().contains('flutter_sliding_up_panel'),
        )
        .map((file) => file.path)
        .toList();
    expect(hits, isEmpty);
  });

  test('every direct dependency is imported somewhere in lib/', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final block = pubspec
        .split('\ndependencies:\n')[1]
        .split('\ndev_dependencies:')[0];
    final packages = RegExp(r'^  ([a-z0-9_]+):', multiLine: true)
        .allMatches(block)
        .map((m) => m.group(1)!)
        .where((name) => name != 'flutter');
    final source = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');
    final unused = packages
        .where((name) => !source.contains('package:$name/'))
        .toList();
    expect(unused, isEmpty, reason: 'Remove unused dependencies');
  });

  test('no source archives are tracked', () {
    final archives = Directory('.')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.zip'))
        .map((file) => file.path)
        .toList();
    expect(archives, isEmpty);
  });
}
