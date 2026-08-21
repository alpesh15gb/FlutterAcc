import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
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

  List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is Map && raw['items'] is List) {
      return (raw['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get('/recurring-invoices');
      if (mounted) setState(() => _items = _rows(data));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor([String? id]) async {
    try {
      final result = await Future.wait([
        widget.api.get('/masters/contacts',
            query: {'contact_type': 'CUSTOMER', 'limit': 100}),
        widget.api.get('/masters/products', query: {'limit': 100}),
      ]);
      if (!mounted) return;
      final contacts = _rows(result[0]);
      final products = _rows(result[1]);
      if (contacts.isEmpty || products.isEmpty) {
        showMessage(context, 'Create at least one customer and one item first.',
            error: true);
        return;
      }
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _RecurringEditor(
            api: widget.api,
            contacts: contacts,
            products: products,
            initialId: id,
          ),
        ),
      );
      if (saved == true) _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _generate(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Generate invoice now?'),
            content: Text(
              'Generate an invoice from ${row['template_name'] ?? 'this template'}? '
              'Recurring template rates are GST EXCLUSIVE, so GST is added on top.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Back')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Generate')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      final data =
          await widget.api.post('/recurring-invoices/${row['id']}/generate');
      if (!mounted) return;
      showMessage(
        context,
        'Invoice ${data is Map ? data['invoice_number'] ?? '' : ''} generated. '
        'GST was added above the taxable template rates.',
      );
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _setActive(Map<String, dynamic> row, bool active) async {
    try {
      await widget.api.put('/recurring-invoices/${row['id']}',
          body: {'is_active': active});
      if (!mounted) return;
      showMessage(context, active ? 'Template activated.' : 'Template paused.');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete recurring template?'),
            content: Text(
              'Delete ${row['template_name'] ?? 'this template'}? '
              'Already-generated invoices remain in the books.',
            ),
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
      await widget.api.delete('/recurring-invoices/${row['id']}');
      if (!mounted) return;
      showMessage(context, 'Recurring template deleted.');
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Recurring Invoices',
        subtitle:
            'Scheduled billing. Template rates are explicitly GST-exclusive until the backend stores an inclusive-rate mode.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New template')),
        ],
        child: Column(children: [
          SectionCard(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GST EXCLUSIVE RATES: ₹16,500 @ 18% generates ₹19,470. '
                      'If ₹16,500 is the final GST-inclusive amount, create a normal invoice and choose “GST INCLUDED in entered rate”.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(60), child: CircularProgressIndicator())
          else if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else if (_items.isEmpty)
            EmptyState(
              icon: Icons.autorenew_rounded,
              title: 'No recurring templates',
              message:
                  'Create a schedule for retainers, rent, subscriptions or repeat billing.',
              action: FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New template')),
            )
          else
            Column(
              children: _items.map((row) {
                final active = row['is_active'] != false;
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
                          child: Text('${row['template_name'] ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const Chip(label: Text('GST EXCL. RATES')),
                        const SizedBox(width: 6),
                        Chip(label: Text(active ? 'Active' : 'Paused')),
                      ]),
                      subtitle: Text(
                        '${row['contact_name'] ?? ''} • ${titleCase('${row['frequency'] ?? ''}')} • '
                        'next ${displayDate(row['next_date'])}\n'
                        '${row['occurrences_created'] ?? 0} invoice(s) created',
                      ),
                      isThreeLine: true,
                      onTap: () => _openEditor('${row['id']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _openEditor('${row['id']}');
                          if (value == 'generate') _generate(row);
                          if (value == 'pause') _setActive(row, false);
                          if (value == 'resume') _setActive(row, true);
                          if (value == 'delete') _delete(row);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (active)
                            const PopupMenuItem(
                                value: 'generate', child: Text('Generate now')),
                          PopupMenuItem(
                              value: active ? 'pause' : 'resume',
                              child: Text(active ? 'Pause' : 'Activate')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ]),
      );
}

class _RecurringEditor extends StatefulWidget {
  const _RecurringEditor({
    required this.api,
    required this.contacts,
    required this.products,
    this.initialId,
  });

  final ApiClient api;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> products;
  final String? initialId;

  @override
  State<_RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends State<_RecurringEditor> {
  final _name = TextEditingController();
  final _pos = TextEditingController(text: '27');
  final _max = TextEditingController(text: '12');
  final _notes = TextEditingController();
  final _terms = TextEditingController();

  String? _contactId;
  String _frequency = 'MONTHLY';
  String _endMode = 'NEVER';
  int _interval = 1;
  DateTime _nextDate = DateTime.now();
  DateTime? _endDate;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  final List<_RecurringLine> _lines = [];

  bool get _editing => widget.initialId != null;

  @override
  void initState() {
    super.initState();
    _contactId = '${widget.contacts.first['id']}';
    _addProduct(widget.products.first);
    if (_editing) _loadExisting();
  }

  @override
  void dispose() {
    for (final c in [_name, _pos, _max, _notes, _terms]) {
      c.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  void _addProduct(Map<String, dynamic> product) {
    final line = _RecurringLine()
      ..productId = '${product['id']}'
      ..description.text = '${product['name'] ?? ''}'
      ..rate.text = '${product['sales_price'] ?? 0}'
      ..hsn.text = '${product['hsn_sac'] ?? ''}'
      ..gst.text = '${product['gst_rate'] ?? 0}';
    setState(() => _lines.add(line));
  }

  void _selectProduct(_RecurringLine line, String? id) {
    final matches = widget.products.where((p) => '${p['id']}' == id).toList();
    if (matches.isEmpty) return;
    final product = matches.first;
    setState(() {
      line.productId = id;
      line.description.text = '${product['name'] ?? ''}';
      line.rate.text = '${product['sales_price'] ?? 0}';
      line.hsn.text = '${product['hsn_sac'] ?? ''}';
      line.gst.text = '${product['gst_rate'] ?? 0}';
    });
  }

  Future<void> _loadExisting() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = Map<String, dynamic>.from(
          await widget.api.get('/recurring-invoices/${widget.initialId}') as Map);
      if (!mounted) return;
      for (final line in _lines) {
        line.dispose();
      }
      setState(() {
        _lines.clear();
        _name.text = '${data['template_name'] ?? ''}';
        _contactId = '${data['contact_id']}';
        _frequency = '${data['frequency'] ?? 'MONTHLY'}';
        _interval = int.tryParse('${data['interval_count'] ?? 1}') ?? 1;
        _nextDate = DateTime.tryParse('${data['next_date']}') ?? DateTime.now();
        _endMode = '${data['end_mode'] ?? 'NEVER'}';
        _endDate = data['end_date'] == null
            ? null
            : DateTime.tryParse('${data['end_date']}');
        _max.text = '${data['max_occurrences'] ?? 12}';
        _pos.text = '${data['pos_state_code'] ?? '27'}';
        _notes.text = '${data['notes'] ?? ''}';
        _terms.text = '${data['terms_and_conditions'] ?? ''}';
        for (final raw in data['items'] as List? ?? const []) {
          final item = Map<String, dynamic>.from(raw as Map);
          _lines.add(_RecurringLine()
            ..productId = '${item['product_id']}'
            ..description.text = '${item['description'] ?? ''}'
            ..quantity.text = '${item['quantity'] ?? 1}'
            ..rate.text = '${item['rate'] ?? 0}'
            ..discount.text = '${item['discount'] ?? 0}'
            ..hsn.text = '${item['hsn_sac'] ?? ''}'
            ..gst.text = '${item['gst_rate'] ?? 0}');
        }
        if (_lines.isEmpty) _addProduct(widget.products.first);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, double> get _estimate {
    var taxable = 0.0;
    var gst = 0.0;
    for (final line in _lines) {
      final qty = double.tryParse(line.quantity.text) ?? 0;
      final rate = double.tryParse(line.rate.text) ?? 0;
      final discount = double.tryParse(line.discount.text) ?? 0;
      final lineBase = (qty * rate - discount).clamp(0.0, double.infinity);
      final ratePct = double.tryParse(line.gst.text) ?? 0;
      taxable += lineBase;
      gst += lineBase * ratePct / 100;
    }
    return {'taxable': taxable, 'gst': gst, 'total': taxable + gst};
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _contactId == null ||
        _pos.text.trim().length != 2 ||
        _lines.isEmpty) {
      showMessage(context, 'Template name, customer, POS and items are required.',
          error: true);
      return;
    }
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.productId == null ||
          (double.tryParse(line.quantity.text) ?? 0) <= 0 ||
          (double.tryParse(line.rate.text) ?? -1) < 0 ||
          line.hsn.text.trim().length < 4) {
        showMessage(context, 'Fix item ${i + 1}: item, qty, taxable rate and HSN/SAC are required.',
            error: true);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final body = {
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
        'items': _lines
            .map((line) => {
                  'product_id': line.productId,
                  'description': line.description.text.trim().isEmpty
                      ? null
                      : line.description.text.trim(),
                  'quantity': double.tryParse(line.quantity.text) ?? 0,
                  'rate': double.tryParse(line.rate.text) ?? 0,
                  'discount': double.tryParse(line.discount.text) ?? 0,
                  'hsn_sac': line.hsn.text.trim(),
                  'gst_rate': double.tryParse(line.gst.text) ?? 0,
                })
            .toList(),
      };
      if (_editing) {
        await widget.api.put('/recurring-invoices/${widget.initialId}', body: body);
      } else {
        await widget.api.post('/recurring-invoices', body: body);
      }
      if (!mounted) return;
      showMessage(context, _editing ? 'Template updated.' : 'Template created.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totals = _estimate;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit recurring invoice' : 'New recurring invoice'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Save template'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorPanel(message: _error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(children: [
                        SectionCard(
                          title: 'GST rate mode',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'GST EXCLUDED — FIXED BY CURRENT BACKEND. Every rate below is a taxable/base rate; GST is added when the invoice is generated.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SectionCard(
                          title: 'Schedule',
                          child: Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(
                              width: 330,
                              child: TextField(
                                controller: _name,
                                decoration: const InputDecoration(
                                    labelText: 'Template name *'),
                              ),
                            ),
                            SizedBox(
                              width: 360,
                              child: DropdownButtonFormField<String>(
                                value: _contactId,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: 'Customer'),
                                items: widget.contacts
                                    .map((c) => DropdownMenuItem(
                                        value: '${c['id']}',
                                        child: Text('${c['name']}')))
                                    .toList(),
                                onChanged: (v) => setState(() => _contactId = v),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<String>(
                                value: _frequency,
                                decoration:
                                    const InputDecoration(labelText: 'Frequency'),
                                items: const [
                                  'WEEKLY',
                                  'MONTHLY',
                                  'QUARTERLY',
                                  'YEARLY'
                                ]
                                    .map((v) => DropdownMenuItem(
                                        value: v, child: Text(titleCase(v))))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _frequency = v ?? 'MONTHLY'),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: DropdownButtonFormField<int>(
                                value: _interval,
                                decoration: const InputDecoration(labelText: 'Every'),
                                items: List.generate(
                                    12,
                                    (i) => DropdownMenuItem(
                                        value: i + 1, child: Text('${i + 1}'))),
                                onChanged: (v) =>
                                    setState(() => _interval = v ?? 1),
                              ),
                            ),
                            SizedBox(
                              width: 210,
                              child: InkWell(
                                onTap: () async {
                                  final d = await pickDate(context, _nextDate);
                                  if (d != null) setState(() => _nextDate = d);
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                      labelText: 'Next invoice date'),
                                  child: Text(displayDate(_nextDate.toIso8601String())),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<String>(
                                value: _endMode,
                                decoration:
                                    const InputDecoration(labelText: 'Ends'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'NEVER', child: Text('Never')),
                                  DropdownMenuItem(
                                      value: 'ON_DATE', child: Text('On date')),
                                  DropdownMenuItem(
                                      value: 'AFTER_N',
                                      child: Text('After N invoices')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _endMode = v ?? 'NEVER'),
                              ),
                            ),
                            if (_endMode == 'ON_DATE')
                              SizedBox(
                                width: 210,
                                child: InkWell(
                                  onTap: () async {
                                    final d = await pickDate(
                                        context,
                                        _endDate ??
                                            _nextDate.add(const Duration(days: 365)));
                                    if (d != null) setState(() => _endDate = d);
                                  },
                                  child: InputDecorator(
                                    decoration:
                                        const InputDecoration(labelText: 'End date'),
                                    child: Text(_endDate == null
                                        ? 'Choose date'
                                        : displayDate(_endDate!.toIso8601String())),
                                  ),
                                ),
                              ),
                            if (_endMode == 'AFTER_N')
                              SizedBox(
                                width: 160,
                                child: TextField(
                                  controller: _max,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: 'Occurrences'),
                                ),
                              ),
                            SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _pos,
                                maxLength: 2,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: 'POS state', counterText: ''),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 14),
                        SectionCard(
                          title: 'Invoice items',
                          trailing: TextButton.icon(
                            onPressed: () => _addProduct(widget.products.first),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add item'),
                          ),
                          child: Column(
                            children: List.generate(_lines.length, (index) {
                              final line = _lines[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 290,
                                      child: DropdownButtonFormField<String>(
                                        value: line.productId,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: 'Item ${index + 1}'),
                                        items: widget.products
                                            .map((p) => DropdownMenuItem(
                                                value: '${p['id']}',
                                                child: Text('${p['name']}')))
                                            .toList(),
                                        onChanged: (v) => _selectProduct(line, v),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: TextField(
                                        controller: line.quantity,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Qty'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 190,
                                      child: TextField(
                                        controller: line.rate,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Taxable rate (GST excluded)',
                                          helperText: 'GST added on top',
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 130,
                                      child: TextField(
                                        controller: line.discount,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Discount'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 135,
                                      child: TextField(
                                        controller: line.hsn,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'HSN/SAC'),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 105,
                                      child: TextField(
                                        controller: line.gst,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'GST %'),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _lines.length == 1
                                          ? null
                                          : () {
                                              final removed = _lines.removeAt(index);
                                              removed.dispose();
                                              setState(() {});
                                            },
                                      icon: const Icon(Icons.delete_outline_rounded),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SectionCard(
                          title: 'Expected invoice total',
                          child: Wrap(spacing: 28, runSpacing: 12, children: [
                            _metric('Taxable', totals['taxable'] ?? 0),
                            _metric('Estimated GST', totals['gst'] ?? 0),
                            _metric('Expected total', totals['total'] ?? 0),
                          ]),
                        ),
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
                                    labelText: 'Terms & conditions')),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
    );
  }

  Widget _metric(String label, num value) => SizedBox(
        width: 170,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(money(value),
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ]),
      );
}

class _RecurringLine {
  String? productId;
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  final discount = TextEditingController(text: '0');
  final hsn = TextEditingController();
  final gst = TextEditingController(text: '18');

  void dispose() {
    description.dispose();
    quantity.dispose();
    rate.dispose();
    discount.dispose();
    hsn.dispose();
    gst.dispose();
  }
}
