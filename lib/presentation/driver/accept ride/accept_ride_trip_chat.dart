part of 'accept_ride.dart';

// Rule 25 tidy-up (owner Q84, 2026-11-10, before G9 part 2): the trip
// screen's chat and call handling, moved word for word out of
// accept_ride_panel.dart and accept_ride_trip.dart (no behaviour change).

extension _AcceptRideTripChat on _AcceptRideState {
  /// Chat with the rider; a live build counts their unread messages on it.
  Widget _chatButton() {
    final chat = LiveDriverServices.instance?.chat;
    TripRoundButton button(String tooltip) => TripRoundButton(
      key: const ValueKey<String>('active-ride-message-rider'),
      tooltip: tooltip,
      onTap: _messageRider,
      asset: AppAssets.solarChatRoundDots,
    );
    if (chat == null) {
      return button(tr.messageRider);
    }
    return ListenableBuilder(
      listenable: chat.thread(widget.tripId),
      builder: (_, __) {
        final unread = chat.unreadOf(widget.tripId);
        return Badge.count(
          key: const ValueKey<String>('active-ride-chat-unread'),
          count: unread,
          isLabelVisible: unread > 0,
          backgroundColor: const Color(0xFFE0474C),
          child: button(
            unread == 0
                ? tr.messageRider
                : chat.thread(widget.tripId).unreadFromSupport > 0
                ? tr.chatNewMessagesAny(unread)
                : tr.chatNewMessages(unread),
          ),
        );
      },
    );
  }

  /// Contract v0.13.0 §22: a masked call, never the rider's number.
  void _callRider() {
    unawaited(
      callRider(
        context,
        tripId: widget.tripId,
        snackBar: (text) => SnackBar(
          content: Text(text),
          backgroundColor: _AcceptRideState._ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  void _messageRider() {
    pushSingle(
      context,
      BottomToTopTransition(
        chatScreen(riderDisplayName: _riderName, tripId: widget.tripId),
      ),
    );
  }

  /// The rider's "I'm on my way" signal (G9-2.14 builds on this).
  void _showRiderOnTheWay(DriverRealtimeEvent event) {
    if (_rideLifecycle.terminal) {
      return;
    }
    _rebuild(() => _riderOnTheWay = true);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          // The rider app sends its own English words ("I'm on the
          // way"); they read in the driver's language.
          event.message?.trim().isNotEmpty == true &&
                  event.message!.trim() != riderOnTheWayMessage
              ? event.message!
              : tr.riderNameIsOnWay(_riderName),
        ),
        backgroundColor: _AcceptRideState._ink,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
