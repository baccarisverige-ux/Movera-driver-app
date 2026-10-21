import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/widgets/single_route_entry.dart';
import 'package:movera/core/vehicle/vehicle_year_policy.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:movera/core/vehicle/local_vehicle_store.dart';
import 'package:image_picker/image_picker.dart';

// Mounted routes can still be closing or covered by another route.
void _popVehicleRoute<T>(BuildContext context, [T? result]) {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  Navigator.of(context).pop<T>(result);
}

class AddVehicle extends StatefulWidget {
  const AddVehicle({super.key, this.store});

  final LocalVehicleStore? store;

  @override
  State<AddVehicle> createState() => _AddVehicleState();
}

class _AddVehicleState extends State<AddVehicle> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  final TextEditingController _make = TextEditingController();
  final TextEditingController _model = TextEditingController();
  final TextEditingController _plate = TextEditingController();
  String? _year;
  bool _saving = false;
  // Set once the draft row exists: the documents page may have added
  // photos to it since.
  bool _drafted = false;
  late final _store = widget.store ?? LocalVehicleStore();
  late final String _vehicleId =
      'local-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _make.addListener(_refresh);
    _model.addListener(_refresh);
    _plate.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  bool get _ready =>
      _make.text.trim().isNotEmpty &&
      _model.text.trim().isNotEmpty &&
      _year != null &&
      _plate.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!mounted || _saving || !_ready) {
      return;
    }
    final submitted = <String, dynamic>{
      'id': _vehicleId,
      'make': _make.text.trim(),
      'model': _model.text.trim(),
      'year': _year!,
      'plate': _plate.text.trim(),
    };
    setState(() => _saving = true);
    try {
      // Back from the documents page and Continue again: keep the photos
      // saved for this draft (driver-50).
      final previous = _drafted
          ? (await _store.list()).where((row) => row['id'] == _vehicleId)
          : const <Map<String, dynamic>>[];
      await _store.upsert({...?previous.firstOrNull, ...submitted});
      _drafted = true;
      if (!mounted) {
        return;
      }
      await pushSingle(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VehicleDocuments(
            vehicleId: submitted['id'] as String,
            make: submitted['make'] as String,
            model: submitted['model'] as String,
            year: submitted['year'] as String,
            plate: submitted['plate'] as String,
            store: _store,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.vehCouldNotSaveDraft),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickYear() async {
    if (!mounted || _saving || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final years = VehicleYearPolicy.choices(
          now: DateTime.now(),
          selected: _year,
        );
        return ListView(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Text(
                tr.year,
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final year in years)
              ListTile(
                title: Text(year),
                onTap: () => _popVehicleRoute(context, year),
              ),
          ],
        );
      },
    );
    if (picked == null ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _year = picked);
  }

  @override
  Widget build(BuildContext context) {
    final showModel = _make.text.trim().isNotEmpty;
    final showYear = showModel && _model.text.trim().isNotEmpty;
    final showPlate = showYear && _year != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text(
                  tr.vehRequirements,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr.vehRequirementsBody,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  tr.vehEnterInformation,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 18),
                _field(
                  label: tr.make,
                  child: TextField(
                    controller: _make,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _input(tr.searchByMake),
                  ),
                ),
                if (showModel) ...[
                  const SizedBox(height: 16),
                  _field(
                    label: tr.model,
                    child: TextField(
                      controller: _model,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _input(tr.searchByModel),
                    ),
                  ),
                ],
                if (showYear) ...[
                  const SizedBox(height: 16),
                  _field(
                    label: tr.year,
                    child: InkWell(
                      onTap: _pickYear,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: _input(tr.selectEllipsis),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _year ?? tr.selectEllipsis,
                                style: TextStyle(
                                  color: _year == null ? _muted : _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (showPlate) ...[
                  const SizedBox(height: 16),
                  _field(
                    label: tr.licensePlateNumber,
                    child: TextField(
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _input(''),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  tr.requiredMark,
                  style: TextStyle(
                    color: Color(0xFFB84F3D),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _ready && !_saving ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  disabledBackgroundColor: const Color(0xFFE8EAEC),
                  disabledForegroundColor: const Color(0xFFB0B6BA),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  tr.navContinue,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFB84F3D)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _input(String hint) {
    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
      filled: true,
      fillColor: const Color(0xFFF4F6F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _ink, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _line),
      ),
    );
  }
}

class VehicleDocuments extends StatefulWidget {
  const VehicleDocuments({
    super.key,
    this.vehicleId,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
    this.store,
    this.capturePhoto,
  });

  final String? vehicleId;
  final String make;
  final String model;
  final String year;
  final String plate;
  final LocalVehicleStore? store;

  /// Optional capture port for controlled frontend verification.
  final Future<XFile?> Function()? capturePhoto;

  @override
  State<VehicleDocuments> createState() => _VehicleDocumentsState();
}

class _VehicleDocumentsState extends State<VehicleDocuments> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _line = Color(0xFFE6E8EA);

  late final _store = widget.store ?? LocalVehicleStore();
  Map<String, dynamic>? _draft;
  bool _busy = false;
  bool _loading = true;
  bool _restoring = false;
  bool _restoreFailed = false;
  bool get _canEdit => !_loading && !_restoreFailed && !_busy && _draft != null;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (_restoring || _busy || !mounted) {
      return;
    }
    _restoring = true;
    setState(() {
      _loading = true;
      _restoreFailed = false;
    });
    try {
      final rows = await _store.list();
      final matching = rows.where((row) => row['id'] == widget.vehicleId);
      if (mounted) {
        setState(() {
          _draft = matching.isEmpty ? null : matching.first;
          _registrationDone = _draft?['registrationPhoto'] is String;
          _insuranceDone = _draft?['insurancePhoto'] is String;
          _loading = false;
        });
      }
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

  bool _registrationDone = false;
  bool _insuranceDone = false;

  String get _name => '${widget.make} ${widget.model}'.toUpperCase();

  Future<void> _openPhoto({
    required String title,
    required List<String> checks,
    required bool registration,
  }) async {
    if (!_canEdit) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _openPhotoOwned(
        title: title,
        checks: checks,
        registration: registration,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openPhotoOwned({
    required String title,
    required List<String> checks,
    required bool registration,
  }) async {
    final saved = await pushSingle<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (_) => _VehiclePhotoPage(
          title: title,
          checks: checks,
          capturePhoto: widget.capturePhoto,
        ),
      ),
    );
    if (saved == null || !mounted) {
      return;
    }
    final updated = {
      ..._draft!,
      (registration ? 'registrationPhoto' : 'insurancePhoto'): base64Encode(
        saved,
      ),
    };
    try {
      await _store.upsert(updated);
      if (!mounted) {
        return;
      }
      _draft = updated;
    } on VehiclePhotoBudgetExceeded catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr.vehPhotoCouldNotSave),
          ),
        );
      }
      return;
    }
    setState(() {
      if (registration) {
        _registrationDone = true;
      } else {
        _insuranceDone = true;
      }
    });
  }

  Future<void> _confirmRemove() async {
    if (!_canEdit ||
        widget.vehicleId == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await _removeOwned();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _removeOwned() async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr.vehRemoveDraftQ,
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                tr.vehRemovesNameAndPhotos(_name),
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                // Allow translated and enlarged labels to wrap.
                constraints: const BoxConstraints(
                  minWidth: double.infinity,
                  minHeight: 50,
                ),
                child: FilledButton(
                  onPressed: () => _popVehicleRoute(context, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tr.vehKeepVehicle,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                // Allow translated and enlarged labels to wrap.
                constraints: const BoxConstraints(
                  minWidth: double.infinity,
                  minHeight: 50,
                ),
                child: FilledButton(
                  onPressed: () => _popVehicleRoute(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC4473A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    tr.vehRemoveVehicle,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (remove == true &&
        mounted &&
        widget.vehicleId != null &&
        ModalRoute.of(context)?.isCurrent == true) {
      try {
        await _store.remove(widget.vehicleId!);
      } catch (_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr.vehCouldNotRemoveDraft),
            ),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      _popVehicleRoute<void>(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            _name,
            style: const TextStyle(
              color: _ink,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr.vehPhotosStayOnDevice,
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 22),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_restoreFailed) ...[
            Text(tr.vehCouldNotLoadDocuments),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _restore,
                child: Text(tr.retry),
              ),
            ),
          ],
          if (!_loading && !_restoreFailed && _draft == null)
            Text(tr.vehDraftNoLongerAvailable),
          _docRow(
            title: tr.vehRegistrationCertFront,
            note: _registrationDone
                ? tr.vehSavedLocallyNotVerified
                : tr.vehRecommendedNextStep,
            noteColor: _registrationDone
                ? const Color(0xFF1F7A4D)
                : const Color(0xFF3D5A80),
            onTap: !_canEdit
                ? null
                : () => _openPhoto(
                    title: tr.vehTakePhotoRegistration,
                    checks: [
                      tr.vehDocBlueBlackWhite,
                      tr.vehAllFourCorners,
                    ],
                    registration: true,
                  ),
          ),
          const Divider(height: 1, color: _line),
          _docRow(
            title: tr.vehInsuranceLetter,
            note: _insuranceDone ? tr.vehSavedLocallyNotVerified : null,
            noteColor: const Color(0xFF1F7A4D),
            onTap: !_canEdit
                ? null
                : () => _openPhoto(
                    title: tr.vehTakePhotoInsurance,
                    checks: [
                      tr.vehInsuranceShowsTaxi,
                      tr.vehInsuranceDatesVisible,
                    ],
                    registration: false,
                  ),
          ),
          for (final key in ['registrationPhoto', 'insurancePhoto'])
            if (_draft?[key] is String)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Image.memory(
                  base64Decode(_draft![key] as String),
                  height: 160,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      tr.vehSavedPhotoCannotDisplay,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: double.infinity,
              minHeight: 50,
            ),
            child: TextButton(
              onPressed: _canEdit ? _confirmRemove : null,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF4F6F7),
                foregroundColor: const Color(0xFFC4473A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                tr.vehRemoveVehicle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _docRow({
    required String title,
    required VoidCallback? onTap,
    String? note,
    Color? noteColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: TextStyle(
                        color: noteColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0B8BC)),
          ],
        ),
      ),
    );
  }
}

class _VehiclePhotoPage extends StatefulWidget {
  const _VehiclePhotoPage({
    required this.title,
    required this.checks,
    this.capturePhoto,
  });

  final String title;
  final List<String> checks;
  final Future<XFile?> Function()? capturePhoto;

  @override
  State<_VehiclePhotoPage> createState() => _VehiclePhotoPageState();
}

class _VehiclePhotoPageState extends State<_VehiclePhotoPage> {
  bool _taking = false;
  String? _captureError;
  bool get _ownsRoute => mounted && ModalRoute.of(context)?.isCurrent == true;

  static const Color _ink = Color(0xFF252E3A);

  Future<void> _take() async {
    if (_taking || !_ownsRoute) return;
    setState(() {
      _taking = true;
      _captureError = null;
    });
    try {
      final file =
          await (widget.capturePhoto?.call() ??
              ImagePicker().pickImage(
                source: ImageSource.camera,
                imageQuality: 60,
                maxWidth: 1024,
              ));
      if (!mounted || !_ownsRoute) {
        return;
      }
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (!mounted || !_ownsRoute) {
          return;
        }
        if (bytes.length > LocalVehicleStore.maxPhotoBytes) {
          setState(
            () => _captureError = tr.vehPhotoTooLarge,
          );
          return;
        }
        popOwned(context, bytes);
      }
    } catch (_) {
      if (!mounted || !_ownsRoute) {
        return;
      }
      // Bottom snackbars cover this page's retry button on compact screens.
      setState(
        () => _captureError = tr.vehCameraNotAvailable,
      );
    } finally {
      if (mounted) setState(() => _taking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 30,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 220,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE6E8EA)),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF8A949A),
                    size: 54,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  tr.vehBeforeSavingCheck,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                for (final check in widget.checks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: _ink)),
                        Expanded(
                          child: Text(
                            check,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_captureError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _captureError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _taking ? null : _take,
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _taking ? tr.takingPhoto : tr.takePhoto,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
