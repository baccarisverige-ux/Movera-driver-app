import 'package:flutter/widgets.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/onboarding/driver_reminders.dart';
import 'package:movera/presentation/driver/account/contact_change_screen.dart';
import 'package:movera/presentation/driver/account/join_fleet_screen.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/account/start_company_screen.dart';
import 'package:movera/presentation/driver/documents/info_session_screen.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/presentation/driver/vehicles/live_vehicles_screen.dart';

/// The page a tap on a Home reminder line (or one of its buttons) opens
/// (`ReminderFix.target`): the upload guide, "How to book", My fleet, the
/// car list or (contract v0.18.76, G30) the e-mail check. Accept / Decline
/// of an invitation are answered on Home itself; here they open My fleet.
Widget reminderFixPage(
  DriverAccountSession session,
  DriverReminder reminder,
  ReminderFix fix,
) {
  final me = session.account;
  return switch (fix.target) {
    ReminderFixTarget.document => UploadGuideScreen(
      account: session,
      type: fix.documentType ?? reminder.documentType ?? '',
      ownerId: fix.vehicleId ?? me?.driverId ?? '',
      isCar: fix.vehicleId != null,
      country: me?.country ?? DriverAccountRules.current.country,
      status: reminder.status,
      expiresAt: reminder.expiresAt,
    ),
    ReminderFixTarget.infoSession => InfoSessionScreen(
      status: reminder.status ?? 'waiting_for_movera',
    ),
    ReminderFixTarget.fleetVehicles => MyFleetScreen(account: session),
    ReminderFixTarget.pickVehicle => LiveVehiclesScreen(account: session),
    // Contract v0.18.3 (R4): the no_fleet line's two buttons.
    ReminderFixTarget.joinFleet => JoinFleetScreen(account: session),
    ReminderFixTarget.startCompany => StartCompanyScreen(account: session),
    ReminderFixTarget.acceptInvitation ||
    ReminderFixTarget.declineInvitation => MyFleetScreen(account: session),
    // Contract v0.18.76 (G30, owner Q3): the check of his own address,
    // filled in; the normal change when there is none (or it is verified
    // by now and the line was stale).
    ReminderFixTarget.verifyEmail => ContactChangeScreen(
      account: session,
      kind: ContactKind.email,
      verifyCurrent: me?.emailVerified == true ? null : me?.email,
    ),
  };
}
