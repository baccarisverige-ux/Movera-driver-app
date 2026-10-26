import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movera/core/dispatch/destination_mode_session.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/location/driver_start_position.dart';
import 'package:movera/core/notifications/driver_notifications.dart';
import 'package:movera/core/session/driver_runtime_scope.dart';
import 'package:movera/main.dart';
import 'package:movera/presentation/driver/home/components/island_messages.dart';
import 'package:movera/presentation/driver/home/home.dart';
import 'package:movera/presentation/driver/scheduled%20rides/scheduled_rides.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// driver-u53: the notification feed and the document-renewal store are
/// per-driver state kept in process singletons. Logout must clear them, or
/// the next driver sees the previous driver's reminders (with their rider
/// pickup addresses) and documents in review.
void main() {
  testWidgets('logout clears the previous driver notifications, documents '
      'and destinations', (tester) async {
    SharedPreferences.setMockInitialValues({});
    IslandMessages.reset();
    ScheduledRideStore.reset();
    DriverStartPosition.clearMemory();
    await (await SharedPreferences.getInstance()).setString(
      DriverStartPosition.key,
      '{"lat":59.3326,"lng":18.0649}',
    );
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MoveraApp());
    await tester.pump(const Duration(milliseconds: 120));

    final feed = DriverNotificationFeed.instance;
    final reminder = DriverNotices.scheduledReminder(
      at: feed.now,
      title: () => 'Head to your 08:15 pickup',
      body: () => 'Södermalm, Stockholm',
    );
    feed.add(reminder, popup: false);
    feed.markAllRead();
    final documents = DocumentExpiryStore.instance;
    documents.load([
      TrackedDocument(
        id: 'DRIVER-A-INSURANCE',
        title: 'Insurance letter',
        shortTitle: 'Insurance',
        expiresOn: DateTime(2027, 1, 1),
      ),
    ]);
    documents.uploadNew('DRIVER-A-INSURANCE');
    expect(documents.byId('DRIVER-A-INSURANCE')!.inReview, isTrue);
    // driver-r4-11: today's destinations are the driver's too.
    DestinationModeSession.instance.started(address: 'Solna');

    final runtime = DriverRuntimeScope.maybeOf(
      tester.element(find.byType(DriverHome)),
    )!;
    await tester.runAsync(() => runtime.logout!());
    await tester.pump(const Duration(milliseconds: 120));

    expect(feed.items.map((n) => n.id), isNot(contains(reminder.id)));
    expect(feed.isRead(reminder), isFalse);
    expect(documents.byId('DRIVER-A-INSURANCE'), isNull);
    expect(DestinationModeSession.instance.usedToday(), 0);
    expect(DestinationModeSession.instance.activeAddress, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
