import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/contracts/status_words.g.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Owner decisions of 2026-10-29, driver group 2 items 8 and 13 (Sweden
/// and France): "How to book your info session", the admin's Content
/// text and link (content slot `driver-info-session`, sv / fr / en), and
/// the session's state, "Waiting for Movera" until Movera marks it held.
class InfoSessionScreen extends StatefulWidget {
  const InfoSessionScreen({
    super.key,
    required this.status,
    this.content,
    this.openLink,
    this.refresh,
  });

  /// `contract.json#driverOnboarding.infoSession.type`.
  static const type = 'info_session';

  /// The shown state: `waiting_for_movera`, `approved` or `rejected`.
  final String status;

  /// The content store (tests hand one in).
  final DriverContentStore? content;

  /// Opens a link (tests record it).
  final Future<bool> Function(Uri uri)? openLink;

  /// Reads the admin's texts again when the page opens (live builds:
  /// `GET /driver/content`), so a text published since the app started
  /// shows.
  final Future<void> Function()? refresh;

  static final _link = RegExp(r'https://[^\s<>()]+');

  @override
  State<InfoSessionScreen> createState() => _InfoSessionScreenState();
}

class _InfoSessionScreenState extends State<InfoSessionScreen> {
  @override
  void initState() {
    super.initState();
    final refresh =
        widget.refresh ?? LiveDriverServices.instance?.content.refresh;
    if (refresh != null) unawaited(refresh());
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final openLink = widget.openLink;
    final store = widget.content ?? DriverContentStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final item = store.infoSession;
        final text = item?.textIn(tr.localeName);
        final link = text == null
            ? null
            : InfoSessionScreen._link.firstMatch(text)?.group(0);
        final statusLabel =
            statusWord(tr, 'documentStatus', status) ??
            tr.swDocumentStatusWaitingForMovera;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AccountStyle.appBar(
            context,
            tr.infoHowToBook,
            onBack: () => maybePopOwned(context),
          ),
          body: SafeArea(
            child: ListView(
              key: const ValueKey('info-session'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    statusLabel,
                    key: const ValueKey('info-session-status'),
                    color: status == 'approved'
                        ? AccountStyle.green
                        : status == 'rejected'
                        ? AccountStyle.error
                        : AccountStyle.amber,
                  ),
                ),
                const SizedBox(height: 16),
                if (status == 'approved')
                  Text(tr.infoHeld, style: AccountStyle.body())
                else ...[
                  if (item != null) ...[
                    Text(
                      item.title,
                      key: const ValueKey('info-session-title'),
                      style: AccountStyle.title(),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    text ?? tr.infoNoContent,
                    key: const ValueKey('info-session-text'),
                    style: AccountStyle.body(),
                  ),
                  if (link != null) ...[
                    const SizedBox(height: 18),
                    AccountButton(
                      key: const ValueKey('info-session-link'),
                      label: tr.infoOpenLink,
                      onPressed: () {
                        final uri = Uri.parse(link);
                        (openLink ?? _launch)(uri);
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(tr.infoRequiredBeforeOnline, style: AccountStyle.hint()),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
