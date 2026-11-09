import 'package:flutter/widgets.dart';
import 'package:movera/presentation/common/chat/chat.dart' deferred as chat;
import 'package:movera/presentation/driver/my%20wallet/wallet.dart'
    deferred as wallet;
import 'package:movera/presentation/driver/ride%20history/ride_history.dart'
    deferred as ride_history;
import 'package:movera/presentation/driver/documents/documents.dart'
    deferred as documents;
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

Widget supportScreen() => DeferredScreen(
  load: support.loadLibrary,
  builder: (_) => support.SupportScreen(),
);

Widget supportInboxScreen() => DeferredScreen(
  load: support.loadLibrary,
  builder: (_) => support.SupportInboxScreen(),
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
  support.loadLibrary(),
]);
