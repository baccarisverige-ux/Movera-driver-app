import 'package:flutter/widgets.dart';
import 'package:movera/presentation/common/chat/chat.dart' deferred as chat;
import 'package:movera/presentation/driver/my%20wallet/wallet.dart'
    deferred as wallet;
import 'package:movera/presentation/driver/ride%20history/ride_history.dart'
    deferred as ride_history;
import 'package:movera/presentation/driver/documents/documents.dart'
    deferred as documents;
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart'
    deferred as driving_logs;
import 'package:movera/presentation/driver/promotions/promotions.dart'
    deferred as promotions;
import 'package:movera/presentation/driver/profile/profile.dart'
    deferred as profile;
import 'package:movera/presentation/driver/settings/settings.dart'
    deferred as settings;
import 'package:movera/presentation/driver/support/support_inbox.dart'
    deferred as support;
import 'package:movera/widgets/deferred_screen.dart';

/// Owner 2026-11-03 (LT-4 "load on open"): Wallet, Ride history and Chat
/// are loaded the first time they open, so the app's first download is
/// smaller. Every place that opens them goes through here; nothing else may
/// import those screens directly, or they would be back in the first
/// download (test/perf/deferred_screens_test.dart checks it).
Widget walletScreen() => DeferredScreen(
  load: wallet.loadLibrary,
  builder: (_) => wallet.WalletScreen(),
);

Widget rideHistoryScreen() => DeferredScreen(
  load: ride_history.loadLibrary,
  builder: (_) => ride_history.DriverRideHistory(),
);

Widget chatScreen({required String riderDisplayName, String? tripId}) =>
    DeferredScreen(
      load: chat.loadLibrary,
      builder: (_) =>
          chat.Chat(riderDisplayName: riderDisplayName, tripId: tripId),
    );

/// B9 "Fast app start" (owner 2026-11-04): Settings, Documents and Help
/// (support) load on first open too, the same way.
Widget settingsScreen() => DeferredScreen(
  load: settings.loadLibrary,
  builder: (_) => settings.Settings(),
);

Widget driverDocumentsScreen() => DeferredScreen(
  load: documents.loadLibrary,
  builder: (_) => documents.DriverDocuments(),
);

/// Driving log and Promotions (side menu) load on first open too, the same
/// way, so the first download stays inside the web size budget (owner Q51).
Widget drivingLogsScreen() => DeferredScreen(
  load: driving_logs.loadLibrary,
  builder: (_) => driving_logs.DrivingLogs(),
);

Widget promotionsScreen() => DeferredScreen(
  load: promotions.loadLibrary,
  builder: (_) => promotions.Promotions(),
);

/// [openTicketId]: contract v0.18.53 §75, a `support_reply` push tap opens
/// that ticket over the Support list.
Widget supportScreen({String? openTicketId}) => DeferredScreen(
  load: support.loadLibrary,
  builder: (_) => support.SupportScreen(openTicketId: openTicketId),
);

Widget supportInboxScreen() => DeferredScreen(
  load: support.loadLibrary,
  builder: (_) => support.SupportInboxScreen(),
);

/// v0.18.113 BQ-S13: Profile (side menu) loads on first open too, the
/// same way, so the call window on Trip finished fits the web size budget.
Widget profileScreen() => DeferredScreen(
  load: profile.loadLibrary,
  builder: (_) => profile.DriverProfile(),
);

/// Loads all of them now (tests: a deferred load does not finish inside a
/// widget test's fake clock).
@visibleForTesting
Future<void> loadDeferredScreens() => Future.wait([
  wallet.loadLibrary(),
  ride_history.loadLibrary(),
  chat.loadLibrary(),
  settings.loadLibrary(),
  documents.loadLibrary(),
  driving_logs.loadLibrary(),
  promotions.loadLibrary(),
  support.loadLibrary(),
  profile.loadLibrary(),
]);
