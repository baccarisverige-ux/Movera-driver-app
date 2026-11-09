import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_error_message.dart';
import 'package:movera/core/scheduled/server_reservations.dart';

/// W3: why « Starta nu mot upphämtningen » did not start the booked ride
/// (`POST /driver/reservations/{id}/start` refused): no connection, else
/// the server's general trip error. Kept out of home.dart (its size limit,
/// test/audit/home_map_sheet_split_test.dart).
String bookedStartRefusalMessage(ReservationRefusal refused) =>
    refused == ReservationRefusal.network
    ? tr.islandNoConnection
    : liveTripErrorMessage(null);
