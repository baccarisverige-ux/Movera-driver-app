import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/account/my_fleet_screen.dart';
import 'package:movera/presentation/driver/documents/live_documents_screen.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// Round 4b: the server's notifications (`GET /notifications`, newest
/// first): a fleet invitation, an answer to one, later more. A tap marks
/// the row read (`POST /notifications/{id}/read`); a `fleet_invitation`
/// opens My fleet, where the invitations are answered.
class ServerNotificationsScreen extends StatefulWidget {
  const ServerNotificationsScreen({super.key, required this.account});

  final DriverAccountSession account;

  @override
  State<ServerNotificationsScreen> createState() =>
      _ServerNotificationsScreenState();
}

class _ServerNotificationsScreenState extends State<ServerNotificationsScreen>
    with WidgetsBindingObserver {
  List<ServerNotification> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.account.repository.notifications();
      if (!mounted) return;
      setState(() => _items = items);
      widget.account.unreadNotifications.value = items
          .where((n) => !n.read)
          .length;
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _error = accountErrorMessage(error, fallback: tr.notifCouldNotLoad),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(ServerNotification notice) async {
    if (!notice.read) {
      setState(() {
        _items = [
          for (final item in _items)
            item.notificationId == notice.notificationId ? item.asRead() : item,
        ];
      });
      widget.account.unreadNotifications.value = _items
          .where((n) => !n.read)
          .length;
      try {
        await widget.account.repository.markNotificationRead(
          notice.notificationId,
        );
      } catch (_) {
        // Read again next time; the row already shows as read.
      }
    }
    if (!mounted) return;
    if (notice.opensFleet) {
      await pushSingle(
        context,
        RightToLeftTransition(MyFleetScreen(account: widget.account)),
      );
      if (mounted) await _load();
    } else if (notice.kind == 'document_rejected' &&
        notice.documentLink != null) {
      // R6: a rejected document opens its upload guide (a new one).
      final link = notice.documentLink!;
      final me = widget.account.account;
      await pushSingle(
        context,
        RightToLeftTransition(
          UploadGuideScreen(
            account: widget.account,
            type: link.type,
            ownerId: link.vehicleId ?? me?.driverId ?? '',
            isCar: link.vehicleId != null,
            country: me?.country ?? DriverAccountRules.current.country,
            status: 'rejected',
          ),
        ),
      );
      if (mounted) await _load();
    } else if (notice.opensDocuments) {
      await pushSingle(
        context,
        RightToLeftTransition(LiveDocumentsScreen(account: widget.account)),
      );
      if (mounted) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.notifications,
        onBack: () => maybePopOwned(context),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty && _error == null) {
      return const Center(
        child: CircularProgressIndicator(color: AccountStyle.ink),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        color: AccountStyle.ink,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: AuthColors.muted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? tr.notifNone,
              key: const ValueKey('notifications-empty'),
              textAlign: TextAlign.center,
              style: AccountStyle.body(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AccountButton(label: tr.retry, outlined: true, onPressed: _load),
            ],
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AccountStyle.ink,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        itemCount: _items.length + (_error == null ? 0 : 1),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AccountStyle.line),
        itemBuilder: (context, i) {
          if (_error != null && i == 0) return AccountErrorLine(_error!);
          final notice = _items[_error == null ? i : i - 1];
          return _NotificationRow(notice: notice, onTap: () => _open(notice));
        },
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notice, required this.onTap});

  final ServerNotification notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final at = notice.at.toLocal();
    final when = '${DriverDates.weekdayDayMonth(at)} · ${DriverDates.time(at)}';
    return Semantics(
      button: true,
      label: '${notice.title}. ${notice.body}. $when',
      hint: notice.opensFleet
          ? tr.myFleet
          : notice.opensDocuments
          ? tr.documents
          : null,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('notification-${notice.notificationId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: notice.read
                      ? AccountStyle.field
                      : const Color(0xFFE6F2EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notice.opensFleet
                      ? Icons.groups_outlined
                      : notice.opensDocuments
                      ? Icons.description_outlined
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: notice.read ? AuthColors.muted : AuthColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            style: AuthText.urbanist(
                              size: 15.5,
                              weight: notice.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notice.read)
                          Container(
                            key: ValueKey(
                              'notification-unread-${notice.notificationId}',
                            ),
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              color: AuthColors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(notice.body, style: AccountStyle.body()),
                    const SizedBox(height: 4),
                    Text(
                      when,
                      style: AuthText.urbanist(
                        size: 12,
                        color: AuthColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (notice.opensFleet || notice.opensDocuments)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AuthColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
