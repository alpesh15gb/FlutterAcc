import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class TaxDocumentEditorScreen extends StatefulWidget {
  const TaxDocumentEditorScreen(
      {super.key, required this.api, required this.kindName, this.initialId});
  final ApiClient api;
  final String kindName;
  final String? initialId;

  @override
  State<TaxDocumentEditorScreen> createState() =>
      _TaxDocumentEditorScreenState();
}

class _TaxDocumentEditorScreenState extends State<TaxDocumentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _pos = TextEditingController(text: '27');
  final _discount = TextEditingController(text: '0');
  final _shipping = TextEditingController(text: '0');
  final _tds = TextEditingController(text: '0');
  final _tcs = TextEditingController(text: '0');
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String? _contactId;
  String _supplyType = 'DOMESTIC';
  bool _inclusive = false;
  bool _rcm = false;
  bool _itc = true;
  bool _postOnCreate = true;
  bool _loading = true;
  bool _saving = false;
  bool _previewing = false;
  String? _error;
  Map<String, dynamic>? _preview;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _products = [];
  final List<_LineDraft> _lines = [_LineDraft()];
  Timer? _previewDebounce;

  _DocDef get def => _DocDef.fromName(widget.kindName);
  bool get _editing => widget.initialId != null;

  @override
  void initState() {
    super.initState();
    _loadMasters();
    for (final line in _lines) {
      line.addListener(_queuePreview);
    }
    for (final c in [_pos, _discount, _shipping, _tds, _tcs]) {
      c.addListener(_queuePreview);
    }
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    for (final c in [
      _number,
      _pos,
      _discount,
      _shipping,
      _tds,
      _tcs,
      _reference,
      _notes,
      _terms
    ]) {
      c.dispose();
    }
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final contactData = await widget.api.get('/masters/contacts', query: {
        'contact_type': def.vendor ? 'VENDOR' : 'CUSTOMER',
        'limit': 100
      });
      final productData =
          await widget.api.get('/masters/products', query: {'limit': 100});
      Map<String, dynamic>? existing;
      if (_editing) {
        existing = Map<String, dynamic>.from(
            await widget.api.get('${def.endpoint}/${widget.initialId}') as Map);
      }
      if (!mounted) return;
      setState(() {
        _contacts = (contactData as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _products = (productData as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (existing != null) {
          _applyExisting(existing);
        } else if (_contacts.isNotEmpty) {
          _contactId = _contacts.first['id']?.toString();
          final state = _contacts.first['state_code']?.toString();
          if (state != null && state.length == 2) _pos.text = state;
        }
      });
      _queuePreview();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _parseDate(Object? value, DateTime fallback) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed ?? fallback;
  }

  void _applyExisting(Map<String, dynamic> data) {
    _contactId = data['contact_id']?.toString() ??
        (data['contact'] is Map
            ? (data['contact'] as Map)['id']?.toString()
            : null);
    _number.text = data[def.numberKey]?.toString() ?? '';
    _date = _parseDate(data[def.dateKey], _date);
    _dueDate = _parseDate(data['due_date'], _dueDate);
    if (data['pos_state_code'] != null)
      _pos.text = data['pos_state_code'].toString();
    _discount.text = '${data['discount_rate'] ?? 0}';
    _shipping.text = '${data['shipping_charges'] ?? 0}';
    _tds.text = '${data['tds_rate'] ?? 0}';
    _tcs.text = '${data['tcs_rate'] ?? 0}';
    _reference.text = data['reference_number']?.toString() ?? '';
    _notes.text = data['notes']?.toString() ?? '';
    _terms.text = data['terms_and_conditions']?.toString() ?? '';
    _inclusive = data['is_gst_inclusive'] == true;
    _rcm = data['is_rcm'] == true;
    _itc = data['itc_eligible'] != false;
    _supplyType = data['supply_type']?.toString() ?? _supplyType;
    _postOnCreate = false;
    final rawLines = data['lines'] is List ? data['lines'] as List : const [];
    for (final line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll(rawLines.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return _LineDraft()
          ..productId = map['product_id']?.toString()
          ..quantity.text = '${map['quantity'] ?? 1}'
          ..rate.text = '${map['rate'] ?? 0}'
          ..discount.text = '${map['discount'] ?? 0}'
          ..hsn.text = '${map['hsn_sac'] ?? ''}'
          ..gst.text = '${map['gst_rate'] ?? 0}'
          ..description.text = '${map['description'] ?? ''}';
      }));
    if (_lines.isEmpty) _lines.add(_LineDraft());
    for (final line in _lines) {
      line.addListener(_queuePreview);
    }
  }

  void _queuePreview() {
    if (!def.hasPreview) return;
    _previewDebounce?.cancel();
    _previewDebounce =
        Timer(const Duration(milliseconds: 500), _previewDocument);
  }

  Map<String, dynamic> _linePayload(_LineDraft line) => {
        'product_id': line.productId,
        'description': line.description.text.trim().isEmpty
            ? null
            : line.description.text.trim(),
        'quantity': double.tryParse(line.quantity.text) ?? 0,
        'rate': double.tryParse(line.rate.text) ?? 0,
        'discount': double.tryParse(line.discount.text) ?? 0,
        'hsn_sac': line.hsn.text.trim(),
        'gst_rate': double.tryParse(line.gst.text) ?? 0,
      };

  Map<String, dynamic> _payload({bool preview = false}) {
    final common = <String, dynamic>{
      'contact_id': _contactId,
      def.numberKey: _number.text.trim().isEmpty && def.numberOptional
          ? null
          : _number.text.trim(),
      def.dateKey: apiDate(_date),
      'due_date': apiDate(_dueDate),
      'pos_state_code': _pos.text.trim(),
      'line_items': _lines.map(_linePayload).toList(),
    };
    if (def.extendedTaxFields) {
      common.addAll({
        'discount_rate': double.tryParse(_discount.text) ?? 0,
        'shipping_charges': double.tryParse(_shipping.text) ?? 0,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'terms_and_conditions':
            _terms.text.trim().isEmpty ? null : _terms.text.trim(),
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'is_gst_inclusive': _inclusive,
        if (!_editing) 'post_on_create': preview ? false : _postOnCreate,
      });
      if (def.kind == 'invoice') {
        common.addAll({
          'is_rcm': _rcm,
          'supply_type': _supplyType,
          'currency': 'INR',
          'exchange_rate': 1,
          'tds_rate': double.tryParse(_tds.text) ?? 0,
          'tcs_rate': double.tryParse(_tcs.text) ?? 0,
        });
      } else if (def.kind == 'bill') {
        common.addAll({
          'tds_rate': double.tryParse(_tds.text) ?? 0,
          'itc_eligible': _itc,
        });
      }
    }
    return common;
  }

  Future<void> _previewDocument() async {
    if (!def.hasPreview ||
        _contactId == null ||
        _lines.any((l) => l.productId == null)) return;
    if (_lines.any((l) =>
        (double.tryParse(l.quantity.text) ?? 0) <= 0 ||
        (double.tryParse(l.rate.text) ?? -1) < 0)) return;
    if (_pos.text.trim().length != 2) return;
    setState(() => _previewing = true);
    try {
      final path = def.kind == 'bill' ? '/bills/preview' : '/invoices/preview';
      final data = await widget.api.post(path, body: _payload(preview: true));
      if (mounted)
        setState(() => _preview = Map<String, dynamic>.from(data as Map));
    } catch (_) {
      // Preview should never block data entry; authoritative error is shown on save.
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  String? _validateDocument() {
    if (_contactId == null)
      return 'Select a ${def.vendor ? 'vendor' : 'customer'}.';
    if (!def.numberOptional && _number.text.trim().isEmpty)
      return 'Enter the ${def.numberLabel.toLowerCase()}.';
    if (def.kind == 'invoice' && _number.text.trim().length > 16)
      return 'GST invoice numbers must be 16 characters or fewer.';
    if (_pos.text.trim().length != 2 || int.tryParse(_pos.text.trim()) == null)
      return 'Place of supply must be a two-digit GST state code.';
    if (_dueDate.isBefore(_date))
      return 'Due date cannot be before the document date.';
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.productId == null) return 'Select an item on line ${i + 1}.';
      if ((double.tryParse(line.quantity.text) ?? 0) <= 0)
        return 'Line ${i + 1}: quantity must be greater than zero.';
      if ((double.tryParse(line.rate.text) ?? -1) < 0)
        return 'Line ${i + 1}: rate cannot be negative.';
      if (line.hsn.text.trim().length < 4)
        return 'Line ${i + 1}: enter a valid HSN/SAC.';
    }
    return null;
  }

  Future<void> _save() async {
    final validation = _validateDocument();
    if (validation != null) {
      showMessage(context, validation, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.api
            .put('${def.endpoint}/${widget.initialId}', body: _payload());
      } else {
        await widget.api.post(def.endpoint, body: _payload());
      }
      if (mounted) {
        showMessage(context,
            _editing ? '${def.title} updated.' : '${def.title} saved.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit ${def.title}' : 'New ${def.title}'),
        actions: [
          if (def.hasPreview)
            IconButton(
                tooltip: 'Refresh tax preview',
                onPressed: _previewDocument,
                icon: const Icon(Icons.calculate_outlined)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving…' : 'Save')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorPanel(message: _error!, onRetry: _loadMasters))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: LayoutBuilder(builder: (context, c) {
                          final wide = c.maxWidth >= 1000;
                          final form = Column(children: [
                            _headerCard(),
                            const SizedBox(height: 14),
                            _lineItemsCard(),
                            if (def.extendedTaxFields) ...[
                              const SizedBox(height: 14),
                              _adjustmentsCard(),
                              const SizedBox(height: 14),
                              _notesCard(),
                            ],
                          ]);
                          if (!wide) {
                            return Column(children: [
                              form,
                              const SizedBox(height: 14),
                              _summaryCard()
                            ]);
                          }
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: form),
                                const SizedBox(width: 14),
                                SizedBox(width: 330, child: _summaryCard()),
                              ]);
                        }),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _headerCard() {
    return SectionCard(
      title: 'Document details',
      child: Wrap(spacing: 14, runSpacing: 14, children: [
        SizedBox(
          width: 350,
          child: DropdownButtonFormField<String>(
            value: _contactId,
            isExpanded: true,
            decoration:
                InputDecoration(labelText: def.vendor ? 'Vendor' : 'Customer'),
            items: _contacts
                .map((c) => DropdownMenuItem(
                    value: c['id']?.toString(),
                    child: Text(c['name']?.toString() ?? 'Party',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (value) {
              setState(() => _contactId = value);
              final contact =
                  _contacts.where((c) => c['id']?.toString() == value).toList();
              if (contact.isNotEmpty && contact.first['state_code'] != null)
                _pos.text = contact.first['state_code'].toString();
              _queuePreview();
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: TextFormField(
            controller: _number,
            maxLength: def.kind == 'invoice' ? 16 : 50,
            decoration: InputDecoration(
                labelText: def.numberLabel,
                counterText: '',
                hintText: def.numberOptional ? 'Auto if blank' : null),
          ),
        ),
        SizedBox(
            width: 210,
            child: _DateField(
                label: def.dateLabel,
                value: _date,
                onChanged: (d) => setState(() => _date = d))),
        SizedBox(
            width: 210,
            child: _DateField(
                label: 'Due date',
                value: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d))),
        SizedBox(
            width: 180,
            child: TextFormField(
                controller: _pos,
                maxLength: 2,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Place of supply',
                    helperText: 'GST state code',
                    counterText: ''))),
        if (def.kind == 'invoice')
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              value: _supplyType,
              decoration: const InputDecoration(labelText: 'Supply type'),
              items: const [
                DropdownMenuItem(value: 'DOMESTIC', child: Text('Domestic')),
                DropdownMenuItem(
                    value: 'EXPORT_WITH_TAX', child: Text('Export with tax')),
                DropdownMenuItem(
                    value: 'EXPORT_WITHOUT_TAX',
                    child: Text('Export without tax')),
                DropdownMenuItem(
                    value: 'SEZ_WITH_TAX', child: Text('SEZ with tax')),
                DropdownMenuItem(
                    value: 'SEZ_WITHOUT_TAX', child: Text('SEZ without tax')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _supplyType = v);
                _queuePreview();
              },
            ),
          ),
      ]),
    );
  }

  Widget _lineItemsCard() {
    return SectionCard(
      title: 'Items',
      trailing: TextButton.icon(
        onPressed: () => setState(
            () => _lines.add(_LineDraft()..addListener(_queuePreview))),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add line'),
      ),
      child: Column(children: [
        for (var i = 0; i < _lines.length; i++) ...[
          _lineEditor(i, _lines[i]),
          if (i != _lines.length - 1) const Divider(height: 24),
        ],
      ]),
    );
  }

  Widget _lineEditor(int index, _LineDraft line) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Line ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        if (_lines.length > 1)
          IconButton(
            tooltip: 'Remove line',
            onPressed: () => setState(() {
              final removed = _lines.removeAt(index);
              removed.dispose();
              _queuePreview();
            }),
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
      ]),
      Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                value: line.productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Item / service'),
                items: _products
                    .map((p) => DropdownMenuItem(
                        value: p['id']?.toString(),
                        child: Text(p['name']?.toString() ?? 'Item',
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    line.productId = value;
                    final matches = _products
                        .where((p) => p['id']?.toString() == value)
                        .toList();
                    if (matches.isNotEmpty) {
                      final p = matches.first;
                      line.description.text = p['name']?.toString() ?? '';
                      line.hsn.text = p['hsn_sac']?.toString() ?? '';
                      line.gst.text = p['gst_rate']?.toString() ?? '0';
                      line.rate.text =
                          (def.vendor ? p['purchase_price'] : p['sales_price'])
                                  ?.toString() ??
                              '0';
                    }
                  });
                  _queuePreview();
                },
              ),
            ),
            SizedBox(
                width: 105,
                child: TextField(
                    controller: line.quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Qty'))),
            SizedBox(
                width: 135,
                child: TextField(
                    controller: line.rate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Rate'))),
            SizedBox(
                width: 120,
                child: TextField(
                    controller: line.discount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Discount'))),
            SizedBox(
                width: 130,
                child: TextField(
                    controller: line.hsn,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'HSN / SAC'))),
            SizedBox(
                width: 105,
                child: TextField(
                    controller: line.gst,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'GST %'))),
          ]),
      const SizedBox(height: 10),
      TextField(
          controller: line.description,
          decoration:
              const InputDecoration(labelText: 'Description (optional)')),
    ]);
  }

  Widget _adjustmentsCard() {
    return SectionCard(
      title: 'Tax & adjustments',
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: 150,
              child: TextField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Discount %'))),
          SizedBox(
              width: 165,
              child: TextField(
                  controller: _shipping,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Freight / shipping'))),
          if (def.kind == 'invoice' || def.kind == 'bill')
            SizedBox(
                width: 125,
                child: TextField(
                    controller: _tds,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'TDS %'))),
          if (def.kind == 'invoice')
            SizedBox(
                width: 125,
                child: TextField(
                    controller: _tcs,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'TCS %'))),
          SizedBox(
              width: 240,
              child: TextField(
                  controller: _reference,
                  decoration:
                      const InputDecoration(labelText: 'Reference number'))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 22, runSpacing: 8, children: [
          FilterChip(
              label: const Text('GST inclusive prices'),
              selected: _inclusive,
              onSelected: (v) {
                setState(() => _inclusive = v);
                _queuePreview();
              }),
          if (def.kind == 'invoice')
            FilterChip(
                label: const Text('Reverse charge'),
                selected: _rcm,
                onSelected: (v) {
                  setState(() => _rcm = v);
                  _queuePreview();
                }),
          if (def.kind == 'bill')
            FilterChip(
                label: const Text('Claim ITC'),
                selected: _itc,
                onSelected: (v) => setState(() => _itc = v)),
          FilterChip(
              label: Text(_postOnCreate ? 'Post on save' : 'Save as draft'),
              selected: _postOnCreate,
              onSelected: (v) => setState(() => _postOnCreate = v)),
        ]),
      ]),
    );
  }

  Widget _notesCard() => SectionCard(
        title: 'Notes & terms',
        child: Column(children: [
          TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 12),
          TextField(
              controller: _terms,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Terms & conditions')),
        ]),
      );

  Widget _summaryCard() {
    final p = _preview;
    final localSubtotal = _lines.fold<double>(0, (sum, l) {
      final qty = double.tryParse(l.quantity.text) ?? 0;
      final rate = double.tryParse(l.rate.text) ?? 0;
      final disc = double.tryParse(l.discount.text) ?? 0;
      return sum + (qty * rate - disc);
    });
    final total = p?['total'] ?? localSubtotal;
    final cgst = p?['cgst_amount'] ?? 0;
    final sgst = p?['sgst_amount'] ?? 0;
    final igst = p?['igst_amount'] ?? 0;
    final cess = p?['cess_amount'] ?? 0;
    return SectionCard(
      title: 'Summary',
      trailing: _previewing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      child: Column(children: [
        _summaryRow(
            'Taxable / subtotal', money(p?['subtotal'] ?? localSubtotal)),
        if (def.hasPreview) ...[
          _summaryRow('CGST', money(cgst)),
          _summaryRow(
              'SGST / UTGST',
              money((num.tryParse('$sgst') ?? 0) +
                  (num.tryParse('${p?['utgst_amount'] ?? 0}') ?? 0))),
          _summaryRow('IGST', money(igst)),
          if ((num.tryParse('$cess') ?? 0) != 0)
            _summaryRow('Cess', money(cess)),
          _summaryRow('Round off', money(p?['round_off'] ?? 0)),
        ],
        const Divider(height: 22),
        Row(children: [
          const Expanded(
              child: Text('Grand total',
                  style: TextStyle(fontWeight: FontWeight.w900))),
          Text(money(total),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))
        ]),
        if (def.hasPreview) ...[
          const SizedBox(height: 10),
          const Text(
              'Tax split is calculated by the FastAPI GST engine. The server remains authoritative.',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
        const SizedBox(height: 18),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving…' : 'Save ${def.title}'))),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child:
                  Text(label, style: const TextStyle(color: AppColors.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700))
        ]),
      );
}

class _DateField extends StatelessWidget {
  const _DateField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final picked = await pickDate(context, value);
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_month_outlined)),
          child: Text(displayDate(value.toIso8601String())),
        ),
      );
}

