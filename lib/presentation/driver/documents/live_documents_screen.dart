import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/contracts/driver_onboarding_rules.dart';
import 'package:movera/core/account/driver_account_rules.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/onboarding/document_status.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/documents/info_session_screen.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';
import 'package:movera/presentation/driver/documents/upload_guide_screen.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/document_file_picker.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// Documents, live (contract v0.5.3 §14): the person's required documents
/// ("You"), the company's for a fleet account ("Company") and each car's
/// ("Car PLATE"), from the lists the server sends, named with the
/// admin's published texts (types the admin made included). A file
/// document opens its upload guide (owner item 4); the terms are approved
/// at sign-up; the information session opens "How to book" and shows
/// "Waiting for Movera" until Movera marks it held (item 8).
class LiveDocumentsScreen extends StatefulWidget {
  const LiveDocumentsScreen({
    super.key,
    required this.account,
    this.filePicker = const DeviceDocumentFilePicker(),
  });

  final DriverAccountSession account;
  final DocumentFilePicker filePicker;

  @override
  State<LiveDocumentsScreen> createState() => _LiveDocumentsScreenState();
}

class _LiveDocumentsScreenState extends State<LiveDocumentsScreen>
    with WidgetsBindingObserver {
  List<AccountDocument> _docs = const [];
  List<FleetVehicle> _cars = const [];
  bool _loading = true;
  String? _error;

  /// R6 (owner 2026-10-30, "Update + notice"): an admin's decision shows
  /// without leaving the screen: read again every 60 s, when the app
  /// returns and when a page opened from here closes.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.account.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(
      onboardingRefreshEvery,
      (_) => _refreshQuietly(),
    );
    _load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.account.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshQuietly();
  }

  /// The documents and the reminders again, without the spinner; a
  /// failed read keeps what the screen shows.
  Future<void> _refreshQuietly() async {
    if (!mounted || _loading) return;
    unawaited(refreshReminders(widget.account));
    try {
      final docs = await widget.account.repository.documents();
      if (mounted) setState(() => _docs = docs);
    } catch (_) {
      // Offline or a server fault: the next tick tries again.
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = widget.account.repository;
    try {
      final results = await Future.wait([
        repository.documents(),
        repository.vehicles().catchError((Object _) => <FleetVehicle>[]),
        refreshOnboardingSettings(
          widget.account,
        ).then<Object?>((s) => s, onError: (Object _) => null),
        if (widget.account.account == null)
          widget.account.refresh()
        else
          widget.account.refresh().catchError(
            (Object _) => widget.account.account!,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _docs = results[0] as List<AccountDocument>;
        _cars = results[1] as List<FleetVehicle>;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(error, fallback: tr.docCouldNotLoad),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The document of [type] (never its renewal).
  AccountDocument? _doc(String ownerId, String type) {
    for (final doc in _docs) {
      if (doc.ownerId == ownerId && doc.type == type && !doc.isRenewal) {
        return doc;
      }
    }
    return null;
  }

  /// Contract v0.18.5 (G2-D1): the renewal waiting under the approved
  /// document of [type], if any.
  AccountDocument? _renewal(String ownerId, String type) {
    for (final doc in _docs) {
      if (doc.ownerId == ownerId && doc.type == type && doc.isRenewal) {
        return doc;
      }
    }
    return null;
  }

  /// The status to show: the uploaded document's, else the summary the
  /// server put on the owner, else missing.
  String _status(String ownerId, String type, List<DocumentSummary> summary) {
    final doc = _doc(ownerId, type);
    if (doc != null) return doc.status;
    for (final item in summary) {
      if (item.type == type && !item.isRenewal) return item.status;
    }
    return 'missing';
  }

  /// Owner item 4: a file document opens its upload guide; the info
  /// session opens "How to book" (item 8). The list is read again after.
  Future<void> _open(
    String ownerId,
    String type,
    bool isCar,
    String status,
  ) async {
    final me = widget.account.account;
    final kind = OnboardingSettingsStore.instance.kindOf(type);
    if (kind == DocumentKind.adminCheck) {
      if (type != InfoSessionScreen.type) return;
      await pushSingle(
        context,
        RightToLeftTransition(InfoSessionScreen(status: status)),
      );
      unawaited(_refreshQuietly());
      return;
    }
    final doc = _doc(ownerId, type);
    final result = await pushSingle<Object?>(
      context,
      RightToLeftTransition(
        UploadGuideScreen(
          account: widget.account,
          type: type,
          ownerId: ownerId,
          isCar: isCar,
          country: me?.country ?? DriverAccountRules.current.country,
          status: status,
          expiresAt: doc?.expiresAt,
          filePicker: widget.filePicker,
        ),
      ),
    );
    if (!mounted) return;
    if (result is! AccountDocument) {
      unawaited(_refreshQuietly());
      return;
    }
    final uploaded = result;
    setState(() {
      // v0.18.5 (G2-D1): a renewal sits next to the approved document,
      // which stays; any other upload replaces the type's document.
      _docs = [
        for (final d in _docs)
          if (!(d.ownerId == uploaded.ownerId &&
              d.type == uploaded.type &&
              (!uploaded.isRenewal || d.isRenewal)))
            d,
        uploaded,
      ];
    });
    unawaited(refreshReminders(widget.account));
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.account.account;
    final language = DriverAppTexts.language;
    // Owner decision 19: car documents are the fleet owner's (an owner who
    // drives too); a member driver sees only his own documents and picks a
    // car in My fleet / Vehicles.
    final cars = [if (me != null && seesCarDocuments(me)) ..._cars];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.documents,
        onBack: () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AccountStyle.ink,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              if (_loading)
                const LinearProgressIndicator(color: AccountStyle.ink),
              if (_error != null) ...[
                AccountErrorLine(_error!),
                const SizedBox(height: 10),
                AccountButton(
                  label: tr.retry,
                  outlined: true,
                  onPressed: _load,
                ),
              ],
              if (me != null) ...[
                _section(tr.docYou),
                if (me.requiredDocuments.isEmpty)
                  Text(tr.docNoneYet, style: AccountStyle.hint()),
                for (final type in me.requiredDocuments)
                  _row(me.driverId, type, me.documents, language, isCar: false),
                if (me.requiredFleetDocuments.isNotEmpty) ...[
                  _section(tr.docCompany),
                  for (final type in me.requiredFleetDocuments)
                    _row(
                      me.driverId,
                      type,
                      me.documents,
                      language,
                      isCar: false,
                    ),
                ],
                for (final car in cars) ...[
                  _section(tr.docCar(car.plate)),
                  for (final type in car.requiredDocuments)
                    _row(
                      car.vehicleId,
                      type,
                      car.documents,
                      language,
                      isCar: true,
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 6),
    child: Text(title.toUpperCase(), style: AccountStyle.section()),
  );

  Widget _row(
    String ownerId,
    String type,
    List<DocumentSummary> summary,
    String language, {
    required bool isCar,
  }) {
    final settings = OnboardingSettingsStore.instance;
    final kind = settings.kindOf(type);
    final doc = _doc(ownerId, type);
    final status = shownDocumentStatus(
      kind: kind,
      stored: _status(ownerId, type, summary),
      expiresAt: doc?.expiresAt ?? _summaryExpiry(type, summary),
      warnDays: isCar
          ? settings.settings?.vehicleWarnDays
          : settings.settings?.warnDays.firstOrNull,
      now: DateTime.now(),
    );
    final expiresAt = doc?.expiresAt ?? _summaryExpiry(type, summary);
    final opens =
        kind == DocumentKind.file ||
        (kind == DocumentKind.adminCheck && type == InfoSessionScreen.type);
    final row = DocumentRow(
      key: ValueKey('doc-row-$ownerId-$type'),
      title: settings.nameOf(type, language),
      status: status,
      note: kind == DocumentKind.adminCheck
          ? (type == InfoSessionScreen.type && status != 'approved'
                ? tr.infoHowToBook
                : null)
          : status == 'rejected'
          ? doc?.reviewNote
          : expiresAt != null && status != 'needed'
          ? tr.docExpiresOnNote(DriverDates.dayMonthYear(expiresAt.toLocal()))
          : doc?.fileName,
      onTap: opens ? () => _open(ownerId, type, isCar, status) : null,
    );
    final renewal = _renewal(ownerId, type);
    final listed = renewal == null ? _summaryRenewal(type, summary) : null;
    final renewalStatus = renewal?.status ?? listed?.status;
    if (renewalStatus == null) return row;
    // Contract v0.18.5 (G2-D1): "New document waiting for review" under
    // the approved one; a rejected renewal says why.
    final rejected = renewalStatus == 'rejected';
    final note = renewal?.reviewNote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          key: ValueKey('doc-renewal-$ownerId-$type'),
          padding: const EdgeInsets.fromLTRB(14, 0, 0, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                rejected
                    ? Icons.error_outline_rounded
                    : Icons.hourglass_top_rounded,
                size: 16,
                color: rejected ? const Color(0xFFCB424B) : AuthColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rejected
                      ? (note == null
                            ? tr.docRenewalRejected
                            : '${tr.docRenewalRejected}: $note')
                      : tr.docRenewalWaiting,
                  style: AccountStyle.hint().copyWith(
                    color: rejected ? const Color(0xFFCB424B) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The renewal the profile's summary lists for [type] (before the
  /// document list was read).
  DocumentSummary? _summaryRenewal(String type, List<DocumentSummary> summary) {
    for (final item in summary) {
      if (item.type == type && item.isRenewal) return item;
    }
    return null;
  }

  DateTime? _summaryExpiry(String type, List<DocumentSummary> summary) {
    for (final item in summary) {
      if (item.type == type && !item.isRenewal) return item.expiresAt;
    }
    return null;
  }
}

/// One document line: its name, the status chip (and the rejection note),
/// a progress bar while its file goes up.
class DocumentRow extends StatelessWidget {
  const DocumentRow({
    super.key,
    required this.title,
    required this.status,
    this.note,
    this.uploading = false,
    this.onTap,
  });

  final String title;
  final String status;
  final String? note;
  final bool uploading;
  final VoidCallback? onTap;

  static (String, Color) chipOf(String status) => switch (status) {
    // v0.10.4: contract words (statusWords documentStatus).
    'approved' => (tr.swDocumentStatusApproved, AccountStyle.green),
    'in_review' => (tr.swDocumentStatusInReview, AccountStyle.amber),
    'rejected' => (tr.swDocumentStatusRejected, AccountStyle.error),
    'expired' => (tr.swDocumentStatusExpired, AccountStyle.error),
    'expiring' => (tr.swDocumentStatusExpiring, AccountStyle.amber),
    // v0.17.0 (owner item 8): the info session until Movera marks it.
    'waiting_for_movera' => (
      tr.swDocumentStatusWaitingForMovera,
      AccountStyle.amber,
    ),
    // missing (stored) and needed (required, not uploaded) show "needed".
    _ => (tr.swDocumentStatusNeeded, AccountStyle.error),
  };

  @override
  Widget build(BuildContext context) {
    final (label, color) = chipOf(status);
    return InkWell(
      onTap: uploading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AccountStyle.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AccountStyle.rowTitle()),
                      if (note != null && note!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            note!,
                            style: AuthText.urbanist(
                              size: 12.5,
                              height: 1.35,
                              color: status == 'rejected'
                                  ? AccountStyle.error
                                  : AccountStyle.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                StatusChip(label, color: color),
                if (onTap != null && !uploading) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AccountStyle.ink,
                    size: 22,
                  ),
                ],
              ],
            ),
            if (uploading)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: LinearProgressIndicator(
                        key: ValueKey('doc-progress'),
                        color: AccountStyle.ink,
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(tr.docUploading, style: AccountStyle.hint()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Owner decision 19: only the fleet owner (a fleet account, also when he
/// drives) sees and uploads car documents.
bool seesCarDocuments(DriverAccount account) =>
    account.isFleetAccount || (account.fleet?.isOwner ?? false);
