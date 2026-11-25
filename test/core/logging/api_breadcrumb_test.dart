import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movera/core/api/api_client.dart';
import 'package:movera/core/auth/token_store.dart';
import 'package:movera/core/logging/crash_breadcrumbs.dart';

/// Contract v0.18.158 (crashCatcher.breadcrumbs, type network): a failed
/// ApiClient call leaves a network breadcrumb (fleet #679 review S3: a merge
/// once dropped these calls from api_client.dart and no test noticed).
void main() {
  test('a failed API call leaves a network breadcrumb, ids out', () async {
    final saved = CrashBreadcrumbs.instance;
    addTearDown(() => CrashBreadcrumbs.instance = saved);
    CrashBreadcrumbs.instance = CrashBreadcrumbs();
    final api = ApiClient(
      client: MockClient((request) async => http.Response('{}', 503)),
      baseUri: Uri.parse('https://api.example.test'),
      tokens: MemoryTokenStore()..save(access: 'a1', refresh: 'r1'),
    );
    await expectLater(
      api.get('/driver/trips/trp_01JB2Z3Y4X5W6V7T8S9R0QPNMK'),
      throwsA(anything),
    );
    final lines = CrashBreadcrumbs.instance.items.map(
      (c) => '${c.type} ${c.message}',
    );
    expect(lines, contains('network GET /driver/trips/:id 503'));
  });
}
