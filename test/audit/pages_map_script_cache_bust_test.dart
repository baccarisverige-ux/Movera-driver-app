import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pages build fingerprints the map zoom adapter for cache safety', () {
    final workflow = File(
      '.github/workflows/deploy-pages.yml',
    ).readAsStringSync();
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('src="driver_map_camera.js"'));
    expect(workflow, contains('name: Version map zoom/gesture adapter'));
    expect(workflow, contains('DEPLOY_SHA:'));
    expect(workflow, contains("workflow_run.head_sha"));
    expect(workflow, contains("driver_map_camera.js?v="));
    expect(
      workflow.indexOf('Version map zoom/gesture adapter'),
      lessThan(workflow.indexOf('Build Drider web')),
    );
  });
}
