import 'package:movera/widgets/movera_dialog_theme.dart';
import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/core/sound/offer_alert.dart';
import 'package:flutter/material.dart';

class Accessibility extends StatefulWidget {
  const Accessibility({super.key, this.repository});
  final SettingsRepository? repository;

  @override
  State<Accessibility> createState() => _AccessibilityState();
}

class _AccessibilityState extends State<Accessibility> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  bool _flash = false;
  bool _vibration = false;

  late final _settings = widget.repository ?? SettingsRepository();
  bool _loading = true;
  bool _restoreFailed = false;
  bool _restoring = false;
  bool _saveFailed = false;
  bool _retryingSave = false;
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
      final data = await _settings.read('accessibility');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        if (data['flash'] is bool) {
          _flash = data['flash'] as bool;
        }
        if (data['vibration'] is bool) {
          _vibration = data['vibration'] as bool;
        }
        OfferAlertSettings.vibrate.value = _vibration;
      });
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
      await _settings.save('accessibility', {
        'flash': _flash,
        'vibration': _vibration,
      });
      saved = true;
      // G4-E6: offers (and the web push) vibrate only while this is on.
      OfferAlertSettings.vibrate.value = _vibration;
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
    _restoreSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => maybePopOwned(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        titleSpacing: 0,
        title: Text(
          tr.accessibility,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_saveFailed)
            TextButton(
              key: const ValueKey('settings-save-retry'),
              onPressed: _retryingSave ? null : _retrySave,
              child: Text(
                _retryingSave
                    ? tr.savingPreferencesEllipsis
                    : tr.changesNotSavedRetry,
              ),
            ),
          if (_restoreFailed)
            TextButton(
              onPressed: _restoreSettings,
              child: Text(tr.couldNotLoadSavedPreferencesRetry),
            ),
          Text(tr.localDemoPreferencesSavedOnThis),
          _tile(
            title: tr.hearing,
            detail: tr.tellRidersIfYouAreDeaf,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB0B8BC),
            ),
            onTap: () {
              if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
              showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  return MoveraDialogTheme(
                    child: AlertDialog(
                      backgroundColor: Colors.white,
                      title: Text(tr.hearing),
                      content: Text(tr.demoPreviewNoInformationIsShared),
                      actions: [
                        TextButton(
                          onPressed: () => popOwned(dialogContext),
                          child: Text(tr.notNow),
                        ),
                        FilledButton(
                          onPressed: () => popOwned(dialogContext),
                          style: FilledButton.styleFrom(backgroundColor: _ink),
                          child: Text(tr.closePreview),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 10),
          _tile(
            title: tr.flashForRequests,
            detail: tr.screenFlashesWhenRequestArrives,
            trailing: Semantics(
              container: true,
              label: tr.flashForRequests,
              enabled: _canEdit,
              toggled: _flash,
              onTap: !_canEdit
                  ? null
                  : () {
                      if (!_canEdit) return;
                      setState(() => _flash = !_flash);
                      _persistSettings();
                    },
              child: ExcludeSemantics(
                child: Switch.adaptive(
                  value: _flash,
                  activeTrackColor: _ink,
                  onChanged: !_canEdit
                      ? null
                      : (value) {
                          if (!_canEdit) return;
                          setState(() => _flash = value);
                          _persistSettings();
                        },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _tile(
            title: tr.vibrationForRequests,
            detail: tr.phoneVibratesWhenRequestArrives,
            trailing: Semantics(
              container: true,
              label: tr.vibrationForRequests,
              enabled: _canEdit,
              toggled: _vibration,
              onTap: !_canEdit
                  ? null
                  : () {
                      if (!_canEdit) return;
                      setState(() => _vibration = !_vibration);
                      _persistSettings();
                    },
              child: ExcludeSemantics(
                child: Switch.adaptive(
                  value: _vibration,
                  activeTrackColor: _ink,
                  onChanged: !_canEdit
                      ? null
                      : (value) {
                          if (!_canEdit) return;
                          setState(() => _vibration = value);
                          _persistSettings();
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required String detail,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
