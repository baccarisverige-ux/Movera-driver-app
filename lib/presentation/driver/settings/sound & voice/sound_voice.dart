import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:flutter/material.dart';

class SoundAndVoice extends StatefulWidget {
  const SoundAndVoice({super.key, this.repository});
  final SettingsRepository? repository;

  @override
  State<SoundAndVoice> createState() => _SoundAndVoiceState();
}

class _SoundAndVoiceState extends State<SoundAndVoice> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);
  static const Color _line = Color(0xFFE6E8EA);

  double generalVolume = 0.35;
  bool alwaysPlayRequests = true;
  bool voiceNavigation = true;
  bool readRiderMessages = false;

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
      final data = await _settings.read('sound');
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        if (data['generalVolume'] is num) {
          generalVolume = (data['generalVolume'] as num).toDouble().clamp(
            0.0,
            1.0,
          );
        }
        if (data['alwaysPlayRequests'] is bool) {
          alwaysPlayRequests = data['alwaysPlayRequests'] as bool;
        }
        if (data['voiceNavigation'] is bool) {
          voiceNavigation = data['voiceNavigation'] as bool;
        }
        if (data['readRiderMessages'] is bool) {
          readRiderMessages = data['readRiderMessages'] as bool;
        }
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
      await _settings.save('sound', {
        'generalVolume': generalVolume,
        'alwaysPlayRequests': alwaysPlayRequests,
        'voiceNavigation': voiceNavigation,
        'readRiderMessages': readRiderMessages,
      });
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
          tr.soundVoice,
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
          Text(
            tr.localDemoPreferencesSavedOnThis,
          ),
          _card(
            children: [
              Text(
                tr.volume,
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Slider(
                label: tr.generalVolume,
                value: generalVolume,
                activeColor: _ink,
                semanticFormatterCallback: (value) =>
                    '${(value * 100).round()}%',
                onChanged: !_canEdit
                    ? null
                    : (value) {
                        if (!_canEdit) return;
                        setState(() => generalVolume = value);
                        _persistSettings();
                      },
              ),
              _switchRow(
                tr.alwaysPlayTripRequests,
                tr.playsEvenWhenPhoneIsSilent,
                alwaysPlayRequests,
                (value) {
                  if (!_canEdit) return;
                  setState(() => alwaysPlayRequests = value);
                  _persistSettings();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _card(
            children: [
              Text(
                tr.voice,
                style: TextStyle(
                  color: _ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _switchRow(
                tr.voiceNavigation,
                tr.spokenTurnsWhileYouDrive,
                voiceNavigation,
                (value) {
                  if (!_canEdit) return;
                  setState(() => voiceNavigation = value);
                  _persistSettings();
                },
              ),
              _switchRow(
                tr.readRiderMessages,
                tr.readsNewChatMessagesAloud,
                readRiderMessages,
                (value) {
                  if (!_canEdit) return;
                  setState(() => readRiderMessages = value);
                  _persistSettings();
                },
              ),
              const SizedBox(height: 8),
              _test(tr.testAlerts, _onTestAlerts),
              const SizedBox(height: 8),
              _test(tr.testVoice, _onTestVoice),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _switchRow(
    String title,
    String detail,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: title,
            enabled: _canEdit,
            toggled: value,
            onTap: _canEdit ? () => onChanged(!value) : null,
            child: ExcludeSemantics(
              child: Switch.adaptive(
                value: value,
                activeTrackColor: _ink,
                onChanged: _canEdit ? onChanged : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _test(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          side: const BorderSide(color: _line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  void _onTestAlerts() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr.playingAlertSoundMock)));
  }

  void _onTestVoice() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr.playingVoiceSoundMock)));
  }
}
