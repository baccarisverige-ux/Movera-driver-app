import 'package:movera/core/l10n/driver_l10n.dart';
import 'package:movera/widgets/owned_external_action.dart';
import 'package:movera/widgets/owned_route_exit.dart';
import 'package:flutter/material.dart';
import 'package:movera/core/settings/settings_repository.dart';
import 'package:movera/constants/appcolors.dart';
import 'package:movera/constants/appfontweight.dart';
import 'package:movera/widgets/custom_text_widget.dart';
import 'package:movera/widgets/responsive_size.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({
    super.key,
    this.repository,
    this.launchDialer,
  });
  final Future<bool> Function(Uri)? launchDialer;
  final SettingsRepository? repository;

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContact {
  const _EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  final String name;
  final String phone;
  final String relation;
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  static const Color _ink = Color(0xFF252E3A);
  static const Color _muted = Color(0xFF7D898F);

  final _dialAction = OwnedExternalAction();
  final List<_EmergencyContact> _contacts = [
    const _EmergencyContact(
      name: 'Emergency services — 112',
      phone: '112',
      relation: 'Emergency',
    ),
  ];

  late final _settings = widget.repository ?? SettingsRepository();
  bool _loading = true;
  bool _restoring = false;
  bool _restoreFailed = false;
  bool _adding = false;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    if (_restoring || !mounted) return;
    _restoring = true;
    setState(() {
      _loading = true;
      _restoreFailed = false;
    });
    try {
      final data = await _settings.read('contacts');
      final rows = data['rows'];
      if (mounted) {
        setState(() {
          if (rows is List) {
            _contacts.removeWhere((c) => c.phone != '112');
            for (final row in rows) {
              if (row is Map &&
                  row['name'] is String &&
                  row['phone'] is String &&
                  _validPhone(row['phone'] as String)) {
                _contacts.add(
                  _EmergencyContact(
                    name: row['name'] as String,
                    phone: row['phone'] as String,
                    relation: row['relation'] is String
                        ? row['relation'] as String
                        : tr.trustedContact,
                  ),
                );
              }
            }
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoreFailed = true;
        });
      }
    } finally {
      _restoring = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool _validPhone(String phone) =>
      RegExp(r'^\+?[0-9]{7,15}$')
          .hasMatch(phone.replaceAll(RegExp(r'[\s()-]'), '')) ||
      phone == '112';
  Future<void> _addContact() async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _loading ||
        _restoreFailed ||
        _adding) {
      return;
    }
    setState(() => _adding = true);
    try {
      final created = await showModalBottomSheet<_EmergencyContact>(
        context: context,
        isScrollControlled: true,
        // A swipe closes BottomSheet directly, bypassing the composer's
        // PopScope. Keep Back/barrier dismissal, which respect pending saves.
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ContactComposer(
          validPhone: _validPhone,
          onSave: (contact) async {
            final number = contact.phone.replaceAll(RegExp(r'[\s()-]'), '');
            if (_contacts.any(
              (existing) =>
                  existing.phone.replaceAll(RegExp(r'[\s()-]'), '') == number,
            )) {
              throw const FormatException(
                'This number is already in your contacts.',
              );
            }
            final updated = [..._contacts, contact];
            await _settings.save('contacts', {
              'rows': updated
                  .where((c) => c.phone != '112')
                  .map(
                    (c) => {
                      'name': c.name,
                      'phone': c.phone,
                      'relation': c.relation,
                    },
                  )
                  .toList(),
            });
          },
        ),
      );
      if (created != null && mounted) {
        setState(() => _contacts.add(created));
      }
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  Future<void> _call(_EmergencyContact contact) async {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final uri = Uri.parse(
      'tel:${contact.phone.replaceAll(RegExp(r'[^0-9+]'), '')}',
    );
    final opened = await _dialAction.run(
      context,
      () => widget.launchDialer?.call(uri) ?? launchUrl(uri),
    );
    if (opened == false &&
        mounted &&
        ModalRoute.of(context)?.isCurrent == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr.dialerIsUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColor.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: tr.back,
          onPressed: () => popOwned(context),
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColor.title,
            size: ResSize.h * 18,
          ),
        ),
        centerTitle: true,
        title: TextWidget(
          text: tr.emergencyContacts,
          color: AppColor.title,
          fontSize: 16,
          fontWeight: fwMedium,
        ),
        actions: [
          IconButton(
            tooltip: tr.addTrustedContact,
            key: const ValueKey<String>('add-emergency-contact'),
            onPressed: _loading || _restoreFailed || _adding
                ? null
                : _addContact,
            icon: const Icon(Icons.add_rounded, color: Color(0xFF19865C)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_restoreFailed)
            TextButton(
              onPressed: _restore,
              child: Text(tr.couldNotLoadTrustedContactsRetry),
            ),
          Text(
            tr.trustedContactsStayOnThisDevice,
            style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          for (final contact in _contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: const Color(0xFFF7FBF9),
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  title: Text(
                    contact.name,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text('${contact.relation} · ${contact.phone}'),
                  trailing: IconButton(
                    tooltip: tr.callName(contact.name),
                    icon: const Icon(Icons.phone_outlined),
                    onPressed: () => _call(contact),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactComposer extends StatefulWidget {
  const _ContactComposer({required this.validPhone, required this.onSave});
  final bool Function(String) validPhone;
  final Future<void> Function(_EmergencyContact) onSave;
  @override
  State<_ContactComposer> createState() => _ContactComposerState();
}

class _ContactComposerState extends State<_ContactComposer> {
  final _form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final relation = TextEditingController(text: 'Family');
  bool _saving = false;
  String? _saveError;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final contact = _EmergencyContact(
      name: name.text.trim(),
      phone: phone.text.trim(),
      relation: relation.text.trim().isEmpty
          ? tr.trustedContact
          : relation.text.trim(),
    );
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onSave(contact);
      if (mounted) popOwned(context, contact);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = error is FormatException
              ? error.message
              : tr.contactCouldNotBeSavedRetry;
        });
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr.addTrustedContact,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: name,
                    enabled: !_saving,
                    decoration: InputDecoration(labelText: tr.name),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? tr.enterName
                        : null,
                  ),
                  TextFormField(
                    controller: phone,
                    enabled: !_saving,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: tr.phone),
                    validator: (value) => widget.validPhone(value?.trim() ?? '')
                        ? null
                        : tr.enterValidPhoneNumber,
                  ),
                  TextFormField(
                    controller: relation,
                    enabled: !_saving,
                    decoration: InputDecoration(labelText: tr.relation),
                  ),
                  const SizedBox(height: 16),
                  if (_saveError != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _saveError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF19865C),
                    ),
                    child: Text(_saving ? tr.savingContactEllipsis : tr.saveContact),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
