import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/legal/driver_legal.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';

/// Which legal document a page shows.
enum LegalKind { terms, privacy }

/// Contract v0.18.5 `legal` (owner G1-B2): the terms of use or the privacy
/// policy of the driver's country, as the admin published them (or
/// Movera's drafts), in the app's language. Opened from the sign-in screen
/// and from the menu, as two separate pages. The demo build (no server)
/// keeps its built-in short text.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({super.key, required this.kind, this.legal});

  final LegalKind kind;

  /// Null: [DriverLegal.instance].
  final DriverLegal? legal;

  static LegalDocumentScreen get privacy =>
      const LegalDocumentScreen(kind: LegalKind.privacy);

  static LegalDocumentScreen get terms =>
      const LegalDocumentScreen(kind: LegalKind.terms);

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  DriverLegal get _legal => widget.legal ?? DriverLegal.instance;

  @override
  void initState() {
    super.initState();
    // The latest version each time the page opens (no token needed).
    if (_legal.live) _legal.refresh();
  }

  String _fallbackTitle() => widget.kind == LegalKind.terms
      ? tr.termsOfService
      : tr.privacyPolicyTitle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _legal,
      builder: (context, _) {
        final language = DriverAppTexts.language;
        final texts = _legal.current;
        final doc = texts == null
            ? null
            : widget.kind == LegalKind.terms
            ? texts.terms
            : texts.privacy;
        final title = doc?.titleIn(language) ?? _fallbackTitle();
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: AppColor.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: tr.back,
              onPressed: () => popOwned(context),
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: AppColor.title,
                size: ResSize.h * 18,
              ),
            ),
            centerTitle: true,
            title: Semantics(
              header: true,
              child: TextWidget(
                text: title,
                color: AppColor.title,
                fontSize: 16,
                fontWeight: fwMedium,
              ),
            ),
          ),
          body: _body(doc, language),
        );
      },
    );
  }

  Widget _body(LegalDocument? doc, String language) {
    if (doc != null) {
      return ListView(
        key: ValueKey('legal-${widget.kind.name}'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          for (final paragraph in doc.paragraphsIn(language))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(paragraph, style: _style),
            ),
        ],
      );
    }
    if (!_legal.live) {
      // The demo build has no server: its built-in short text.
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            widget.kind == LegalKind.terms
                ? tr.legalTermsBody
                : tr.legalPrivacyBody,
            style: _style,
          ),
        ],
      );
    }
    if (_legal.failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr.legalCouldNotLoad,
                key: const ValueKey('legal-failed'),
                textAlign: TextAlign.center,
                style: _style,
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _legal.refresh, child: Text(tr.retry)),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  static const _style = TextStyle(
    color: Color(0xFF3F4A50),
    fontSize: 14,
    height: 1.45,
  );
}
