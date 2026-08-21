import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _type = 'ALL';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = <String, dynamic>{'limit': 100};
      if (_type != 'ALL') query['contact_type'] = _type;
      if (_search.text.trim().isNotEmpty) query['search'] = _search.text.trim();
      final data = await widget.api.get('/masters/contacts', query: query);
      if (mounted)
        setState(
          () => _items = (data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
        );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ContactDialog(api: widget.api, item: item),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    final active = item['is_active'] != false;
    try {
      await widget.api.put(
        '/masters/contacts/${item['id']}',
        body: {'is_active': !active},
      );
      if (mounted) {
        showMessage(
          context,
          active ? 'Party deactivated.' : 'Party activated.',
        );
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete party?'),
            content: Text(
              'Delete ${item['name'] ?? 'this party'}? Parties linked to active invoices or bills cannot be deleted; deactivate them instead.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await widget.api.delete('/masters/contacts/${item['id']}');
      if (mounted) {
        showMessage(context, 'Party deleted.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _actions(Map<String, dynamic> item) => PopupMenuButton<String>(
    onSelected: (v) {
      if (v == 'edit') _openForm(item);
      if (v == 'toggle') _toggle(item);
      if (v == 'delete') _delete(item);
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Text('Edit')),
      PopupMenuItem(
        value: 'toggle',
        child: Text(item['is_active'] == false ? 'Activate' : 'Deactivate'),
      ),
      const PopupMenuItem(value: 'delete', child: Text('Delete')),
    ],
  );

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Parties',
    subtitle: 'Customers, vendors, GST registrations and party master data.',
    actions: [
      IconButton(
        onPressed: _load,
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh_rounded),
      ),
      FilledButton.icon(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Add party'),
      ),
    ],
    child: Column(
      children: [
        SectionCard(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 330,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search name, GSTIN, phone or email',
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _load);
                  },
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ALL', label: Text('All')),
                  ButtonSegment(value: 'CUSTOMER', label: Text('Customers')),
                  ButtonSegment(value: 'VENDOR', label: Text('Vendors')),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() => _type = s.first);
                  _load();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(50),
            child: CircularProgressIndicator(),
          )
        else if (_error != null)
          ErrorPanel(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          EmptyState(
            icon: Icons.people_alt_outlined,
            title: 'No parties found',
            message:
                'Create customers or vendors to start billing and purchasing.',
            action: FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add party'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) => c.maxWidth >= 850
                ? _table()
                : Column(children: _items.map(_card).toList()),
          ),
      ],
    ),
  );

  Widget _table() => SectionCard(
    padding: EdgeInsets.zero,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Party')),
          DataColumn(label: Text('Type')),
          DataColumn(label: Text('GSTIN')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('State')),
          DataColumn(label: Text('')),
        ],
        rows: _items
            .map(
              (p) => DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          p['email']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      '${p['contact_type'] ?? ''}${p['is_active'] == false ? ' • INACTIVE' : ''}',
                    ),
                  ),
                  DataCell(Text(p['gstin']?.toString() ?? '—')),
                  DataCell(Text(p['phone']?.toString() ?? '—')),
                  DataCell(Text(p['state_code']?.toString() ?? '—')),
                  DataCell(_actions(p)),
                ],
              ),
            )
            .toList(),
      ),
    ),
  );

  Widget _card(Map<String, dynamic> p) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Text(
            (p['name']?.toString() ?? 'P').substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(
          p['name']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${p['contact_type'] ?? ''}${p['is_active'] == false ? ' • INACTIVE' : ''} • ${p['gstin'] ?? 'Unregistered'}\n${p['phone'] ?? p['email'] ?? ''}',
        ),
        isThreeLine: true,
        trailing: _actions(p),
      ),
    ),
  );
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.api, this.item});
  final ApiClient api;
  final Map<String, dynamic>? item;
  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name,
      _gstin,
      _pan,
      _email,
      _phone,
      _stateCode,
      _street,
      _city,
      _state,
      _pincode;
  String _type = 'CUSTOMER';
  String _registration = 'CONSUMER';
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    final p = widget.item ?? {};
    final a = p['billing_address'] is Map
        ? Map<String, dynamic>.from(p['billing_address'] as Map)
        : <String, dynamic>{};
    _name = TextEditingController(text: p['name']?.toString() ?? '');
    _gstin = TextEditingController(text: p['gstin']?.toString() ?? '');
    _pan = TextEditingController(text: p['pan']?.toString() ?? '');
    _email = TextEditingController(text: p['email']?.toString() ?? '');
    _phone = TextEditingController(text: p['phone']?.toString() ?? '');
    _stateCode = TextEditingController(
      text: p['state_code']?.toString() ?? a['state_code']?.toString() ?? '27',
    );
    _street = TextEditingController(text: a['street']?.toString() ?? '');
    _city = TextEditingController(text: a['city']?.toString() ?? '');
    _state = TextEditingController(text: a['state']?.toString() ?? '');
    _pincode = TextEditingController(text: a['pincode']?.toString() ?? '');
    _type = p['contact_type']?.toString() ?? 'CUSTOMER';
    _registration = p['registration_type']?.toString() ?? 'CONSUMER';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _gstin,
      _pan,
      _email,
      _phone,
      _stateCode,
      _street,
      _city,
      _state,
      _pincode,
    ])
      c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final address =
          [
            _street,
            _city,
            _state,
            _pincode,
          ].every((c) => c.text.trim().isNotEmpty)
          ? {
              'street': _street.text.trim(),
              'city': _city.text.trim(),
              'state': _state.text.trim(),
              'state_code': _stateCode.text.trim(),
              'pincode': _pincode.text.trim(),
              'country': 'India',
            }
          : null;
      final body = {
        'name': _name.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'contact_type': _type,
        'gstin': _gstin.text.trim().isEmpty
            ? null
            : _gstin.text.trim().toUpperCase(),
        'pan': _pan.text.trim().isEmpty ? null : _pan.text.trim().toUpperCase(),
        'registration_type': _registration,
        'billing_address': address,
        'shipping_address': null,
        'state_code': _stateCode.text.trim(),
      };
      if (widget.item == null) {
        await widget.api.post('/masters/contacts', body: body);
      } else {
        await widget.api.put(
          '/masters/contacts/${widget.item!['id']}',
          body: body,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Add party' : 'Edit party'),
    content: SizedBox(
      width: 760,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 350,
                child: TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Party name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'CUSTOMER',
                      child: Text('Customer'),
                    ),
                    DropdownMenuItem(value: 'VENDOR', child: Text('Vendor')),
                    DropdownMenuItem(value: 'BOTH', child: Text('Both')),
                  ],
                  onChanged: (v) => setState(() => _type = v!),
                ),
              ),
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<String>(
                  value: _registration,
                  decoration: const InputDecoration(
                    labelText: 'GST registration',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'REGULAR', child: Text('Regular')),
                    DropdownMenuItem(
                      value: 'COMPOSITION',
                      child: Text('Composition'),
                    ),
                    DropdownMenuItem(value: 'SEZ', child: Text('SEZ')),
                    DropdownMenuItem(
                      value: 'UNREGISTERED',
                      child: Text('Unregistered'),
                    ),
                    DropdownMenuItem(
                      value: 'CONSUMER',
                      child: Text('Consumer'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _registration = v!),
                ),
              ),
              SizedBox(
                width: 230,
                child: TextFormField(
                  controller: _gstin,
                  maxLength: 15,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN',
                    counterText: '',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextFormField(
                  controller: _pan,
                  maxLength: 10,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'PAN',
                    counterText: '',
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ),
              SizedBox(
                width: 320,
                child: TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextFormField(
                  controller: _stateCode,
                  maxLength: 2,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'State code',
                    counterText: '',
                  ),
                  validator: (v) => v?.length == 2 ? null : '2 digits',
                ),
              ),
              const SizedBox(width: 700, child: Divider()),
              SizedBox(
                width: 350,
                child: TextField(
                  controller: _street,
                  decoration: const InputDecoration(
                    labelText: 'Billing street',
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _city,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _state,
                  decoration: const InputDecoration(labelText: 'State'),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _pincode,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
