import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/navigation/coalescing_map_route_refresh.dart';

void main() {
  test(
    'rapid GPS fixes run one fetch and one latest-position follow-up',
    () async {
      final queue = CoalescingMapRouteRefresh();
      final firstResponse = Completer<void>();
      var networkRequests = 0;
      Future<void> refresh() async {
        networkRequests++;
        if (networkRequests == 1) await firstResponse.future;
      }

      final first = queue.request(refresh);
      expect(queue.isRunning, isTrue);
      for (var i = 0; i < 25; i++) {
        await queue.request(refresh);
      }
      expect(
        networkRequests,
        1,
        reason: 'Twenty-five GPS fixes must not launch duplicate requests',
      );

      firstResponse.complete();
      await first;
      expect(
        networkRequests,
        2,
        reason: 'The latest GPS fix must still receive a route refresh',
      );
      expect(queue.isRunning, isFalse);
    },
  );

  test(
    'dismissal drops queued GPS routing before another request starts',
    () async {
      final queue = CoalescingMapRouteRefresh();
      final outstanding = Completer<void>();
      var runs = 0;
      Future<void> refresh() async {
        runs++;
        if (runs == 1) await outstanding.future;
      }

      final current = queue.request(refresh);
      await queue.request(refresh);
      queue.cancelPending();
      outstanding.complete();
      await current;
      expect(runs, 1);
      expect(queue.isRunning, isFalse);

      await queue.request(refresh);
      expect(runs, 2, reason: 'A later destination can start normally');
    },
  );

  test(
    'a failed fetch does not leave the route lane permanently occupied',
    () async {
      final queue = CoalescingMapRouteRefresh();
      await expectLater(
        queue.request(() async {
          throw StateError('route unavailable');
        }),
        throwsStateError,
      );
      expect(queue.isRunning, isFalse);
      var recovered = false;
      await queue.request(() async {
        recovered = true;
      });
      expect(recovered, isTrue);
    },
  );
}
