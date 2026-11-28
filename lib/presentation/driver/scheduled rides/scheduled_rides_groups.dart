part of 'scheduled_rides.dart';

/// v0.18.172 (owner 2026-11-28, favourite areas): the open list in two
/// visible groups. The server already sends the rides in his favourite areas
/// first (`DriverReservation.inPreferredArea`); the app never re-sorts, it
/// only puts a small header above the first ride of each group. With
/// favourite areas but none of the open rides in them: one line "0 bookings
/// in your favourite areas" above the others. No favourite areas chosen: no
/// header at all (the list as before).
enum _RideGroupMark { none, favourites, others, noneInFavourites }

bool _inFavourites(_ScheduledRide ride) =>
    ScheduledRideStore.serverRow(ride.id)?.inPreferredArea == true;

/// The header to show above `rides[i]` of the open list.
_RideGroupMark _groupMarkAt(
  List<_ScheduledRide> rides,
  int i, {
  required bool hasFavourites,
}) {
  if (!hasFavourites || i < 0 || i >= rides.length) return _RideGroupMark.none;
  final here = _inFavourites(rides[i]);
  if (i == 0) {
    return here ? _RideGroupMark.favourites : _RideGroupMark.noneInFavourites;
  }
  return !here && _inFavourites(rides[i - 1])
      ? _RideGroupMark.others
      : _RideGroupMark.none;
}

class _RideGroupHeader extends StatelessWidget {
  const _RideGroupHeader(this.mark);
  final _RideGroupMark mark;

  @override
  Widget build(BuildContext context) {
    final text = switch (mark) {
      _RideGroupMark.favourites => tr.schedGroupFavourites,
      _RideGroupMark.others => tr.schedGroupOthers,
      _RideGroupMark.noneInFavourites => tr.schedGroupNoneInFavourites,
      _RideGroupMark.none => '',
    };
    return Padding(
      key: ValueKey<String>('scheduled-group-${mark.name}'),
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6F7B82),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The card with its group header above it (open tab only).
Widget _withRideGroup(
  List<_ScheduledRide> rides,
  int i,
  Widget card, {
  required bool openTab,
}) {
  final mark = openTab
      ? _groupMarkAt(
          rides,
          i,
          hasFavourites: PreferredAreasStore.saved.value.isNotEmpty,
        )
      : _RideGroupMark.none;
  if (mark == _RideGroupMark.none) return card;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [_RideGroupHeader(mark), card],
  );
}
