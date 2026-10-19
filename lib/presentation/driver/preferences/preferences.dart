import 'dart:math' as math;

import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:movera/constants/appassets.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/vehicle/ride_categories.dart';

class Preferences extends StatefulWidget {
  const Preferences({super.key, this.repository});
  final SettingsRepository? repository;

  @override
  State<Preferences> createState() => _PreferencesState();
}

class _PreferencesState extends State<Preferences> {
  // Measured from the approved ride options design.
  static const Color _ink = Color(0xFF111614);
  static const Color _heading = Color(0xFF0F221C);
  static const Color _text = Color(0xFF1F2523);
  static const Color _border = Color(0xFF2A302E);
  static const Color _offInk = Color(0xFFB7BCBA);
  static const Color _offBorder = Color(0xFFDDE1DF);

  // Stored order: the saved `selected` list is indexed by this list, so new
  // categories are only ever appended. [_displayOrder] controls the grid.
  final List<_DriverCategory> _categories = const [
    _DriverCategory(
      title: 'Movera',
      subtitle: 'Standard • Everyday ride',
      icon: AppAssets.rideMovera,
    ),
    _DriverCategory(
      title: 'Comfort',
      subtitle: 'Extra comfort • Plush',
      icon: AppAssets.rideComfort,
    ),
    _DriverCategory(
      title: 'Premium',
      subtitle: 'Luxury • Premium service',
      icon: AppAssets.ridePremium,
    ),
    _DriverCategory(
      title: 'Priority',
      subtitle: 'Faster pickup • Priority',
      icon: AppAssets.ridePriority,
    ),
    _DriverCategory(
      title: 'Movera XL',
      subtitle: '6 seat • Spacious',
      icon: AppAssets.rideXl,
    ),
    _DriverCategory(
      title: 'Electric',
      subtitle: 'Low emissions • Eco',
      icon: AppAssets.rideElectric,
    ),
    _DriverCategory(
      title: 'Movera Pet',
      subtitle: 'Pet friendly • Carrier OK',
      icon: AppAssets.ridePet,
    ),
    _DriverCategory(
      title: 'Booster Seat',
      subtitle: 'Child seat • Kids safe',
      icon: AppAssets.rideBooster,
    ),
  ];

  static const List<int> _displayOrder = [4, 5, 6, 0, 1, 2, 3, 7];

  /// Only the categories admin allows from the car (Q27), in grid order.
  List<int> get _visible => [
        for (final index in _displayOrder)
          if (DriverCategoryAccess.current.allows(_categories[index].title))
            index,
      ];

  late List<bool> _selected;

