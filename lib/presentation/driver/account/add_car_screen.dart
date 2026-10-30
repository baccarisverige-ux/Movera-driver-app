import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:movera/core/account/account_error_message.dart';
import 'package:movera/core/account/driver_account.dart';
import 'package:movera/core/account/driver_account_session.dart';
import 'package:movera/core/contracts/category_catalog.dart';
import 'package:movera/core/contracts/category_name_text.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/presentation/driver/account/account_style.dart';
import 'package:movera/core/onboarding/onboarding_settings.dart';
import 'package:movera/presentation/driver/account/car_photos_screen.dart';
import 'package:movera/presentation/driver/account/details_pickers.dart';
import 'package:movera/presentation/driver/auth/widgets/auth_style.dart';
import 'package:movera/presentation/driver/documents/onboarding_refresh.dart';
import 'package:movera/widgets/navigation_transition.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';

/// A fleet owner adds a car (`POST /driver/vehicles`); Movera reviews it.
/// Contract v0.17.0 (owner item 11, "Make them real"): the admin's car
/// rules of the driver's country (`GET /driver/onboarding/settings`) say
/// which car types the car fits (year, seats, fuel); only those are
/// offered. After the car is added the app asks its four photos.
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
  final Set<String> _categories = {};
  String? _fuel;
  bool _busy = false;
  String? _error;

  OnboardingSettings? _rules;
  bool _rulesLoading = true;
  String? _rulesError;

  @override
  void initState() {
    super.initState();
    _rules = OnboardingSettingsStore.instance.settings;
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() {
      _rulesLoading = true;
      _rulesError = null;
    });
    try {
      final rules = await refreshOnboardingSettings(widget.account);
      if (mounted) setState(() => _rules = rules);
    } catch (error) {
      if (mounted && _rules == null) {
        setState(
          () => _rulesError = accountErrorMessage(
            error,
            fallback: tr.carRulesCouldNotLoad,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _rulesLoading = false);
    }
  }

  int get _yearValue => int.tryParse(_year.text.trim()) ?? 0;
  int get _seatsValue => int.tryParse(_seats.text.trim()) ?? 0;

  /// The car types the car fits now, in catalog order; empty until the
  /// rules, the year and the seats are known.
  List<String> get _fitting {
    final rules = _rules;
    if (rules == null || _yearValue < 1950 || _seatsValue < 1) return const [];
    return rules.fittingCategories(
      CategoryCatalog.seed,
      year: _yearValue,
      seats: _seatsValue,
      fuel: _fuel,
    );
  }

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
        _fuel != null &&
        _rideChosen;
  }

  /// Contract v0.18.3 (R2): at least one ride type is ticked; an extra
  /// (Booster Seat) alone is not enough.
  bool get _rideChosen => _categories.any(
    (id) => _fitting.contains(id) && !OnboardingSettings.isExtra(id),
  );

  /// Only extras are ticked: say a ride type is needed too.
  bool get _onlyExtras =>
      !_rideChosen &&
      _categories.any(
        (id) => _fitting.contains(id) && OnboardingSettings.isExtra(id),
      );

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
            for (final id in _fitting)
              if (_categories.contains(id)) id,
          ],
          fuel: _fuel,
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
        // Owner item 11: the four photos next (when the admin asks them).
        final photos = _rules?.carPhotos ?? const <String>[];
        if (photos.isNotEmpty) {
          await pushSingle(
            context,
            RightToLeftTransition(
              CarPhotosScreen(
                account: widget.account,
                vehicle: vehicle,
                photoTypes: photos,
              ),
            ),
          );
        }
        if (mounted) popOwned(context, vehicle);
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = accountErrorMessage(
          error,
          fallback: tr.fleetCouldNotAddCar,
          baseYear: _rules?.baseYear,
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
                child: Text(tr.carFuel, style: AccountStyle.label()),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final fuel in OnboardingSettings.fuels)
                    ChoiceChip(
                      key: ValueKey('car-fuel-$fuel'),
                      label: Text(fuelLabel(fuel)),
                      selected: _fuel == fuel,
                      onSelected: _busy
                          ? null
                          : (on) => setState(() => _fuel = on ? fuel : null),
                      selectedColor: const Color(0xFFE2EEE6),
                      labelStyle: AuthText.urbanist(
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                      side: const BorderSide(color: AccountStyle.line),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tr.fleetCarTypes, style: AccountStyle.label()),
              ),
              ..._categoryChips(),
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

  /// Only the car types the car fits (owner item 11).
  List<Widget> _categoryChips() {
    if (_rulesLoading && _rules == null) {
      return const [LinearProgressIndicator(color: AccountStyle.ink)];
    }
    if (_rules == null) {
      return [
        AccountErrorLine(_rulesError ?? tr.carRulesCouldNotLoad),
        const SizedBox(height: 8),
        AccountButton(label: tr.retry, outlined: true, onPressed: _loadRules),
      ];
    }
    if (_yearValue < 1950 || _seatsValue < 1 || _fuel == null) {
      return [Text(tr.carTypesEnterFirst, style: AccountStyle.hint())];
    }
    final fitting = _fitting;
    if (fitting.isEmpty) {
      return [
        Text(
          tr.carNoTypeFits,
          key: const ValueKey('car-no-type-fits'),
          style: AuthText.urbanist(
            size: 14,
            weight: FontWeight.w600,
            color: AccountStyle.error,
          ),
        ),
      ];
    }
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final id in fitting)
            FilterChip(
              key: ValueKey('car-type-$id'),
              label: Text(
                categoryNameText(CategoryCatalog.driverLabels[id] ?? id),
              ),
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
              labelStyle: AuthText.urbanist(size: 13, weight: FontWeight.w600),
              side: const BorderSide(color: AccountStyle.line),
            ),
        ],
      ),
      if (_onlyExtras)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            tr.carExtraNeedsRide,
            key: const ValueKey('car-extra-needs-ride'),
            style: AuthText.urbanist(
              size: 14,
              weight: FontWeight.w600,
              color: AccountStyle.error,
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        tr.carTypesFitHint(
          countryName(widget.account.account?.country ?? _rules?.country ?? ''),
        ),
        style: AccountStyle.hint(),
      ),
    ];
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

/// "Petrol", "Diesel", "Hybrid", "Electric" in the app's language.
String fuelLabel(String fuel) => switch (fuel) {
  'petrol' => tr.fuelPetrol,
  'diesel' => tr.fuelDiesel,
  'hybrid' => tr.fuelHybrid,
  _ => tr.fuelElectric,
};
