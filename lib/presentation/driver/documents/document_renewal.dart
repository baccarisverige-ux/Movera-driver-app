import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/documents/document_expiry.dart';
import 'package:movera/core/notifications/driver_notifications.dart';

// Documents that run out (Q26): the warning card, "Upload new" and the
// sheet shown when an expired document keeps the driver offline.

const Color _ink = Color(0xFF111614);
const Color _muted = Color(0xFF6F7A80);
const Color _amber = Color(0xFF9B6B24);
const Color _red = Color(0xFFB3261E);

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "22 Oct"
String documentDateLabel(DateTime day) => '${day.day} ${_months[day.month - 1]}';

Widget _solar(String asset, Color color, double size) => SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

/// What the driver reads about [document] now.
({String text, Color color}) documentStatus(TrackedDocument document, DateTime now) {
  if (document.inReview) {
    return (text: 'New document in review', color: _amber);
  }
  final days = document.daysLeft(now);
  if (days <= 0) {
    return (text: 'Expired · You can’t go online', color: _red);
  }
  return (
    text: 'Expires ${expiresInLabel(days)} · ${documentDateLabel(document.expiresOn)}',
    color: _amber,
  );
}

/// The driver sends a new [document]; Movera checks it before it counts.
Future<void> showDocumentUploadSheet(
  BuildContext context,
  TrackedDocument document, {
  DocumentExpiryStore? store,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        key: const ValueKey<String>('document-upload-sheet'),
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        // Scrolls when large text makes it taller than the sheet.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New ${document.title.toLowerCase()}',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Take a clear photo of the whole document. Movera checks it '
                'before it counts.',
                style: TextStyle(color: _muted, fontSize: 14, height: 1.35),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  key: const ValueKey<String>('document-upload-send'),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  icon: _solar(AppAssets.solarUploadMinimalistic, Colors.white, 20),
                  label: const Text(
                    'Send new document',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Demo: no file leaves the phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (sent != true || !context.mounted) { return; }
  (store ?? DocumentExpiryStore.instance).uploadNew(document.id);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(
      content: Text('Sent for review'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Demo of admin's approval. In the real app admin approves in
/// Onboarding and the driver gets a notification.
void approveDocumentDemo(TrackedDocument document, {DocumentExpiryStore? store}) {
  final documents = store ?? DocumentExpiryStore.instance;
  documents.approve(document.id);
  final feed = DriverNotificationFeed.instance;
  feed.add(DriverNotices.documentApproved(feed.now, title: document.title));
}

/// Going online was blocked by an expired [document]: what to do next.
Future<void> showDocumentBlockedSheet(
  BuildContext context,
  TrackedDocument document, {
  DocumentExpiryStore? store,
}) {
  final documents = store ?? DocumentExpiryStore.instance;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ValueListenableBuilder<int>(
        valueListenable: documents.changes,
        builder: (context, _, _) {
          final current = documents.byId(document.id) ?? document;
          final cleared = !current.expiredAt(documents.now);
          return Padding(
            key: const ValueKey<String>('document-blocked-sheet'),
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _solar(
                      cleared ? AppAssets.solarCheckCircle : AppAssets.solarDocumentText,
                      cleared ? const Color(0xFF1C6B45) : _red,
                      24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cleared
                            ? 'Document approved'
                            : '${current.title} expired',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  cleared
                      ? 'You can go online now.'
                      : current.inReview
                          ? 'Your new document is in review. You can go online '
                              'when Movera approves it.'
                          : 'Upload a new one. You can go online when Movera '
                              'approves it.',
                  style: const TextStyle(color: _muted, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 18),
                if (cleared)
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: FilledButton.styleFrom(backgroundColor: _ink),
                      child: const Text('Done'),
                    ),
                  )
                else if (current.inReview)
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      key: const ValueKey<String>('document-blocked-approve'),
                      onPressed: () => approveDocumentDemo(current, store: documents),
                      child: const Text('Approve (demo)'),
                    ),
                  )
                else
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      key: const ValueKey<String>('document-blocked-upload'),
                      onPressed: () => showDocumentUploadSheet(
                        sheetContext,
                        current,
                        store: documents,
                      ),
                      style: FilledButton.styleFrom(backgroundColor: _ink),
                      child: const Text('Upload new'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

/// Documents that run out soon or ran out, at the top of Documents.
class DocumentExpiryList extends StatelessWidget {
  const DocumentExpiryList({super.key, this.store});

  final DocumentExpiryStore? store;

  @override
  Widget build(BuildContext context) {
    final documents = store ?? DocumentExpiryStore.instance;
    return ValueListenableBuilder<int>(
      valueListenable: documents.changes,
      builder: (context, _, _) {
        final now = documents.now;
        final due = documents.needingNew;
        if (due.isEmpty) { return const SizedBox.shrink(); }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            children: [
              for (final document in due)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ExpiryCard(
                    document: document,
                    now: now,
                    store: documents,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpiryCard extends StatelessWidget {
  const _ExpiryCard({
    required this.document,
    required this.now,
    required this.store,
  });

  final TrackedDocument document;
  final DateTime now;
  final DocumentExpiryStore store;

  @override
  Widget build(BuildContext context) {
    final status = documentStatus(document, now);
    final expired = document.expiredAt(now);
    return Container(
      key: ValueKey<String>('document-expiry-${document.id}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: expired ? const Color(0xFFFFF4F2) : const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expired ? const Color(0xFFF2C6C0) : const Color(0xFFF0DDB8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _solar(AppAssets.solarDocumentText, status.color, 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.text,
                      style: TextStyle(
                        color: status.color,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: document.inReview
                ? TextButton(
                    key: ValueKey<String>('document-approve-${document.id}'),
                    onPressed: () => approveDocumentDemo(document, store: store),
                    child: const Text('Approve (demo)'),
                  )
                : OutlinedButton.icon(
                    key: ValueKey<String>('document-upload-${document.id}'),
                    onPressed: () => showDocumentUploadSheet(
                      context,
                      document,
                      store: store,
                    ),
                    icon: _solar(AppAssets.solarUploadMinimalistic, _ink, 18),
                    label: const Text('Upload new'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: Color(0xFFD5D9DB)),
                      backgroundColor: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
