import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/navigation/map_preview_generation.dart';

void main() {
  test(
    'older offer route cannot change zoom or markers after newer selection',
    () async {
      final requests = MapPreviewGeneration();
      final offerA = Completer<String>();
      final offerB = Completer<String>();
      String? displayedRoute;
      final displayedPreviews = <String>[];

      Future<void> resolve(Completer<String> networkResponse) async {
        final owner = requests.begin();
        final route = await networkResponse.future;
        if (!requests.owns(owner)) return;
        displayedRoute = route;
        displayedPreviews.add(route);
      }

      final first = resolve(offerA);
      final second = resolve(offerB);
      offerB.complete('B / pickup / dropoff');
      await second;
      offerA.complete('A / pickup / dropoff');
      await first;

      expect(displayedRoute, 'B / pickup / dropoff');
      expect(displayedPreviews, ['B / pickup / dropoff']);
    },
  );

  test(
    'newer GPS route keeps priority over late success and failure',
    () async {
      final routeRequests = MapPreviewGeneration();
      String? currentRoad;

      Future<void> resolve(Completer<String> response) async {
        final generation = routeRequests.begin();
        try {
          final road = await response.future;
          if (routeRequests.owns(generation)) currentRoad = road;
        } catch (_) {
          if (routeRequests.owns(generation)) currentRoad = null;
        }
      }

      final slowOldFix = Completer<String>();
      final fastNewFix = Completer<String>();
      final oldPending = resolve(slowOldFix);
      final newPending = resolve(fastNewFix);
      fastNewFix.complete('new GPS road');
      await newPending;
      slowOldFix.complete('obsolete GPS road');
      await oldPending;
      expect(currentRoad, 'new GPS road');

      final oldFailure = Completer<String>();
      final newSuccess = Completer<String>();
      final failurePending = resolve(oldFailure);
      final successPending = resolve(newSuccess);
      newSuccess.complete('newer valid route');
      await successPending;
      oldFailure.completeError(StateError('old routing attempt failed'));
      await failurePending;
      expect(currentRoad, 'newer valid route');

      final pendingAfterExit = Completer<String>();
      final exitPending = resolve(pendingAfterExit);
      routeRequests.cancel();
      currentRoad = null; // Destination mode was closed.
      pendingAfterExit.complete('route from closed destination');
      await exitPending;
      expect(currentRoad, isNull);
    },
  );

  test(
    'dismiss and destination replacement revoke older camera ownership',
    () async {
      final requests = MapPreviewGeneration();
      final pendingRoute = Completer<String>();
      var cameraFits = 0;

      Future<void> resolve() async {
        final owner = requests.begin();
        await pendingRoute.future;
        if (requests.owns(owner)) cameraFits++;
      }

      final pending = resolve();
      requests.cancel();
      pendingRoute.complete('late offer');
      await pending;
      expect(cameraFits, 0);

      final destinationToken = requests.begin();
      expect(requests.owns(destinationToken), isTrue);
      final nextOffer = requests.begin();
      expect(requests.owns(destinationToken), isFalse);
      expect(requests.owns(nextOffer), isTrue);
      requests.cancel();
      expect(requests.owns(nextOffer), isFalse);
    },
  );
}
