import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class RecurringInvoicesScreen extends StatefulWidget {
  const RecurringInvoicesScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<RecurringInvoicesScreen> createState() =>
      _RecurringInvoicesScreenState();
}

class _RecurringInvoicesScreenState extends State<RecurringInvoicesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get('/recurring-invoices');
      _items = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    try {
      final contacts = (await widget.api.get('/masters/contacts',
              query: {'contact_type': 'CUSTOMER', 'limit': 100}) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final products = (await widget.api
              .get('/masters/products', query: {'limit': 100}) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      if (contacts.isEmpty || products.isEmpty) {
        showMessage(context, 'Create at least one customer and one item first.',
            error: true);
        return;
      }
      final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => _RecurringEditor(
                  api: widget.api, contacts: contacts, products: products)));
      if (saved == true) _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _generate(Map<String, dynamic> item) async {
    try {
      final data =
          await widget.api.post('/recurring-invoices/${item['id']}/generate');
      if (mounted) {
        showMessage(context,
            'Invoice ${data is Map ? data['invoice_number'] ?? '' : ''} generated and posted.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Recurring Invoices',
        subtitle:
            'Automate repeat billing while keeping each generated invoice in the normal GST and ledger flow.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New schedule')),
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.autorenew_rounded,
                        title: 'No recurring invoices',
                        message:
                            'Create a schedule for rent, retainers, subscriptions or repeat supply.',
                        action: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New schedule')))
                    : Column(
                        children: _items.map((r) {
                        final active = r['is_active'] != false;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Card(
                              child: ListTile(
                            leading: CircleAvatar(
                                child: Icon(active
                                    ? Icons.autorenew_rounded
                                    : Icons.pause_rounded)),
                            title: Row(children: [
                              Expanded(
                                  child: Text('${r['template_name'] ?? ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800))),
                              Chip(label: Text(active ? 'Active' : 'Paused')),
                            ]),
                            subtitle: Text(
                                '${r['contact_name'] ?? ''} • ${titleCase('${r['frequency'] ?? ''}')} • next ${displayDate(r['next_date'])}\n${r['occurrences_created'] ?? 0} invoice(s) created'),
                            isThreeLine: true,
                            trailing: Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (active)
                                    FilledButton.tonal(
                                        onPressed: () => _generate(r),
                                        child: const Text('Generate now')),
                                  PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      try {
                                        if (v == 'pause' || v == 'resume') {
                                          await widget.api.put(
                                              '/recurring-invoices/${r['id']}',
                                              body: {
                                                'is_active': v == 'resume'
                                              });
                                        } else if (v == 'delete') {
                                          await widget.api.delete(
                                              '/recurring-invoices/${r['id']}');
                                        }
                                        if (mounted) {
                                          showMessage(
                                              context,
                                              v == 'delete'
                                                  ? 'Schedule deleted.'
                                                  : v == 'pause'
                                                      ? 'Schedule paused.'
                                                      : 'Schedule activated.');
                                          _load();
                                        }
                                      } catch (e) {
                                        if (mounted)
                                          showMessage(context, e.toString(),
                                              error: true);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (active)
                                        const PopupMenuItem(
                                            value: 'pause',
                                            child: Text('Pause')),
                                      if (!active)
                                        const PopupMenuItem(
                                            value: 'resume',
                                            child: Text('Activate')),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete')),
                                    ],
                                  ),
                                ]),
                          )),
                        );
                      }).toList()),
      );
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor(
      {required this.api, required this.contacts, required this.products});
  final ApiClient api;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> products;
  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  String? _contactId;
  String? _productId;
  String _frequency = 'MONTHLY';
  String _endMode = 'NEVER';
  int _interval = 1;
  DateTime _nextDate = DateTime.now();
  DateTime? _endDate;
  final _name = TextEditingController();
  final _pos = TextEditingController(text: '27');
  final _qty = TextEditingController(text: '1');
  final _rate = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _hsn = TextEditingController();
  final _gst = TextEditingController(text: '18');
  final _max = TextEditingController(text: '12');
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _contactId = '${widget.contacts.first['id']}';
    _productId = '${widget.products.first['id']}';
    _syncProduct();
  }

  void _syncProduct() {
    final p = widget.products.firstWhere((x) => '${x['id']}' == _productId,
        orElse: () => widget.products.first);
    _rate.text = '${p['sales_price'] ?? 0}';
    _hsn.text = '${p['hsn_sac'] ?? ''}';
    _gst.text = '${p['gst_rate'] ?? 0}';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _pos,
      _qty,
      _rate,
      _discount,
      _hsn,
      _gst,
      _max,
      _notes,
      _terms
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text) ?? 0,
        rate = double.tryParse(_rate.text) ?? -1;
    if (_name.text.trim().isEmpty ||
        qty <= 0 ||
        rate < 0 ||
        _pos.text.trim().length != 2) {
      showMessage(
          context, 'Template name, POS and valid line values are required.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.post('/recurring-invoices', body: {
        'contact_id': _contactId,
        'template_name': _name.text.trim(),
        'frequency': _frequency,
        'interval_count': _interval,
        'next_date': apiDate(_nextDate),
        'end_mode': _endMode,
        'end_date': _endMode == 'ON_DATE' && _endDate != null
            ? apiDate(_endDate!)
            : null,
        'max_occurrences':
            _endMode == 'AFTER_N' ? int.tryParse(_max.text) : null,
        'currency': 'INR',
        'exchange_rate': 1,
        'pos_state_code': _pos.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'terms_and_conditions':
            _terms.text.trim().isEmpty ? null : _terms.text.trim(),
        'items': [
          {
            'product_id': _productId,
            'description': null,
            'quantity': qty,
            'rate': rate,
            'discount': double.tryParse(_discount.text) ?? 0,
            'hsn_sac': _hsn.text.trim(),
            'gst_rate': double.tryParse(_gst.text) ?? 0
          }
        ],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New recurring invoice'), actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save schedule')))
        ]),
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: Column(children: [
                      SectionCard(
                          title: 'Schedule',
                          child: Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(
                                width: 330,
                                child: TextField(
                                    controller: _name,
                                    decoration: const InputDecoration(
                                        labelText: 'Template name *'))),
                            SizedBox(
                                width: 360,
                                child: DropdownButtonFormField<String>(
                                    value: _contactId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Customer'),
                                    items: widget.contacts
                                        .map((c) => DropdownMenuItem(
                                            value: '${c['id']}',
                                            child: Text('${c['name']}')))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _contactId = v))),
                            SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                    value: _frequency,
                                    decoration: const InputDecoration(
                                        labelText: 'Frequency'),
                                    items: const [
                                      'WEEKLY',
                                      'MONTHLY',
                                      'QUARTERLY',
                                      'YEARLY'
                                    ]
                                        .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(titleCase(v))))
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _frequency = v!))),
                            SizedBox(
                                width: 120,
                                child: DropdownButtonFormField<int>(
                                    value: _interval,
                                    decoration: const InputDecoration(
                                        labelText: 'Every'),
                                    items: List.generate(
                                        12,
                                        (i) => DropdownMenuItem(
                                            value: i + 1,
                                            child: Text('${i + 1}'))),
                                    onChanged: (v) =>
                                        setState(() => _interval = v!))),
                            SizedBox(
                                width: 210,
                                child: InkWell(
                                    onTap: () async {
                                      final d =
                                          await pickDate(context, _nextDate);
                                      if (d != null)
                                        setState(() => _nextDate = d);
                                    },
                                    child: InputDecorator(
                                        decoration: const InputDecoration(
                                            labelText: 'Next invoice date'),
                                        child: Text(displayDate(
                                            _nextDate.toIso8601String()))))),
                            SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                    value: _endMode,
                                    decoration: const InputDecoration(
                                        labelText: 'Ends'),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'NEVER', child: Text('Never')),
                                      DropdownMenuItem(
                                          value: 'ON_DATE',
                                          child: Text('On date')),
                                      DropdownMenuItem(
                                          value: 'AFTER_N',
                                          child: Text('After N invoices'))
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _endMode = v!))),
                            if (_endMode == 'ON_DATE')
                              SizedBox(
                                  width: 210,
                                  child: InkWell(
                                      onTap: () async {
                                        final d = await pickDate(
                                            context,
                                            _endDate ??
                                                _nextDate.add(
                                                    const Duration(days: 365)));
                                        if (d != null)
                                          setState(() => _endDate = d);
                                      },
                                      child: InputDecorator(
                                          decoration: const InputDecoration(
                                              labelText: 'End date'),
                                          child: Text(_endDate == null
                                              ? 'Choose date'
                                              : displayDate(_endDate!
                                                  .toIso8601String()))))),
                            if (_endMode == 'AFTER_N')
                              SizedBox(
                                  width: 160,
                                  child: TextField(
                                      controller: _max,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          labelText: 'Occurrences'))),
                            SizedBox(
                                width: 150,
                                child: TextField(
                                    controller: _pos,
                                    maxLength: 2,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'POS state',
                                        counterText: ''))),
                          ])),
                      const SizedBox(height: 14),
                      SectionCard(
                          title: 'Invoice item',
                          child: Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(
                                width: 360,
                                child: DropdownButtonFormField<String>(
                                    value: _productId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Item'),
                                    items: widget.products
                                        .map((p) => DropdownMenuItem(
                                            value: '${p['id']}',
                                            child: Text('${p['name']}')))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() => _productId = v);
                                      _syncProduct();
                                    })),
                            SizedBox(
                                width: 120,
                                child: TextField(
                                    controller: _qty,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Qty'))),
                            SizedBox(
                                width: 160,
                                child: TextField(
                                    controller: _rate,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Rate'))),
                            SizedBox(
                                width: 140,
                                child: TextField(
                                    controller: _discount,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Discount'))),
                            SizedBox(
                                width: 160,
                                child: TextField(
                                    controller: _hsn,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'HSN/SAC'))),
                            SizedBox(
                                width: 120,
                                child: TextField(
                                    controller: _gst,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'GST %'))),
                          ])),
                      const SizedBox(height: 14),
                      SectionCard(
                          title: 'Invoice text',
                          child: Column(children: [
                            TextField(
                                controller: _notes,
                                maxLines: 2,
                                decoration:
                                    const InputDecoration(labelText: 'Notes')),
                            const SizedBox(height: 10),
                            TextField(
                                controller: _terms,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                    labelText: 'Terms & conditions'))
                          ])),
                    ])))),
      );
}
