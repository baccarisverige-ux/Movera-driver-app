import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'document_preview.dart';
import 'package:movera/presentation/driver/documents/document_renewal.dart';
import 'package:movera/widgets/navigation_transition.dart';

enum DocStatus { approved, inReview, needed }

class DriverDocuments extends StatelessWidget {
  const DriverDocuments({super.key});

  static const Color _ink = Color(0xFF111614);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFECEEEF);
  static const Color _green = Color(0xFF1FA463);

  // Nothing is uploaded or checked yet, so every document is still needed.
  static List<_Doc> get _driver => [
    _Doc(tr.docTermsAndConditions),
    _Doc(tr.docVirtualInfoSession),
    _Doc(tr.docDriversLicenseLower),
    _Doc(tr.docProfilePhoto),
    _Doc(
      tr.docCompanyRegistration,
      note: tr.docCompanyRegistrationNote,
    ),
    _Doc(tr.docTaxiDriverLicense),
    _Doc(tr.docTaxiTrafficPermit),
    _Doc(tr.docTaxSettings),
    _Doc(tr.docBankStatement),
  ];
  static List<_Doc> get _vehicle => [
    _Doc(tr.docRegistrationCertificate, note: tr.docFrontPage),
    _Doc(tr.docInsuranceLetter),
  ];

  @override
  Widget build(BuildContext context) {
    final all = [..._driver, ..._vehicle];
    final approved = all.where((d) => d.status == DocStatus.approved).length;
    final left = all.length - approved;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        centerTitle: true,
        title: Text(
          tr.documents,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          // Q26: documents that run out soon, with "Upload new".
          const DocumentExpiryList(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.drivingInHeader,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr.docStockholmTrips,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr.docEarnAnywhereSweden,
                  style: TextStyle(color: _muted, fontSize: 14),
                ),
                const SizedBox(height: 14),
                // No upload or review service yet: say so instead of
                // presenting the list as a real onboarding checklist.
                Container(
                  key: const ValueKey<String>('documents-sample-notice'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tr.docSampleListNotice,
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Text(
                      tr.docApprovedOfTotal(approved, all.length),
                      key: const ValueKey<String>('documents-progress'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    Text(
                      tr.docLeftCount(left),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: approved / all.length,
                    minHeight: 5,
                    color: _green,
                    backgroundColor: const Color(0xFFEDEFF0),
                  ),
                ),
              ],
            ),
          ),
          _section(tr.driver),
          _group(context, _driver),
          _section(tr.vehicle),
          _group(context, _vehicle),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 4),
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      );

  Widget _status(DocStatus status) {
    final (color, label) = switch (status) {
      DocStatus.approved => (_green, tr.docStatusApproved),
      DocStatus.inReview => (const Color(0xFFD08A1E), tr.docStatusInReview),
      DocStatus.needed => (const Color(0xFFC2453A), tr.docStatusNeeded),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _group(BuildContext context, List<_Doc> items) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          InkWell(
            onTap: () {
              pushSingle(
                context,
                RightToLeftTransition(DocumentPreview(title: items[i].title)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 14, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].title,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (items[i].note != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              items[i].note!,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        _status(items[i].status),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB4BBB8),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (i < items.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Container(height: 1, color: _line),
            ),
        ],
      ],
    );
  }
}

class _Doc {
  const _Doc(this.title, {this.note});
  final String title;
  final String? note;
  // No upload or review service yet: every document starts as needed.
  DocStatus get status => DocStatus.needed;
}