class _LineDraft {
  _LineDraft() {
    for (final c in [quantity, rate, discount, hsn, gst, description]) {
      c.addListener(_notify);
    }
  }

  String? productId;
  final quantity = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  final discount = TextEditingController(text: '0');
  final hsn = TextEditingController();
  final gst = TextEditingController(text: '18');
  final description = TextEditingController();
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void _notify() {
    for (final listener in List<VoidCallback>.from(_listeners)) listener();
  }

  void dispose() {
    quantity.dispose();
    rate.dispose();
    discount.dispose();
    hsn.dispose();
    gst.dispose();
    description.dispose();
  }
}

class _DocDef {
  const _DocDef({
    required this.kind,
    required this.title,
    required this.endpoint,
    required this.numberKey,
    required this.numberLabel,
    required this.dateKey,
    required this.dateLabel,
    required this.vendor,
    required this.extendedTaxFields,
    required this.hasPreview,
    this.numberOptional = false,
  });

  final String kind;
  final String title;
  final String endpoint;
  final String numberKey;
  final String numberLabel;
  final String dateKey;
  final String dateLabel;
  final bool vendor;
  final bool extendedTaxFields;
  final bool hasPreview;
  final bool numberOptional;

  factory _DocDef.fromName(String name) => switch (name) {
        'invoice' => const _DocDef(
            kind: 'invoice',
            title: 'Invoice',
            endpoint: '/invoices',
            numberKey: 'invoice_number',
            numberLabel: 'Invoice number',
            dateKey: 'issue_date',
            dateLabel: 'Invoice date',
            vendor: false,
            extendedTaxFields: true,
            hasPreview: true,
            numberOptional: true),
        'bill' => const _DocDef(
            kind: 'bill',
            title: 'Purchase Bill',
            endpoint: '/bills',
            numberKey: 'bill_number',
            numberLabel: 'Supplier bill number',
            dateKey: 'issue_date',
            dateLabel: 'Bill date',
            vendor: true,
            extendedTaxFields: true,
            hasPreview: true),
        'proforma' => const _DocDef(
            kind: 'proforma',
            title: 'Proforma',
            endpoint: '/proforma-invoices',
            numberKey: 'proforma_number',
            numberLabel: 'Proforma number',
            dateKey: 'issue_date',
            dateLabel: 'Issue date',
            vendor: false,
            extendedTaxFields: false,
            hasPreview: false),
        'salesOrder' => const _DocDef(
            kind: 'salesOrder',
            title: 'Sales Order',
            endpoint: '/sales-orders',
            numberKey: 'so_number',
            numberLabel: 'Sales order number',
            dateKey: 'order_date',
            dateLabel: 'Order date',
            vendor: false,
            extendedTaxFields: false,
            hasPreview: false),
        'purchaseOrder' => const _DocDef(
            kind: 'purchaseOrder',
            title: 'Purchase Order',
            endpoint: '/purchase-orders',
            numberKey: 'po_number',
            numberLabel: 'Purchase order number',
            dateKey: 'order_date',
            dateLabel: 'Order date',
            vendor: true,
            extendedTaxFields: false,
            hasPreview: false),
        'challan' => const _DocDef(
            kind: 'challan',
            title: 'Delivery Challan',
            endpoint: '/delivery-challans',
            numberKey: 'challan_number',
            numberLabel: 'Challan number',
            dateKey: 'challan_date',
            dateLabel: 'Challan date',
            vendor: false,
            extendedTaxFields: false,
            hasPreview: false),
        _ => throw ArgumentError('Unsupported document kind: $name'),
      };
}
