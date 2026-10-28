import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/content/driver_app_texts.dart';
import 'package:movera/core/content/driver_content.dart';
import 'package:movera/core/content/driver_content_store.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/session/driver_session_controller.dart';
import 'package:movera/presentation/driver/safety%20toolkits/safety_toolkits.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contract v0.10.0 §19 over every screen: the app-versions rule ("Update
/// the app" full screen below min, a closable message below recommended,
/// only a small message during a trip) and the new terms at app start
/// (never during a trip). SOS stays reachable from the block.
class DriverContentGate extends StatefulWidget {
  const DriverContentGate({
    super.key,
    required this.session,
    required this.navigatorKey,
    required this.child,
    this.store,
    this.acceptTerms,
    this.openStore,
  });

  final DriverSessionController session;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final DriverContentStore? store;

  /// `POST /account/terms/accept`; the live build's by default.
  final Future<bool> Function(int version)? acceptTerms;
  final Future<bool> Function(Uri store)? openStore;

  @override
  State<DriverContentGate> createState() => _DriverContentGateState();
}

class _DriverContentGateState extends State<DriverContentGate> {
  DriverContentStore get _store => widget.store ?? DriverContentStore.instance;

  /// The SOS opened from the block is on screen.
  bool _sosOpen = false;

  bool get _onTrip => widget.session.status == DriverOnlineStatus.onTrip;

  void _openSos() {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;
    setState(() => _sosOpen = true);
    unawaited(
      navigator
          .push(MaterialPageRoute<void>(builder: (_) => const SafetyToolKits()))
          .whenComplete(() {
            if (mounted) setState(() => _sosOpen = false);
          }),
    );
  }

  Future<bool> _accept(int version) {
    final accept =
        widget.acceptTerms ??
        LiveDriverServices.instance?.content.acceptTerms ??
        (int v) async {
          await _store.accepted(v);
          return true;
        };
    return accept(version);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_store, widget.session]),
      builder: (context, _) {
        final view = _store.updateView(onTrip: _onTrip);
        final terms = _store.termsDue;
        Widget? cover;
        if (!_sosOpen && view == UpdateView.blocked) {
          cover = UpdateRequiredScreen(
            onSos: _openSos,
            openStore: widget.openStore,
          );
        } else if (!_onTrip && terms != null && _store.termsScreenWanted) {
          cover = TermsAcceptScreen(
            item: _store.legal!,
            version: terms,
            accept: _accept,
          );
        }
        return Stack(
          children: [
            widget.child,
            if (view == UpdateView.recommendedMessage && cover == null)
              _Banner(
                key: const ValueKey<String>('content-update-recommended'),
                text: tr.contentUpdateRecommended,
                onClose: _store.closeRecommended,
                onTap: () => unawaited(_launchStore(widget.openStore)),
              ),
            if (view == UpdateView.tripMessage)
              _Banner(
                key: const ValueKey<String>('content-update-trip'),
                text: tr.contentUpdateAfterTrip,
                small: true,
              ),
            if (cover != null) cover,
          ],
        );
      },
    );
  }
}

/// The store for this phone.
@visibleForTesting
Uri driverStoreUri([TargetPlatform? platform]) => Uri.parse(
  (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
      ? DriverAppVersion.appStore
      : DriverAppVersion.playStore,
);

Future<bool> _launchStore(Future<bool> Function(Uri)? open) async {
  try {
    return await (open ??
        (uri) => launchUrl(uri, mode: LaunchMode.externalApplication))(
      driverStoreUri(),
    );
  } catch (_) {
    return false;
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.text,
    this.onClose,
    this.onTap,
    this.small = false,
  });

  final String text;
  final VoidCallback? onClose;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      // Above Home's radar button and bottom bar.
      bottom: small ? null : 128,
      top: small ? MediaQuery.paddingOf(context).top + 72 : null,
      child: SafeArea(
        top: false,
        child: Center(
          child: Material(
            color: const Color(0xFF111614),
            borderRadius: BorderRadius.circular(small ? 20 : 14),
            elevation: 6,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(small ? 20 : 14),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  small ? 14 : 16,
                  small ? 7 : 10,
                  onClose == null ? (small ? 14 : 16) : 4,
                  small ? 7 : 10,
                ),
                child: Row(
                  mainAxisSize: small ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      color: Colors.white,
                      size: small ? 16 : 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      fit: small ? FlexFit.loose : FlexFit.tight,
                      child: Text(
                        text,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: small ? 12.5 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (onClose != null)
                      // Above the Navigator: no Overlay for a tooltip.
                      Semantics(
                        button: true,
                        label: tr.close,
                        child: InkResponse(
                          key: const ValueKey<String>('content-update-close'),
                          onTap: onClose,
                          radius: 22,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Below the minimum version: the app is blocked; only the store and SOS.
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key, required this.onSos, this.openStore});

  final VoidCallback onSos;
  final Future<bool> Function(Uri)? openStore;

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _failed = false;

  Future<void> _open() async {
    final opened = await _launchStore(widget.openStore);
    if (mounted) setState(() => _failed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    return _FullScreen(
      key: const ValueKey<String>('content-update-required'),
      icon: Icons.system_update_rounded,
      title: tr.contentUpdateTitle,
      body: Text(
        tr.contentUpdateBody,
        textAlign: TextAlign.center,
        style: _bodyStyle,
      ),
      actions: [
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              tr.contentUpdateStoreFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCB424B)),
            ),
          ),
        FilledButton(
          key: const ValueKey<String>('content-update-store'),
          onPressed: _open,
          style: _primary,
          child: Text(tr.contentUpdateStore, style: _label),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const ValueKey<String>('content-update-sos'),
          onPressed: widget.onSos,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFCB424B),
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: Color(0xFFCB424B)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.sos_rounded),
          label: Text(tr.safetySos),
        ),
      ],
    );
  }
}

/// The new terms (legal with reaccept) at app start.
class TermsAcceptScreen extends StatefulWidget {
  const TermsAcceptScreen({
    super.key,
    required this.item,
    required this.version,
    required this.accept,
  });

  final DriverContentItem item;
  final int version;
  final Future<bool> Function(int version) accept;

  @override
  State<TermsAcceptScreen> createState() => _TermsAcceptScreenState();
}

class _TermsAcceptScreenState extends State<TermsAcceptScreen> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await widget.accept(widget.version);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return _FullScreen(
      key: const ValueKey<String>('content-terms'),
      icon: Icons.article_outlined,
      title: item.title.isEmpty ? tr.contentTermsTitle : item.title,
      body: SingleChildScrollView(
        child: Text(item.textIn(DriverAppTexts.language), style: _bodyStyle),
      ),
      expandBody: true,
      actions: [
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              tr.contentTermsFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFCB424B)),
            ),
          ),
        FilledButton(
          key: const ValueKey<String>('content-terms-accept'),
          onPressed: _busy ? null : _accept,
          style: _primary,
          child: Text(tr.contentTermsAccept, style: _label),
        ),
      ],
    );
  }
}

const _label = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

const _bodyStyle = TextStyle(
  color: Color(0xFF5D6A70),
  fontSize: 15,
  height: 1.45,
);

final _primary = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF111614),
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

class _FullScreen extends StatelessWidget {
  const _FullScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
    this.expandBody = false,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool expandBody;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: const Color(0xFFF9FBFA),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!expandBody) const Spacer(),
                Icon(icon, size: 56, color: const Color(0xFF111614)),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111614),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (expandBody) Expanded(child: body) else body,
                if (!expandBody) const Spacer(),
                const SizedBox(height: 16),
                ...actions,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
