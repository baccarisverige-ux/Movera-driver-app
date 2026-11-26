import 'package:flutter/widgets.dart';
import 'package:movera/core/history/trip_history.dart';
import 'package:movera/presentation/common/chat/chat.dart' deferred as chat;
import 'package:movera/presentation/driver/my%20wallet/wallet.dart'
    deferred as wallet;
import 'package:movera/presentation/driver/ride%20history/ride_history.dart'
    deferred as ride_history;
import 'package:movera/presentation/driver/ride%20history/history%20detail/history_detail.dart'
    deferred as history_detail;
import 'package:movera/presentation/driver/profile/profile.dart'
    deferred as profile;
import 'package:movera/presentation/driver/documents/documents.dart'
    deferred as documents;
import 'package:movera/presentation/driver/driving%20logs/driving_logs.dart'
    deferred as driving_logs;
import 'package:movera/presentation/driver/promotions/promotions.dart'
    deferred as promotions;
import 'package:movera/presentation/driver/settings/settings.dart'
    deferred as settings;
import 'package:movera/presentation/driver/support/support_inbox.dart'
    deferred as support;
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/auth/otp_challenge.dart';
import 'package:movera/core/account/driver_account_session.dart';
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

/// [loadHistory]: the same seam as `DriverRideHistory.loadHistory` (tests).
Widget rideHistoryScreen({
  Future<List<TripHistoryRecord>> Function()? loadHistory,
}) => DeferredScreen(
  load: ride_history.loadLibrary,
  builder: (_) => ride_history.DriverRideHistory(loadHistory: loadHistory),
);

/// One trip of Ride history (a refund-taken notification opens it). Web
/// headroom (owner Q51, 2026-11-15): it loads on first open, like Ride
/// history.
Widget rideHistoryDetailScreen({required TripHistoryRecord record}) =>
    DeferredScreen(
      load: history_detail.loadLibrary,
      builder: (_) => history_detail.DriverRideHistoryDetail(record: record),
    );

/// Profile (side menu) and what only it opens (Analytics, Earning stats,
/// Vehicles, Add vehicle, My bank) load on first open too (web headroom,
/// owner Q51, 2026-11-15).
Widget driverProfileScreen() => DeferredScreen(
  load: profile.loadLibrary,
  builder: (_) => profile.DriverProfile(),
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

/// Loads all of them now (tests: a deferred load does not finish inside a
/// widget test's fake clock).
@visibleForTesting
Future<void> loadDeferredScreens() => Future.wait([
  wallet.loadLibrary(),
  ride_history.loadLibrary(),
  history_detail.loadLibrary(),
  profile.loadLibrary(),
  chat.loadLibrary(),
  settings.loadLibrary(),
  documents.loadLibrary(),
  driving_logs.loadLibrary(),
  promotions.loadLibrary(),
  support.loadLibrary(),
]);

/// v0.18.162 (owner 2026-11-25): "Which country do you work in?", loaded on
/// first open with the Profile part (web budget).
Widget driverCountryScreen({
  required DriverAccountSession account,
  required void Function(BuildContext context, DriverAccount saved) onDone,
  String? selected,
}) => DeferredScreen(
  load: profile.loadLibrary,
  builder: (_) => profile.DriverCountryScreen(
    account: account,
    onDone: onDone,
    selected: selected,
  ),
);

/// Contract v0.18.166 (`signupV2`, owner 2026-11-26 "Oui, tout construire"):
/// the new sign-up ("Vos informations", then the checklist), loaded with the
/// Profile part. Replaces the country step and the details form on the
/// first sign-in (both screens and their routes stay, Rule 21).
Widget driverSignupScreen({
  required DriverAccountSession account,
  required String? phone,
  required void Function(BuildContext context) onHome,
}) => DeferredScreen(
  load: profile.loadLibrary,
  builder: (_) =>
      profile.SignupEntry(account: account, phone: phone, onHome: onHome),
);

/// Bug 2026-11-25 / web budget: the sign-up details screen (step 3) loads
/// with the Profile part too, so the first download keeps room for the fixes.
Widget driverDetailsScreen({
  required DriverAccountSession account,
  required void Function(BuildContext context) onDone,
  String? phone,
  ProviderLink? prefill,
}) => DeferredScreen(
  load: profile.loadLibrary,
  builder: (_) => profile.DriverDetailsScreen(
    account: account,
    onDone: onDone,
    phone: phone,
    prefill: prefill,
  ),
);
