import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.api, required this.session});
  final ApiClient api;
  final SessionController session;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _company = {};
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _series = [];
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _terms = [];

  String get _tenantId => widget.session.tenantId ?? '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = _tenantId;
      final r = await Future.wait([
        widget.api.get('/companies/$id'),
        widget.api.get('/settings'),
        widget.api.get('/settings/series'),
        widget.api.get('/companies/$id/members'),
        widget.api.get('/companies/$id/branches'),
        widget.api.get('/terms-templates'),
      ]);
      if (!mounted) return;
      setState(() {
        _company = Map<String, dynamic>.from(r[0] as Map);
        _settings = Map<String, dynamic>.from(r[1] as Map);
        _series = _rows(r[2]);
        _members = _rows(r[3]);
        _branches = _rows(r[4]);
        _terms = _rows(r[5]);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Settings',
        subtitle:
            'Company, branches, GST credentials, numbering, terms, team, security and backup.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(60), child: CircularProgressIndicator())
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : Column(children: [
                    SectionCard(
                      child: TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabs: const [
                          Tab(text: 'Company'),
                          Tab(text: 'GST & Integrations'),
                          Tab(text: 'Numbering'),
                          Tab(text: 'Terms templates'),
                          Tab(text: 'Team'),
                          Tab(text: 'Security'),
                          Tab(text: 'Data & Backup'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AnimatedBuilder(
                      animation: _tabs,
                      builder: (context, _) => switch (_tabs.index) {
                        0 => _companyTab(),
                        1 => _taxTab(),
                        2 => _numberingTab(),
                        3 => _termsTab(),
                        4 => _teamTab(),
                        5 => _securityTab(),
                        _ => _dataTab(),
                      },
                    ),
                  ]),
      );

  Widget _companyTab() {
    final legal =
        TextEditingController(text: _company['legal_name']?.toString() ?? '');
    final trade =
        TextEditingController(text: _company['trade_name']?.toString() ?? '');
    final gstin =
        TextEditingController(text: _company['gstin']?.toString() ?? '');
    final pan = TextEditingController(text: _company['pan']?.toString() ?? '');
    var taxMode = _company['tax_mode']?.toString() ?? 'NON_GST';
    final logoUrl = _settings['logo_url']?.toString();
    return Column(children: [
      SectionCard(
        title: 'Legal business profile',
        child: StatefulBuilder(
          builder: (context, setLocal) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                  width: 330,
                  child: TextField(
                      controller: legal,
                      decoration:
                          const InputDecoration(labelText: 'Legal name'))),
              SizedBox(
                  width: 330,
                  child: TextField(
                      controller: trade,
                      decoration:
                          const InputDecoration(labelText: 'Trade name'))),
              SizedBox(
                  width: 230,
                  child: TextField(
                      controller: gstin,
                      maxLength: 15,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'GSTIN', counterText: ''))),
              SizedBox(
                  width: 200,
                  child: TextField(
                      controller: pan,
                      maxLength: 10,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'PAN', counterText: ''))),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: taxMode,
                  decoration: const InputDecoration(labelText: 'Tax mode'),
                  items: const [
                    DropdownMenuItem(value: 'NON_GST', child: Text('Non-GST')),
                    DropdownMenuItem(
                        value: 'GST_REGULAR', child: Text('GST Regular')),
                    DropdownMenuItem(
                        value: 'GST_COMPOSITION',
                        child: Text('GST Composition')),
                  ],
                  onChanged: (v) => setLocal(() => taxMode = v!),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                try {
                  final data =
                      await widget.api.put('/companies/$_tenantId', body: {
                    'legal_name': legal.text.trim(),
                    'trade_name':
                        trade.text.trim().isEmpty ? null : trade.text.trim(),
                    'gstin': gstin.text.trim().isEmpty
                        ? null
                        : gstin.text.trim().toUpperCase(),
                    'pan': pan.text.trim().isEmpty
                        ? null
                        : pan.text.trim().toUpperCase(),
                    'tax_mode': taxMode,
                    'financial_year_start': _company['financial_year_start'],
                  });
                  if (mounted) {
                    setState(() =>
                        _company = Map<String, dynamic>.from(data as Map));
                    showMessage(context, 'Company profile updated.');
                  }
                } catch (e) {
                  if (mounted) showMessage(context, e.toString(), error: true);
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save company profile'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      SectionCard(
        title: 'Company logo',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (logoUrl != null && logoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Image.network(logoUrl,
                  height: 72,
                  errorBuilder: (_, __, ___) => const Text(
                      'Logo URL is stored but could not be previewed.')),
            )
          else
            const Text(
                'No logo uploaded yet. PNG, JPG, GIF or WebP up to 5 MB.',
                style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: _uploadLogo,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload logo')),
        ]),
      ),
      const SizedBox(height: 14),
      SectionCard(
        title: 'Branches / additional GST locations',
        trailing: TextButton.icon(
            onPressed: () => _editBranch(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add branch')),
        child: _branches.isEmpty
            ? const Text(
                'No additional branches. Warehouses/godowns are managed under Inventory.',
                style: TextStyle(color: AppColors.muted))
            : Column(
                children: _branches
                    .map((b) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${b['name'] ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${b['gstin'] ?? 'No GSTIN'} • ${b['is_active'] == false ? 'Inactive' : 'Active'}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _editBranch(b);
                              if (v == 'toggle') _toggleBranch(b);
                              if (v == 'delete') _deleteBranch(b);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(b['is_active'] == false
                                      ? 'Activate'
                                      : 'Deactivate')),
                              const PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ))
                    .toList(),
              ),
      ),
    ]);
  }

  Future<void> _uploadLogo() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        withData: true);
    if (picked == null || picked.files.isEmpty) return;
    try {
      await widget.api.upload('/settings/logo', picked.files.first);
      if (mounted) {
        showMessage(context, 'Logo uploaded.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _editBranch([Map<String, dynamic>? existing]) async {
    final address = existing?['address'] is Map
        ? Map<String, dynamic>.from(existing!['address'] as Map)
        : <String, dynamic>{};
    final name =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final gstin =
        TextEditingController(text: existing?['gstin']?.toString() ?? '');
    final street =
        TextEditingController(text: address['street']?.toString() ?? '');
    final city = TextEditingController(text: address['city']?.toString() ?? '');
    final state =
        TextEditingController(text: address['state']?.toString() ?? '');
    final stateCode =
        TextEditingController(text: address['state_code']?.toString() ?? '');
    final pincode =
        TextEditingController(text: address['pincode']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add branch' : 'Edit branch'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Branch name *')),
              const SizedBox(height: 10),
              TextField(
                  controller: gstin,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'GSTIN')),
              const SizedBox(height: 10),
              TextField(
                  controller: street,
                  decoration: const InputDecoration(labelText: 'Street *')),
              const SizedBox(height: 10),
              TextField(
                  controller: city,
                  decoration: const InputDecoration(labelText: 'City *')),
              const SizedBox(height: 10),
              TextField(
                  controller: state,
                  decoration: const InputDecoration(labelText: 'State *')),
              const SizedBox(height: 10),
              TextField(
                  controller: stateCode,
                  maxLength: 2,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'State code *', counterText: '')),
              const SizedBox(height: 10),
              TextField(
                  controller: pincode,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Pincode *', counterText: '')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if ([name, street, city, state, stateCode, pincode]
                      .any((c) => c.text.trim().isEmpty) ||
                  stateCode.text.trim().length != 2 ||
                  pincode.text.trim().length != 6) {
                showMessage(
                    context, 'Name and a complete Indian address are required.',
                    error: true);
                return;
              }
              final body = {
                'name': name.text.trim(),
                'gstin': gstin.text.trim().isEmpty
                    ? null
                    : gstin.text.trim().toUpperCase(),
                'address': {
                  'street': street.text.trim(),
                  'city': city.text.trim(),
                  'state': state.text.trim(),
                  'state_code': stateCode.text.trim(),
                  'pincode': pincode.text.trim(),
                  'country': 'India',
                },
              };
              try {
                if (existing == null) {
                  await widget.api
                      .post('/companies/$_tenantId/branches', body: body);
                } else {
                  await widget.api.put(
                      '/companies/$_tenantId/branches/${existing['id']}',
                      body: body);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  showMessage(context, e.toString(), error: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in [name, gstin, street, city, state, stateCode, pincode]) {
      c.dispose();
    }
    if (ok == true) _load();
  }

  Future<void> _toggleBranch(Map<String, dynamic> branch) async {
    try {
      await widget.api.put('/companies/$_tenantId/branches/${branch['id']}',
          body: {'is_active': branch['is_active'] == false});
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteBranch(Map<String, dynamic> branch) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete branch?'),
            content: Text(
                'Delete ${branch['name'] ?? 'this branch'}? Branches with stock history must be deactivated instead.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await widget.api.delete('/companies/$_tenantId/branches/${branch['id']}');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _taxTab() {
    final origin = TextEditingController(
        text: _settings['origin_state_code']?.toString() ?? '');
    final upi =
        TextEditingController(text: _settings['upi_id']?.toString() ?? '');
    final einUser = TextEditingController(
        text: _settings['e_invoice_username']?.toString() ?? '');
    final ewayUser = TextEditingController(
        text: _settings['e_way_bill_username']?.toString() ?? '');
    final einPass = TextEditingController();
    final ewayPass = TextEditingController();
    var einvoice = _settings['e_invoicing_enabled'] == true;
    return SectionCard(
      title: 'GST and statutory integrations',
      child: StatefulBuilder(
        builder: (context, setLocal) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 180,
                child: TextField(
                    controller: origin,
                    maxLength: 2,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Origin state code', counterText: ''))),
            SizedBox(
                width: 260,
                child: TextField(
                    controller: upi,
                    decoration: const InputDecoration(labelText: 'UPI ID'))),
            SizedBox(
                width: 280,
                child: TextField(
                    controller: einUser,
                    decoration: const InputDecoration(
                        labelText: 'E-invoice username'))),
            SizedBox(
                width: 280,
                child: TextField(
                    controller: einPass,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'New e-invoice password',
                        helperText: 'Leave blank to keep current'))),
            SizedBox(
                width: 280,
                child: TextField(
                    controller: ewayUser,
                    decoration: const InputDecoration(
                        labelText: 'E-way bill username'))),
            SizedBox(
                width: 280,
                child: TextField(
                    controller: ewayPass,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'New e-way password',
                        helperText: 'Leave blank to keep current'))),
          ]),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable e-invoicing integration'),
            subtitle: const Text(
                'Credentials remain encrypted on the backend and passwords are never read back.'),
            value: einvoice,
            onChanged: (v) => setLocal(() => einvoice = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              try {
                final body = <String, dynamic>{
                  'origin_state_code': origin.text.trim(),
                  'upi_id': upi.text.trim().isEmpty ? null : upi.text.trim(),
                  'e_invoicing_enabled': einvoice,
                  'e_invoice_username':
                      einUser.text.trim().isEmpty ? null : einUser.text.trim(),
                  'e_way_bill_username': ewayUser.text.trim().isEmpty
                      ? null
                      : ewayUser.text.trim(),
                };
                if (einPass.text.isNotEmpty) {
                  body['e_invoice_password'] = einPass.text;
                }
                if (ewayPass.text.isNotEmpty) {
                  body['e_way_bill_password'] = ewayPass.text;
                }
                final data = await widget.api.put('/settings', body: body);
                if (mounted) {
                  setState(
                      () => _settings = Map<String, dynamic>.from(data as Map));
                  showMessage(context, 'GST integration settings updated.');
                }
              } catch (e) {
                if (mounted) showMessage(context, e.toString(), error: true);
              }
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save tax settings'),
          ),
        ]),
      ),
    );
  }

  Widget _numberingTab() => SectionCard(
        title: 'Document numbering series',
        trailing: TextButton.icon(
            onPressed: _createSeries,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add series')),
        child: _series.isEmpty
            ? const Text('No series returned.')
            : Column(
                children: _series
                    .map((s) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                              child: Icon(Icons.numbers_rounded)),
                          title: Text(s['document_type']?.toString() ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              'Preview: ${s['prefix'] ?? ''}${(s['next_number'] ?? 1).toString().padLeft((s['padding_digits'] as num?)?.toInt() ?? 4, '0')}${s['suffix'] ?? ''}'),
                          trailing: IconButton(
                              onPressed: () => _editSeries(s),
                              icon: const Icon(Icons.edit_outlined)),
                        ))
                    .toList(),
              ),
      );

  Future<void> _createSeries() async {
    const types = [
      'INVOICE',
      'BILL',
      'PAYMENT',
      'JOURNAL',
      'RECEIPT',
      'DISBURSEMENT',
      'CREDIT_NOTE',
      'DEBIT_NOTE',
      'PURCHASE_ORDER',
      'SALES_ORDER',
      'DELIVERY_CHALLAN',
      'PROFORMA_INVOICE',
      'SALES_RETURN',
      'PURCHASE_RETURN',
    ];
    var type = types.first;
    final prefix = TextEditingController();
    final next = TextEditingController(text: '1');
    final suffix = TextEditingController();
    final padding = TextEditingController(text: '4');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('New numbering series'),
          content: SizedBox(
            width: 520,
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: 480,
                child: DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Document type'),
                  items: types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setLocal(() => type = v!),
                ),
              ),
              SizedBox(
                  width: 220,
                  child: TextField(
                      controller: prefix,
                      decoration: const InputDecoration(labelText: 'Prefix'))),
              SizedBox(
                  width: 160,
                  child: TextField(
                      controller: next,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Next number'))),
              SizedBox(
                  width: 180,
                  child: TextField(
                      controller: suffix,
                      decoration: const InputDecoration(labelText: 'Suffix'))),
              SizedBox(
                  width: 150,
                  child: TextField(
                      controller: padding,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Padding digits'))),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.post('/settings/series', body: {
                    'document_type': type,
                    'prefix': prefix.text,
                    'next_number': int.tryParse(next.text) ?? 1,
                    'suffix': suffix.text.isEmpty ? null : suffix.text,
                    'padding_digits': int.tryParse(padding.text) ?? 4,
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    showMessage(context, e.toString(), error: true);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    for (final c in [prefix, next, suffix, padding]) {
      c.dispose();
    }
    if (saved == true) _load();
  }

  Future<void> _editSeries(Map<String, dynamic> s) async {
    final prefix = TextEditingController(text: s['prefix']?.toString() ?? '');
    final next =
        TextEditingController(text: s['next_number']?.toString() ?? '1');
    final suffix = TextEditingController(text: s['suffix']?.toString() ?? '');
    final padding =
        TextEditingController(text: s['padding_digits']?.toString() ?? '4');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Numbering • ${s['document_type']}'),
        content: SizedBox(
          width: 520,
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 220,
                child: TextField(
                    controller: prefix,
                    decoration: const InputDecoration(labelText: 'Prefix'))),
            SizedBox(
                width: 160,
                child: TextField(
                    controller: next,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Next number'))),
            SizedBox(
                width: 180,
                child: TextField(
                    controller: suffix,
                    decoration: const InputDecoration(labelText: 'Suffix'))),
            SizedBox(
                width: 150,
                child: TextField(
                    controller: padding,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Padding digits'))),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await widget.api.put('/settings/series/${s['id']}', body: {
                  'prefix': prefix.text,
                  'next_number': int.tryParse(next.text) ?? 1,
                  'suffix': suffix.text.isEmpty ? null : suffix.text,
                  'padding_digits': int.tryParse(padding.text) ?? 4,
                  'is_active': true,
                });
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  showMessage(context, e.toString(), error: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in [prefix, next, suffix, padding]) {
      c.dispose();
    }
    if (saved == true) _load();
  }

  Widget _termsTab() => SectionCard(
        title: 'Invoice / document terms templates',
        trailing: TextButton.icon(
            onPressed: () => _editTerms(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New template')),
        child: _terms.isEmpty
            ? const Text('No terms templates yet.')
            : Column(
                children: _terms
                    .map((t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${t['name'] ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(t['is_preset'] == true
                              ? 'Preset'
                              : (t['is_active'] == false
                                  ? 'Inactive'
                                  : 'Custom')),
                          trailing: t['is_preset'] == true
                              ? null
                              : PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'edit') _editTerms(t);
                                    if (v == 'delete') _deleteTerms(t);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(
                                        value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                        ))
                    .toList(),
              ),
      );

  Future<void> _editTerms([Map<String, dynamic>? existing]) async {
    final name =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final content =
        TextEditingController(text: existing?['content']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            existing == null ? 'New terms template' : 'Edit terms template'),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(
                controller: content,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Content')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty || content.text.trim().isEmpty) {
                showMessage(context, 'Name and content are required.',
                    error: true);
                return;
              }
              try {
                final body = {
                  'name': name.text.trim(),
                  'content': content.text.trim()
                };
                if (existing == null) {
                  await widget.api.post('/terms-templates', body: body);
                } else {
                  await widget.api
                      .put('/terms-templates/${existing['id']}', body: body);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  showMessage(context, e.toString(), error: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    content.dispose();
    if (saved == true) _load();
  }

  Future<void> _deleteTerms(Map<String, dynamic> t) async {
    try {
      await widget.api.delete('/terms-templates/${t['id']}');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _teamTab() => SectionCard(
        title: 'Team & roles',
        trailing: TextButton.icon(
            onPressed: _inviteMember,
            icon: const Icon(Icons.person_add_alt_rounded),
            label: const Text('Invite')),
        child: _members.isEmpty
            ? const Text('No members returned.')
            : Column(
                children: _members
                    .map((m) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                              child: Text((m['full_name']?.toString() ??
                                      m['email']?.toString() ??
                                      'U')
                                  .substring(0, 1)
                                  .toUpperCase())),
                          title: Text(
                              m['full_name']?.toString() ??
                                  m['email']?.toString() ??
                                  '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                              '${m['email'] ?? ''} • ${m['is_active'] == false ? 'Inactive' : 'Active'}'),
                          trailing: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(
                                    label: Text(
                                        m['role']?.toString() ?? 'member')),
                                PopupMenuButton<String>(
                                  onSelected: (v) {
                                    if (v == 'role') _changeRole(m);
                                    if (v == 'remove') _removeMember(m);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'role',
                                        child: Text('Change role')),
                                    PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove member')),
                                  ],
                                ),
                              ]),
                        ))
                    .toList(),
              ),
      );

  Future<void> _inviteMember() async {
    final email = TextEditingController();
    var role = 'accountant';
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Invite team member'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'owner', child: Text('Owner')),
                  DropdownMenuItem(
                      value: 'accountant', child: Text('Accountant')),
                  DropdownMenuItem(
                      value: 'salesperson', child: Text('Salesperson')),
                  DropdownMenuItem(value: 'auditor', child: Text('Auditor')),
                ],
                onChanged: (v) => setLocal(() => role = v!),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.post('/companies/$_tenantId/invite',
                      body: {'email': email.text.trim(), 'role': role});
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    showMessage(context, e.toString(), error: true);
                  }
                }
              },
              child: const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
    email.dispose();
    if (sent == true) {
      showMessage(context, 'Invitation created.');
      _load();
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member) async {
    var role = member['role']?.toString() ?? 'accountant';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Change role'),
          content: DropdownButtonFormField<String>(
            initialValue: role,
            items: const [
              DropdownMenuItem(value: 'owner', child: Text('Owner')),
              DropdownMenuItem(value: 'accountant', child: Text('Accountant')),
              DropdownMenuItem(
                  value: 'salesperson', child: Text('Salesperson')),
              DropdownMenuItem(value: 'auditor', child: Text('Auditor')),
            ],
            onChanged: (v) => setLocal(() => role = v!),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.put(
                      '/companies/$_tenantId/members/${member['user_id']}',
                      body: {'role': role, 'is_active': true});
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    showMessage(context, e.toString(), error: true);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _removeMember(Map<String, dynamic> member) async {
    try {
      await widget.api
          .delete('/companies/$_tenantId/members/${member['user_id']}');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _securityTab() => Column(children: [
        SectionCard(title: 'Password', child: _ChangePassword(api: widget.api)),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Two-factor authentication',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              widget.session.totpEnabled
                  ? 'Authenticator protection is enabled for this account.'
                  : 'Add TOTP authenticator protection to the account.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            if (widget.session.totpEnabled)
              OutlinedButton.icon(
                  onPressed: _disable2fa,
                  icon: const Icon(Icons.phonelink_erase_rounded),
                  label: const Text('Disable 2FA'))
            else
              FilledButton.icon(
                  onPressed: _enable2fa,
                  icon: const Icon(Icons.phonelink_lock_rounded),
                  label: const Text('Set up 2FA')),
          ]),
        ),
      ]);

  Future<void> _enable2fa() async {
    try {
      final data = Map<String, dynamic>.from(
          await widget.api.post('/auth/2fa/enable') as Map);
      if (!mounted) return;
      final code = TextEditingController();
      Uint8List? bytes;
      final qr = data['qr_code']?.toString();
      if (qr != null) {
        try {
          bytes = base64Decode(qr.contains(',') ? qr.split(',').last : qr);
        } catch (_) {}
      }
      final verified = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set up authenticator'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (bytes != null) Image.memory(bytes, width: 190, height: 190),
              const SizedBox(height: 10),
              SelectableText('Secret: ${data['secret'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Current 6-digit code')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.post('/auth/2fa/verify',
                      body: {'token': code.text.trim()});
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    showMessage(context, e.toString(), error: true);
                  }
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      );
      code.dispose();
      if (verified == true) {
        widget.session.updateTotpEnabled(true);
        if (mounted) showMessage(context, 'Two-factor authentication enabled.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _disable2fa() async {
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: TextField(
            controller: code,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Current authenticator code')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await widget.api.post('/auth/2fa/disable',
                    body: {'token': code.text.trim()});
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted) {
                  showMessage(context, e.toString(), error: true);
                }
              }
            },
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    code.dispose();
    if (ok == true) {
      widget.session.updateTotpEnabled(false);
      if (mounted) showMessage(context, '2FA disabled.');
    }
  }

  Widget _dataTab() => Column(children: [
        SectionCard(
          title: 'Company backup',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Generate a tenant-scoped JSON backup. Integration passwords, secrets and credentials are intentionally excluded.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: _prepareBackup,
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Prepare backup & copy JSON')),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Restore from backup',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Restore a previously exported JSON backup into this company. Existing IDs are skipped; this is not a destructive overwrite of current books.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: _restoreBackup,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restore JSON backup')),
          ]),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Purge company data',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'Requests an email OTP, then permanently purges transactional and master data for this tenant. This cannot be undone.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
                onPressed: _purge,
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Request purge OTP')),
          ]),
        ),
        const SizedBox(height: 14),
        const SectionCard(
          title: 'Migration safety',
          child: Text(
              'Use Import & Migration for Vyapar, Tally and CSV restore workflows. CSV migration validates totals and references in dry-run mode before any rows are written.'),
        ),
      ]);

  Future<void> _prepareBackup() async {
    try {
      final data = await widget.api.get('/companies/$_tenantId/export');
      final encoded = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: encoded));
      if (mounted) {
        showMessage(context,
            'Backup JSON copied to clipboard (${encoded.length} characters).');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _restoreBackup() async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['json'], withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Restore backup?'),
            content: const Text(
                'Existing records with the same IDs are skipped. New rows are inserted in backend dependency order.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Restore')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    try {
      final raw = picked.files.first.bytes != null
          ? utf8.decode(picked.files.first.bytes!)
          : throw ApiException('The selected file could not be read.');
      final payload = jsonDecode(raw);
      await widget.api.post('/companies/$_tenantId/import', body: payload);
      if (mounted) showMessage(context, 'Backup restore completed.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _purge() async {
    final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Purge this company?'),
            content: const Text(
                'An OTP will be emailed to the owner. After verification, transactional and master data for this tenant are permanently deleted.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Request OTP')),
            ],
          ),
        ) ??
        false;
    if (!proceed) return;
    try {
      final result = await widget.api.post('/purge/request');
      if (!mounted) return;
      final otp = TextEditingController();
      final hint = result is Map ? result['detail']?.toString() : 'OTP sent.';
      final verified = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter purge OTP'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(hint ?? '', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(
                controller: otp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '8-digit OTP')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api
                      .post('/purge/verify', body: {'otp': otp.text.trim()});
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) {
                    showMessage(context, e.toString(), error: true);
                  }
                }
              },
              child: const Text('Purge data'),
            ),
          ],
        ),
      );
      otp.dispose();
      if (verified == true && mounted) {
        showMessage(context, 'Company data purged.');
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }
}

class _ChangePassword extends StatefulWidget {
  const _ChangePassword({required this.api});
  final ApiClient api;
  @override
  State<_ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<_ChangePassword> {
  final current = TextEditingController();
  final next = TextEditingController();
  bool saving = false;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
              width: 280,
              child: TextField(
                  controller: current,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Current password'))),
          SizedBox(
              width: 280,
              child: TextField(
                  controller: next,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'New password'))),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      await widget.api.post('/auth/change-password', body: {
                        'current_password': current.text,
                        'new_password': next.text
                      });
                      if (mounted) {
                        current.clear();
                        next.clear();
                        showMessage(context, 'Password changed.');
                      }
                    } catch (e) {
                      if (mounted) {
                        showMessage(context, e.toString(), error: true);
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Changing…' : 'Change password'),
          ),
        ],
      );
}
