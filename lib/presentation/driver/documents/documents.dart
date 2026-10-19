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
  static const List<_Doc> _driver = [
    _Doc('Terms and Conditions'),
    _Doc('Virtual information session'),
    _Doc('Driver’s license'),
    _Doc('Profile photo'),
    _Doc(
      'Company registration',
      note: 'Bolagsverket or Skatteverket extract. Not needed with a Fleet Partner.',
    ),
    _Doc('Taxi driver license'),
    _Doc('Taxi traffic permit'),
    _Doc('Tax settings'),
    _Doc('Bank statement'),
  ];
  static const List<_Doc> _vehicle = [
    _Doc('Registration certificate', note: 'Front page'),
    _Doc('Insurance letter'),
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
        leading: IconButton(tooltip: 'Back',
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        centerTitle: true,
        title: const Text(
          'Documents',
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
                const Text(
                  'DRIVING IN',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Stockholm · Trips',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Earn anywhere in Sweden',
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
                  child: const Text(
                    'Sample list · Sending these documents is not available '
                    'in the app yet. Nothing here was uploaded or reviewed.',
                    style: TextStyle(color: _muted, fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Text(
                      '$approved of ${all.length} approved',
                      key: const ValueKey<String>('documents-progress'),
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    Text(
                      '$left left',
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
          _section('Driver'),
          _group(context, _driver),
          _section('Vehicle'),
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
      DocStatus.approved => (_green, 'Approved'),
      DocStatus.inReview => (const Color(0xFFD08A1E), 'In review'),
      DocStatus.needed => (const Color(0xFFC2453A), 'Needed'),
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
