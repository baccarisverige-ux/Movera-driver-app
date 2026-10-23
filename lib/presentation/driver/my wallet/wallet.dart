import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/presentation/driver/my%20bank/my_bank.dart';

Widget _solarIcon(
  String asset, {
  double size = 20,
  Color color = const Color(0xFF1F2933),
}) => SvgPicture.asset(
  asset,
  width: size,
  height: size,
  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
);

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  static const Color _page = Color(0xFFFFFFFF);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _tile = Color(0xFFF4F5F6);
  static const Color _text = Color(0xFF1F2933);
  static const Color _subtle = Color(0xFF5F6B72);
  static const Color _muted = Color(0xFF7C868D);
  static const Color _dot = Color(0xFF9AA3A8);
  static const Color _line = Color(0xFFECEEF0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _balanceHero(),
                    const SizedBox(height: 14),
                    _payoutInfoStrip(context),
                    const SizedBox(height: 28),
                    // driver-u147: no 'See all' until there is a payouts list;
                    // it opened My bank.
                    _sectionHeader(title: tr.recentPayouts),
                    const SizedBox(height: 12),
                    _recentPayouts(),
                    const SizedBox(height: 22),
                    _bankCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            Material(
              color: _white,
              shape: const CircleBorder(side: BorderSide(color: _line)),
              child: InkWell(
                key: const ValueKey<String>('wallet-back'),
                onTap: () => popOwned(context),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  height: 42,
                  width: 42,
                  child: Center(child: _solarIcon(AppAssets.solarAltArrowLeft)),
                ),
              ),
            ),
            Expanded(
              child: Text(
                tr.wallet,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.25,
                ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }

  Widget _balanceHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 7,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        tr.previewOnly,
                        style: TextStyle(
                          color: _text,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _tile,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: _solarIcon(AppAssets.solarWallet),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '0,00 kr',
            style: TextStyle(
              color: _text,
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr.noPayoutBalanceUntilPaymentService,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _payoutInfoStrip(BuildContext context) {
    // Large text (release evidence b8bd860, F3): the "not set" chip moves
    // under the texts so the subtitle keeps the width of the strip, and
    // the strip's scale is capped so its longest word ("Utbetalningsdatum")
    // still fits one line instead of being split inside the word.
    final large = MediaQuery.textScalerOf(context).scale(14) > 20;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Text(
        tr.notSet,
        style: TextStyle(
          color: _subtle,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tile,
                borderRadius: BorderRadius.circular(13),
              ),
              child: _solarIcon(AppAssets.solarRefresh),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.noAutomaticPayout,
                    style: TextStyle(
                      color: _text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    tr.payoutDateIsNotAvailable,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (large) ...[const SizedBox(height: 8), chip],
                ],
              ),
            ),
            if (!large) chip,
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader({required String title}) {
    return Text(
      title,
      style: const TextStyle(
        color: _text,
        fontSize: 19,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _recentPayouts() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Text(
          tr.noPayoutsYetLocalPreviewCannot,
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _bankCard() {
    return Builder(
      builder: (context) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              pushSingle(
                context,
                MaterialPageRoute<void>(builder: (_) => const MyBank()),
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _tile,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: _solarIcon(AppAssets.solarCard, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr.payoutAccount,
                          style: TextStyle(
                            color: _text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          tr.noPayoutAccountConnected,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _solarIcon(AppAssets.solarInfoCircle, color: _subtle),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