  late final _settings = widget.repository ?? SettingsRepository();
  bool _loading = true;
  bool _restoreFailed = false;
  bool _restoring = false;
  bool _saveFailed = false;
  bool _retryingSave = false;
  bool _explicitSaving = false;
  int _saveRevision = 0;
  bool get _canEdit =>
      mounted &&
      ModalRoute.of(context)?.isCurrent == true &&
      !_loading &&
      !_restoreFailed;
  Future<void> _restoreSettings() async {
    if (_restoring || !mounted) return;
    _restoring = true;
    setState(() {
      _loading = true;
      _restoreFailed = false;
    });
    try {
      final data = await _settings.read('categories');
      if (!mounted) {
        return;
      }
      final saved = data['selected'];
      setState(() {
        _loading = false;
        if (saved is List &&
            saved.length <= _categories.length &&
            saved.every((v) => v is bool)) {
          // Saves from before a category existed keep it enabled by default.
          _selected = [
            ...saved.cast<bool>(),
            ...List<bool>.filled(_categories.length - saved.length, true),
          ];
        }
      });
      _publishChoice();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _restoreFailed = true;
        });
      }
    } finally {
      _restoring = false;
    }
  }

  Future<bool> _persistSettings() async {
    if (!_canEdit) return false;
    final revision = ++_saveRevision;
    var saved = false;
    try {
      await _settings.save('categories', {'selected': _selected});
      saved = true;
    } catch (_) {
      saved = false;
    }
    if (mounted && revision == _saveRevision) {
      setState(() => _saveFailed = !saved);
    }
    return saved;
  }

  Future<void> _retrySave() async {
    if (!_canEdit || _retryingSave) return;
    setState(() => _retryingSave = true);
    try {
      await _persistSettings();
    } finally {
      if (mounted) setState(() => _retryingSave = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = List<bool>.filled(_categories.length, true);
    _restoreSettings();
  }

  int get _selectedCount => _visible.where((index) => _selected[index]).length;

  /// Offers follow the choice (Q27).
  void _publishChoice() {
    DriverCategoryChoice.off.value = {
      for (final index in _visible)
        if (!_selected[index]) _categories[index].title,
    };
  }

  void _toggle(int index) {
    if (!_canEdit) return;
    setState(() {
      _selected[index] = !_selected[index];
    });
    _publishChoice();
    _persistSettings();
  }

  Future<void> _save() async {
    if (!_canEdit || _explicitSaving || _selectedCount == 0) return;
    setState(() => _explicitSaving = true);
    try {
      final selectedCount = _selectedCount;
      final request = _persistSettings();
      final revision = _saveRevision;
      if (!await request ||
          !mounted ||
          !_canEdit ||
          revision != _saveRevision) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$selectedCount ride categories saved',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _explicitSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    final side = MediaQuery.sizeOf(context).width >= 360 ? 32.0 : 18.0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: largeText
            ? ListView(
                padding: EdgeInsets.symmetric(horizontal: side),
                children: [
                  _buildHeader(context),
                  for (final index in _visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCategory(index),
                    ),
                  _buildSaveArea(),
                ],
              )
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: _buildHeader(context),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Shrink the cards so all rows fit on screen.
                        final visible = _visible;
                        final rows = (visible.length / 2).ceil().clamp(1, 4);
                        final extent =
                            ((constraints.maxHeight - 8 - (rows - 1) * 12) / rows).clamp(
                              100.0,
                              137.0,
                            );
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(side, 0, side, 8),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 14,
                                mainAxisExtent: extent,
                              ),
                          itemCount: visible.length,
                          itemBuilder: (context, i) =>
                              _buildCategory(visible[i], extent: extent),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: _buildSaveArea(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_saveFailed)
          TextButton(
            key: const ValueKey('settings-save-retry'),
            onPressed: _retryingSave ? null : _retrySave,
            child: Text(
              _retryingSave
                  ? 'Saving preferences…'
                  : 'Changes not saved — Retry',
            ),
          ),
        if (_restoreFailed)
          TextButton(
            onPressed: _restoreSettings,
            child: const Text('Could not load saved preferences — Retry'),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Transform.translate(
                // Line the arrow up with the heading's left edge.
                offset: const Offset(-10, 0),
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => maybePopOwned(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 24),
                  color: _heading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_selectedCount of ${_visible.length} active',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose your ride options',
          style: TextStyle(
            color: _heading,
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Select the ride types you'd like available for your trips",
          style: TextStyle(
            color: _text,
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Movera sets these from your car. Switch off any you don’t want.',
          key: ValueKey<String>('preferences-categories-note'),
          style: TextStyle(
            color: Color(0xFF6F7673),
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCategory(int index, {double extent = 137}) {
    // Small screens get slightly smaller text so the icon keeps its room.
    final compact = extent < 120;
    // The two text lines grow with the text size; the icon gives up the
    // room so the description is never cut off (UI-09).
    final scaler = MediaQuery.textScalerOf(context);
    final textBlock =
        (scaler.scale(compact ? 15 : 17) + scaler.scale(compact ? 11 : 12)) *
            1.25;
    final reserved = math.max(compact ? 58.0 : 69.0, textBlock + 25.5);
    final iconHeight = (extent - reserved).clamp(24.0, 68.0);
    final category = _categories[index];
    final selected = _selected[index];
    final radius = BorderRadius.circular(11);

    return Semantics(
      button: true,
      enabled: _canEdit,
      selected: selected,
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _canEdit ? () => _toggle(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? _border : _offBorder,
                width: 1.1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  category.icon,
                  width: iconHeight * 124 / 68,
                  height: iconHeight,
                  colorFilter: ColorFilter.mode(
                    selected ? _ink : _offInk,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? _heading : _offInk,
                      fontSize: compact ? 15 : 17,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    category.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? _text : _offInk,
                      fontSize: compact ? 11 : 12,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveArea() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: !_canEdit || _explicitSaving || _selectedCount == 0
              ? null
              : _save,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _heading,
            disabledForegroundColor: _offInk,
            side: BorderSide(
              color: _selectedCount == 0 ? _offBorder : _border,
              width: 1.4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          child: Text(
            _explicitSaving ? 'Saving preferences…' : 'Save preferences',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverCategory {
  const _DriverCategory({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String icon;
}
