import 'dart:async';

import 'package:flutter/material.dart';
import 'package:movera/core/l10n/driver_l10n.dart';

/// Owner 2026-11-21 14:40 ("Don't make philosophy"): when the trip price
/// changes, the driver sees ONLY the new price ("Nytt pris: 240 kr") for
/// [visibleFor], then it goes by itself: no tap needed, and it never
/// blocks the map or the navigation (taps go through it). A newer price
/// while it shows replaces the amount and starts the time again. [close]
/// takes it away when the trip ends or the screen goes.
class MeterChangeNotice {
  static const visibleFor = Duration(seconds: 5);

  final ValueNotifier<String?> _amount = ValueNotifier<String?>(null);
  OverlayEntry? _entry;
  Timer? _timer;
  bool _disposed = false;

  bool get isOpen => _entry != null;

  /// Shows [amount] (the server's formatted fare) over [context]'s screen.
  void show(BuildContext context, String amount) {
    if (_disposed) return;
    _amount.value = amount;
    _timer?.cancel();
    _timer = Timer(visibleFor, close);
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        left: 16,
        right: 16,
        top: MediaQuery.paddingOf(overlayContext).top + 12,
        child: IgnorePointer(
          child: Material(
            key: const ValueKey('meter-change-notice'),
            color: const Color(0xFF303A3F),
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: ValueListenableBuilder<String?>(
                valueListenable: _amount,
                builder: (_, value, _) => Text(
                  tr.tripNewPrice(value ?? amount),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Takes the notice away (its time is up, the trip ended).
  void close() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    _entry = null;
    // Always remove: an entry inserted in this same frame is not mounted
    // yet, and skipping it left the banner stuck on the root overlay.
    entry?.remove();
  }

  /// The screen goes: the notice goes with it.
  void dispose() {
    _disposed = true;
    close();
    _amount.dispose();
  }
}
