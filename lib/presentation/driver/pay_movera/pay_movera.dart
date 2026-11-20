import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/core/live/live_driver_services.dart';
import 'package:movera/core/live/live_earnings.dart';
import 'package:movera/core/payments/stripe_sheet.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Contract v0.18.139 `driverPayRequest.driver` (owner 2026-11-20 "ask
/// driver monthly to pay how much due to Movera, so adding notification and
/// push screen with link to pay", "Link sumup for exp"; TEMPORARY): what the
/// driver owes Movera now, a reference, and — while his country's monthly
/// pay request is on — a button that opens the admin's payment link.
///
/// Money rules: the amount is the server's (`GET /driver/pay-movera`, the
/// same number as the wallet's "You owe Movera"); the link is opened as it
/// is, the app adds no amount to it (a payment link may be generic), so the
/// screen shows the amount and the reference to enter there; the payment is
/// confirmed by Movera by hand, so nothing changes here until then.
class PayMoveraScreen extends StatefulWidget {
  const PayMoveraScreen({
    super.key,
    this.load,
    this.openLink,
    this.startCard,
    this.presentCard,
  });

  /// Reads the screen's numbers; default: the live server.
  final Future<PayMovera> Function()? load;

  /// Opens the payment link in the browser; default: url_launcher.
  final Future<bool> Function(Uri link)? openLink;

  /// DRAFT (driverPayRequest.stripe): POST /driver/pay-movera/pay; default: the live server.
  final Future<StripeDriverPayment> Function()? startCard;

  /// Shows the Stripe PaymentSheet; default: flutter_stripe. true = paid on the phone.
  final Future<bool> Function(StripeDriverPayment intent)? presentCard;

  @override
  State<PayMoveraScreen> createState() => _PayMoveraScreenState();
}

class _PayMoveraScreenState extends State<PayMoveraScreen> {
  static const Color _ink = Color(0xFF1F2933);
  static const Color _muted = Color(0xFF667178);
  static const Color _line = Color(0xFFECEEF0);
  static const Color _tile = Color(0xFFF4F5F6);
  static const Color _owe = Color(0xFFB4232C);

  late Future<PayMovera> _view = _load();

  Future<PayMovera> _load() {
    final load = widget.load;
    if (load != null) return load();
    final live = LiveDriverServices.instance;
    if (live == null) {
      return Future<PayMovera>.error(StateError('no live server'));
    }
    return live.earnings.payMovera();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr.payMoveraCopied)));
  }

  bool _busy = false;

  void _say(String key, String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(key: ValueKey<String>(key), content: Text(text)));
  }

  /// DRAFT (owner 2026-11-20 "Stripe ... (2) the DRIVER paying his monthly
  /// invoice"): the server's PaymentIntent, the Stripe sheet, then the
  /// screen reads the server again: paid only when the server's owed drops.
  Future<void> _payByCard() async {
    setState(() => _busy = true);
    try {
      final live = LiveDriverServices.instance;
      final intent =
          await (widget.startCard ??
              () => live!.earnings.startStripePayment())();
      final paid =
          await (widget.presentCard ??
              (i) => presentStripeSheet(
                clientSecret: i.clientSecret,
                publishableKey: i.publishableKey,
              ))(intent);
      if (!paid) return;
      final next = _load();
      setState(() {
        _view = next;
      });
      final view = await next;
      _say(
        'pay-movera-card-outcome',
        view.owedToMovera.minorUnits < intent.amount.minorUnits
            ? tr.payMoveraCardPaid
            : tr.payMoveraCardChecking,
      );
    } catch (_) {
      _say('pay-movera-card-outcome', tr.payMoveraCardFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay(Uri link) async {
    var opened = false;
    try {
      opened =
          await (widget.openLink ??
              (uri) =>
                  launchUrl(uri, mode: LaunchMode.externalApplication))(link);
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey<String>('pay-movera-link-failed'),
          content: Text(tr.payMoveraLinkFailed),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.payMoveraTitle,
        onBack: () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: FutureBuilder<PayMovera>(
          future: _view,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final view = snap.data;
            if (snap.hasError || view == null) return _failed();
            return _body(view);
          },
        ),
      ),
    );
  }

  Widget _failed() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr.payMoveraUnavailable,
            key: const ValueKey<String>('pay-movera-unavailable'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            key: const ValueKey<String>('pay-movera-retry'),
            onPressed: () => setState(() {
              _view = _load();
            }),
            child: Text(tr.retry),
          ),
        ],
      ),
    ),
  );

  Widget _body(PayMovera view) {
    final owes = view.owedToMovera.minorUnits > 0;
    final card = view.canPayByCard;
    final link = !card && view.canPay ? view.payLink : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // "You owe Movera" / "Settled": the app's existing words.
                  owes ? tr.cashYouOweMovera : tr.cashSettled,
                  key: const ValueKey<String>('pay-movera-label'),
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    view.owedToMovera.formatted,
                    key: const ValueKey<String>('pay-movera-amount'),
                    maxLines: 1,
                    style: TextStyle(
                      color: owes ? _owe : _ink,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                ),
                if (owes && link == null && !card) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr.settledInYourNextPayout2,
                    key: const ValueKey<String>('pay-movera-settles'),
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (owes) ...[
            const SizedBox(height: 14),
            _copyRow(
              'amount',
              tr.payMoveraAmountToPay,
              view.owedToMovera.formatted,
            ),
            const SizedBox(height: 8),
            _copyRow('reference', tr.payMoveraReference, view.reference),
          ],
          if (card) ...[
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey<String>('pay-movera-card-button'),
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _busy ? null : _payByCard,
              child: Text(
                tr.payMoveraPayByCard(view.owedToMovera.formatted),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (link != null) ...[
            const SizedBox(height: 18),
            Text(
              tr.payMoveraHowTo,
              key: const ValueKey<String>('pay-movera-how-to'),
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('pay-movera-button'),
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _pay(link),
              child: Text(
                tr.payMoveraTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              tr.payMoveraConfirmNote,
              key: const ValueKey<String>('pay-movera-confirm-note'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Label / value …… Copy": the value can be selected and copied.
  Widget _copyRow(String id, String label, String value) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
    decoration: BoxDecoration(
      color: _tile,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                value,
                key: ValueKey<String>('pay-movera-$id'),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          key: ValueKey<String>('pay-movera-copy-$id'),
          onPressed: () => _copy(value),
          child: Text(tr.payMoveraCopy),
        ),
      ],
    ),
  );
}
