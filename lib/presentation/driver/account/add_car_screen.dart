import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/widgets/owned_route_exit.dart';

/// A fleet owner adds a car (`POST /driver/vehicles`); Movera reviews it,
/// and its documents go up from the Documents screen.
class AddCarScreen extends StatefulWidget {
  const AddCarScreen({super.key, required this.account, this.onAdded});

  final DriverAccountSession account;
  final void Function(BuildContext context, FleetVehicle vehicle)? onAdded;

  @override
  State<AddCarScreen> createState() => _AddCarScreenState();
}

class _AddCarScreenState extends State<AddCarScreen> {
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  final _seats = TextEditingController(text: '4');
  final Set<String> _categories = {'economy', 'comfort'};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_make, _model, _year, _color, _plate, _seats]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _complete {
    final year = int.tryParse(_year.text.trim()) ?? 0;
    final seats = int.tryParse(_seats.text.trim()) ?? 0;
    return _make.text.trim().isNotEmpty &&
        _model.text.trim().isNotEmpty &&
        year >= 1950 &&
        year <= 2100 &&
        _color.text.trim().isNotEmpty &&
        _plate.text.trim().isNotEmpty &&
        seats >= 1 &&
        seats <= 20 &&
        _categories.isNotEmpty;
  }

  Future<void> _save() async {
    if (_busy || !_complete) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final vehicle = await widget.account.repository.addVehicle(
        NewVehicle(
          make: _make.text,
          model: _model.text,
          year: int.parse(_year.text.trim()),
          color: _color.text,
          plate: _plate.text,
          seats: int.parse(_seats.text.trim()),
          categoryIds: [
            for (final id in CategoryCatalog.seed)
              if (_categories.contains(id)) id,
          ],
        ),
      );
      if (!mounted) return;
      final onAdded = widget.onAdded;
      if (onAdded != null) {
        onAdded(context, vehicle);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr.fleetCarAdded)));
        popOwned(context, vehicle);
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(
          error,
          fallback: tr.fleetCouldNotAddCar,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AccountStyle.appBar(
        context,
        tr.fleetAddCar,
        onBack: _busy ? null : () => maybePopOwned(context),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _make,
            _model,
            _year,
            _color,
            _plate,
            _seats,
          ]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              _field(
                'car-make',
                tr.make,
                _make,
                capitalization: TextCapitalization.words,
              ),
              _field(
                'car-model',
                tr.model,
                _model,
                capitalization: TextCapitalization.words,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      'car-year',
                      tr.year,
                      _year,
                      keyboard: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      'car-seats',
                      tr.fleetSeats,
                      _seats,
                      keyboard: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ),
                ],
              ),
              _field(
                'car-color',
                tr.fleetColour,
                _color,
                capitalization: TextCapitalization.words,
              ),
              _field(
                'car-plate',
                tr.fleetPlate,
                _plate,
                capitalization: TextCapitalization.characters,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tr.fleetCarTypes, style: AccountStyle.label()),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in CategoryCatalog.seed)
                    FilterChip(
                      key: ValueKey('car-type-$id'),
                      label: Text(CategoryCatalog.driverLabels[id] ?? id),
                      selected: _categories.contains(id),
                      onSelected: _busy
                          ? null
                          : (on) => setState(() {
                              if (on) {
                                _categories.add(id);
                              } else {
                                _categories.remove(id);
                              }
                            }),
                      selectedColor: const Color(0xFFE2EEE6),
                      checkmarkColor: AccountStyle.ink,
                      labelStyle: AuthText.urbanist(
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                      side: const BorderSide(color: AccountStyle.line),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(tr.vehDocumentsOnDocs, style: AccountStyle.hint()),
              if (_error != null) AccountErrorLine(_error!),
              const SizedBox(height: 20),
              AccountButton(
                key: const ValueKey('car-save'),
                label: tr.fleetAddCar,
                busy: _busy,
                onPressed: _complete ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: AccountStyle.label()),
          ),
          TextField(
            key: ValueKey(key),
            controller: controller,
            enabled: !_busy,
            keyboardType: keyboard,
            textCapitalization: capitalization,
            inputFormatters: formatters,
            style: AuthText.urbanist(size: 15),
            cursorColor: AccountStyle.ink,
            decoration: AccountStyle.decoration(),
          ),
        ],
      ),
    );
  }
}
