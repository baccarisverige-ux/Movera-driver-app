import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:flutter/material.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

class ColorPickerDialog {
  static Future<void> show(
    BuildContext context,
    ValueChanged<String> onColorSelected,
  ) async {
    final selected = await pushSingle<String>(
      context,
      DialogRoute<String>(
        context: context,
        builder: (_) => const _ColorPicker(),
      ),
    );
    if (!context.mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        selected == null) {
      return;
    }
    onColorSelected(selected);
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker();
  static List<(String, Color)> get _colors => <(String, Color)>[
    (tr.colorRed, Colors.red),
    (tr.colorBlue, Colors.blue),
    (tr.colorGreen, Colors.green),
    (tr.colorBlack, Colors.black),
    (tr.colorWhite, Colors.white),
    (tr.colorGray, Colors.grey),
    (tr.colorSilver, Colors.blueGrey),
    (tr.colorYellow, Colors.yellow),
    (tr.colorOrange, Colors.orange),
    (tr.colorBrown, Colors.brown),
    (tr.colorPurple, Colors.purple),
    (tr.colorPink, Colors.pink),
  ];
  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr.chooseVehicleColor,
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: tr.closeColorPicker,
                    onPressed: () => popOwned(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  itemCount: _colors.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth >= 400 ? 3 : 2,
                    mainAxisExtent:
                        80 + MediaQuery.textScalerOf(context).scale(14) * 3,
                  ),
                  itemBuilder: (context, index) {
                    final (name, color) = _colors[index];
                    return TextButton(
                      key: ValueKey('vehicle-color-$name'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () => popOwned(context, name),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black26),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Audit 2026-11-01: car colours are stored as plain words (often English
/// from the server, e.g. "Black", "Grey"). Show them in the app language;
/// an unknown word is shown as stored.
String localizedCarColor(String raw) {
  final key = raw.trim().toLowerCase();
  if (key.isEmpty) return raw;
  final names = <String Function(), List<String>>{
    () => tr.colorRed: ['red', 'röd', 'rouge'],
    () => tr.colorBlue: ['blue', 'blå', 'bleu'],
    () => tr.colorGreen: ['green', 'grön', 'vert'],
    () => tr.colorBlack: ['black', 'svart', 'noir'],
    () => tr.colorWhite: ['white', 'vit', 'blanc', 'blanche'],
    () => tr.colorGray: ['gray', 'grey', 'grå', 'gris', 'grise'],
    () => tr.colorSilver: ['silver', 'argent', 'argenté', 'silvrig'],
    () => tr.colorYellow: ['yellow', 'gul', 'jaune'],
    () => tr.colorOrange: ['orange'],
    () => tr.colorBrown: ['brown', 'brun', 'marron'],
    () => tr.colorPurple: ['purple', 'lila', 'violet'],
    () => tr.colorPink: ['pink', 'rosa', 'rose'],
  };
  for (final entry in names.entries) {
    if (entry.value.contains(key)) return entry.key();
  }
  return raw;
}
