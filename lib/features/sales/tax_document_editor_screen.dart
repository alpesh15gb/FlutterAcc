import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class TaxDocumentEditorScreen extends StatefulWidget {
  const TaxDocumentEditorScreen({
    super.key,
    required this.api,
    required this.kindName,
    this.initialId,
  });

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

  /// null deliberately means the user has not chosen a rate interpretation yet.
  /// We never silently assume inclusive/exclusive for invoices or bills.
  bool? _inclusive;
  bool _rcm = false;
  bool _itc = true;
  bool _postOnCreate = true;
  bool _loading = true;
  bool _saving = false;
  bool _previewing = false;
  String? _error;
  String? _previewError;
  Map<String, dynamic>? _preview;

  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _products = [];
  final List<_LineDraft> _lines = [_LineDraft()];
  Timer? _previewDebounce;

  _DocDef get def => _DocDef.fromName(widget.kindName);
  bool get _editing => widget.initialId != null;
  bool get _requiresTaxChoice => def.extendedTaxFields;

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
      _terms,
    ]) {
      c.dispose();
    }
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMasters() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final contactData = await widget.api.get('/masters/contacts', query: {
        'contact_type': def.vendor ? 'VENDOR' : 'CUSTOMER',
        'limit': 100,
      });
      final productData =
          await widget.api.get('/masters/products', query: {'limit': 100});

      Map<String, dynamic>? existing;
      if (_editing) {
        existing = Map<String, dynamic>.from(
          await widget.api.get('${def.endpoint}/${widget.initialId}') as Map,
        );
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
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _parseDate(Object? value, DateTime fallback) {
    return DateTime.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _applyExisting(Map<String, dynamic> data) {
    _contactId = data['contact_id']?.toString() ??
        (data['contact'] is Map
            ? (data['contact'] as Map)['id']?.toString()
            : null);
    _number.text = data[def.numberKey]?.toString() ?? '';
    _date = _parseDate(data[def.dateKey], _date);
    _dueDate = _parseDate(data['due_date'], _dueDate);
    if (data['pos_state_code'] != null) {
      _pos.text = data['pos_state_code'].toString();
    }
    _discount.text = '${data['discount_rate'] ?? 0}';
    _shipping.text = '${data['shipping_charges'] ?? 0}';
    _tds.text = '${data['tds_rate'] ?? 0}';
    _tcs.text = '${data['tcs_rate'] ?? 0}';
    _reference.text = data['reference_number']?.toString() ?? '';
    _notes.text = data['notes']?.toString() ?? '';
    _terms.text = data['terms_and_conditions']?.toString() ?? '';
    if (_requiresTaxChoice) {
      _inclusive = data['is_gst_inclusive'] == true;
    }
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
    if (!def.hasPreview) {
      if (mounted) setState(() {});
      return;
    }
    _previewDebounce?.cancel();
    _previewDebounce =
        Timer(const Duration(milliseconds: 400), _previewDocument);
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
        'is_gst_inclusive': _inclusive ?? false,
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

  String _previewPath() => switch (def.kind) {
        'bill' => '/bills/preview',
        'proforma' => '/proforma-invoices/preview',
        _ => '/invoices/preview',
      };

  Future<void> _previewDocument() async {
    if (!def.hasPreview ||
        _contactId == null ||
        _lines.any((line) => line.productId == null)) {
      return;
    }
    if (_requiresTaxChoice && _inclusive == null) return;
    if (_lines.any((line) =>
        (double.tryParse(line.quantity.text) ?? 0) <= 0 ||
        (double.tryParse(line.rate.text) ?? -1) < 0)) {
      return;
    }
    if (_pos.text.trim().length != 2) return;

    if (mounted) {
      setState(() {
        _previewing = true;
        _previewError = null;
      });
    }
    try {
      final data =
          await widget.api.post(_previewPath(), body: _payload(preview: true));
      if (!mounted) return;
      setState(() => _preview = Map<String, dynamic>.from(data as Map));
    } catch (e) {
      if (mounted) setState(() => _previewError = e.toString());
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  String? _validateDocument() {
    if (_contactId == null) {
      return 'Select a ${def.vendor ? 'vendor' : 'customer'}.';
    }
    if (!def.numberOptional && _number.text.trim().isEmpty) {
      return 'Enter the ${def.numberLabel.toLowerCase()}.';
    }
    if (def.kind == 'invoice' && _number.text.trim().length > 16) {
      return 'GST invoice numbers must be 16 characters or fewer.';
    }
    if (_pos.text.trim().length != 2 ||
        int.tryParse(_pos.text.trim()) == null) {
      return 'Place of supply must be a two-digit GST state code.';
    }
    if (_dueDate.isBefore(_date)) {
      return 'Due date cannot be before the document date.';
    }
    if (_requiresTaxChoice && _inclusive == null) {
      return 'Choose whether the entered rates INCLUDE GST or EXCLUDE GST.';
    }

    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.productId == null) return 'Select an item on line ${i + 1}.';
      if ((double.tryParse(line.quantity.text) ?? 0) <= 0) {
        return 'Line ${i + 1}: quantity must be greater than zero.';
      }
      if ((double.tryParse(line.rate.text) ?? -1) < 0) {
        return 'Line ${i + 1}: rate cannot be negative.';
      }
      if (line.hsn.text.trim().length < 4) {
        return 'Line ${i + 1}: enter a valid HSN/SAC.';
      }
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
      if (!mounted) return;
      showMessage(
        context,
        _editing ? '${def.title} updated.' : '${def.title} saved.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _selectTaxMode(bool inclusive) {
    setState(() {
      _inclusive = inclusive;
      _preview = null;
      _previewError = null;
    });
    _queuePreview();
  }

  void _addLine() {
    final line = _LineDraft();
    line.addListener(_queuePreview);
    setState(() => _lines.add(line));
    _queuePreview();
  }

  void _removeLine(int index) {
    if (_lines.length == 1) return;
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
    _queuePreview();
  }

  void _selectProduct(_LineDraft line, String? productId) {
    setState(() => line.productId = productId);
    final match =
        _products.where((p) => p['id']?.toString() == productId).toList();
    if (match.isNotEmpty) {
      final product = match.first;
      line.rate.text =
          '${def.vendor ? product['purchase_price'] ?? 0 : product['sales_price'] ?? 0}';
      line.hsn.text = '${product['hsn_sac'] ?? ''}';
      line.gst.text = '${product['gst_rate'] ?? 0}';
      if (line.description.text.trim().isEmpty) {
        line.description.text = '${product['name'] ?? ''}';
      }
    }
    _queuePreview();
  }

  _LocalEstimate get _estimate {
    var entered = 0.0;
    var taxable = 0.0;
    var tax = 0.0;

    for (final line in _lines) {
      final qty = double.tryParse(line.quantity.text) ?? 0;
      final rate = double.tryParse(line.rate.text) ?? 0;
      final discount = double.tryParse(line.discount.text) ?? 0;
      final gst = double.tryParse(line.gst.text) ?? 0;
      final grossLine =
          (qty * rate - discount).clamp(0.0, double.infinity).toDouble();
      entered += grossLine;

      if (_inclusive == true && gst > 0) {
        final base = grossLine / (1 + gst / 100);
        taxable += base;
        tax += grossLine - base;
      } else {
        taxable += grossLine;
        tax += grossLine * gst / 100;
      }
    }

    final total = _inclusive == true ? entered : taxable + tax;
    return _LocalEstimate(
      entered: entered,
      taxable: taxable,
      tax: tax,
      total: total,
    );
  }

  String get _rateLabel {
    if (!def.extendedTaxFields) return 'Rate (GST excluded)';
    if (_inclusive == true) return 'Rate (GST included)';
    if (_inclusive == false) return 'Rate (GST excluded)';
    return 'Rate — choose GST mode';
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
              icon: const Icon(Icons.calculate_outlined),
            ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorPanel(message: _error!, onRetry: _loadMasters),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1320),
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final wide = c.maxWidth >= 1000;
                            final form = Column(children: [
                              _headerCard(),
                              const SizedBox(height: 14),
                              _taxModeCard(),
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
                                _summaryCard(),
                              ]);
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: form),
                                const SizedBox(width: 14),
                                SizedBox(width: 340, child: _summaryCard()),
                              ],
                            );
                          },
                        ),
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
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id']?.toString(),
                    child: Text(
                      c['name']?.toString() ?? 'Party',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _contactId = value);
              final contact =
                  _contacts.where((c) => c['id']?.toString() == value).toList();
              if (contact.isNotEmpty && contact.first['state_code'] != null) {
                _pos.text = contact.first['state_code'].toString();
              }
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
              hintText: def.numberOptional ? 'Auto if blank' : null,
            ),
          ),
        ),
        SizedBox(
          width: 210,
          child: _DateField(
            label: def.dateLabel,
            value: _date,
            onChanged: (value) {
              setState(() => _date = value);
              _queuePreview();
            },
          ),
        ),
        SizedBox(
          width: 210,
          child: _DateField(
            label: 'Due date',
            value: _dueDate,
            onChanged: (value) => setState(() => _dueDate = value),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _pos,
            maxLength: 2,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'POS state',
              helperText: '2-digit GST code',
              counterText: '',
            ),
          ),
        ),
        if (def.kind == 'invoice')
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              value: _supplyType,
              decoration: const InputDecoration(labelText: 'Supply type'),
              items: const [
                DropdownMenuItem(value: 'DOMESTIC', child: Text('Domestic')),
                DropdownMenuItem(
                    value: 'EXPORT_WITH_TAX', child: Text('Export with tax')),
                DropdownMenuItem(
                    value: 'EXPORT_WITHOUT_TAX',
                    child: Text('Export without tax / LUT')),
                DropdownMenuItem(
                    value: 'SEZ_WITH_TAX', child: Text('SEZ with tax')),
                DropdownMenuItem(
                    value: 'SEZ_WITHOUT_TAX', child: Text('SEZ without tax')),
              ],
              onChanged: (value) {
                setState(() => _supplyType = value ?? 'DOMESTIC');
                _queuePreview();
              },
            ),
          ),
      ]),
    );
  }

  Widget _taxModeCard() {
    if (!def.extendedTaxFields) {
      return SectionCard(
        title: 'GST rate mode',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(.25)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'GST EXCLUDED: this document type treats the entered rate as the taxable rate and adds GST on top. The rate field below is labelled accordingly.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      title: 'GST rate mode — required',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What does the rate you type already contain? Choose before saving so GST is never silently added or extracted.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ChoiceChip(
              avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('GST INCLUDED in entered rate'),
              selected: _inclusive == true,
              onSelected: (_) => _selectTaxMode(true),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('GST EXCLUDED — add GST on top'),
              selected: _inclusive == false,
              onSelected: (_) => _selectTaxMode(false),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            _inclusive == true
                ? 'Example: ₹16,500 @ 18% stays ₹16,500 payable; the server extracts about ₹2,516.95 GST from the entered amount.'
                : _inclusive == false
                    ? 'Example: ₹16,500 @ 18% becomes ₹19,470 payable because ₹2,970 GST is added on top.'
                    : 'No mode selected. Saving and tax preview are blocked until you choose one.',
            style: TextStyle(
              color: _inclusive == null ? AppColors.danger : AppColors.muted,
              fontWeight:
                  _inclusive == null ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItemsCard() {
    return SectionCard(
      title: 'Items',
      trailing: TextButton.icon(
        onPressed: _addLine,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add line'),
      ),
      child: Column(
        children: List.generate(_lines.length, (index) {
          final line = _lines[index];
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == _lines.length - 1 ? 0 : 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 310,
                    child: DropdownButtonFormField<String>(
                      value: line.productId,
                      isExpanded: true,
                      decoration:
                          InputDecoration(labelText: 'Item ${index + 1}'),
                      items: _products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p['id']?.toString(),
                              child: Text(
                                p['name']?.toString() ?? 'Item',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => _selectProduct(line, value),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: line.quantity,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  SizedBox(
                    width: 185,
                    child: TextField(
                      controller: line.rate,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _rateLabel,
                        helperText: _inclusive == true
                            ? 'GST already inside'
                            : _inclusive == false || !def.extendedTaxFields
                                ? 'GST added on top'
                                : 'Choose mode above',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 135,
                    child: TextField(
                      controller: line.discount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Line discount'),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: line.hsn,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'HSN/SAC'),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: line.gst,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'GST %'),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: line.description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove line',
                    onPressed:
                        _lines.length == 1 ? null : () => _removeLine(index),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _adjustmentsCard() {
    return SectionCard(
      title: 'Adjustments & tax options',
      child: Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(
          width: 160,
          child: TextField(
            controller: _discount,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Discount %'),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            controller: _shipping,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Shipping'),
          ),
        ),
        if (def.kind == 'invoice')
          SizedBox(
            width: 145,
            child: TextField(
              controller: _tds,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'TDS %'),
            ),
          ),
        if (def.kind == 'invoice')
          SizedBox(
            width: 145,
            child: TextField(
              controller: _tcs,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'TCS %'),
            ),
          ),
        if (def.kind == 'bill')
          SizedBox(
            width: 145,
            child: TextField(
              controller: _tds,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'TDS %'),
            ),
          ),
        if (def.kind == 'invoice')
          FilterChip(
            label: const Text('Reverse charge'),
            selected: _rcm,
            onSelected: (value) {
              setState(() => _rcm = value);
              _queuePreview();
            },
          ),
        if (def.kind == 'bill')
          FilterChip(
            label: const Text('ITC eligible'),
            selected: _itc,
            onSelected: (value) => setState(() => _itc = value),
          ),
        if (!_editing)
          FilterChip(
            label: const Text('Post on create'),
            selected: _postOnCreate,
            onSelected: (value) => setState(() => _postOnCreate = value),
          ),
      ]),
    );
  }

  Widget _notesCard() {
    return SectionCard(
      title: 'Reference & notes',
      child: Column(children: [
        TextField(
          controller: _reference,
          decoration: const InputDecoration(labelText: 'Reference number'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _terms,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Terms & conditions'),
        ),
      ]),
    );
  }

  Widget _summaryCard() {
    final server = _preview;
    final estimate = _estimate;
    final modeText = !def.extendedTaxFields
        ? 'GST EXCLUDED — added on top'
        : _inclusive == true
            ? 'GST INCLUDED in entered rate'
            : _inclusive == false
                ? 'GST EXCLUDED — added on top'
                : 'SELECT GST RATE MODE';

    final taxable = server?['subtotal'] ?? estimate.taxable;
    final grandTotal = server?['total'] ?? estimate.total;
    final cgst = server?['cgst_amount'] ?? 0;
    final sgst = server?['sgst_amount'] ?? 0;
    final utgst = server?['utgst_amount'] ?? 0;
    final igst = server?['igst_amount'] ?? 0;
    final cess = server?['cess_amount'] ?? 0;

    return SectionCard(
      title: 'Summary',
      trailing: _previewing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (_inclusive == null && _requiresTaxChoice
                    ? AppColors.danger
                    : AppColors.primary)
                .withOpacity(.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            modeText,
            style: TextStyle(
              color: _inclusive == null && _requiresTaxChoice
                  ? AppColors.danger
                  : AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _summaryRow('Entered line amount', money(estimate.entered)),
        _summaryRow(
          _inclusive == true ? 'Taxable (GST extracted)' : 'Taxable value',
          money(taxable),
        ),
        if (server != null) ...[
          _summaryRow('CGST', money(cgst)),
          _summaryRow(
            'SGST / UTGST',
            money((num.tryParse('$sgst') ?? 0) +
                (num.tryParse('$utgst') ?? 0)),
          ),
          _summaryRow('IGST', money(igst)),
          if ((num.tryParse('$cess') ?? 0) != 0)
            _summaryRow('Cess', money(cess)),
          _summaryRow('Round off', money(server['round_off'] ?? 0)),
        ] else
          _summaryRow('Estimated GST', money(estimate.tax)),
        const Divider(height: 22),
        Row(children: [
          const Expanded(
            child: Text(
              'Grand total',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            money(grandTotal),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
        ]),
        if (_previewError != null) ...[
          const SizedBox(height: 10),
          Text(
            'Tax preview error: $_previewError',
            style: const TextStyle(color: AppColors.danger, fontSize: 11),
          ),
        ] else if (def.hasPreview) ...[
          const SizedBox(height: 10),
          Text(
            server == null
                ? 'Shown values are an estimate until the FastAPI tax preview responds.'
                : 'Taxable value, GST split and total above came from the FastAPI preview.',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Saving…' : 'Save ${def.title}'),
          ),
        ),
      ]),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

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
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
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
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
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

class _LocalEstimate {
  const _LocalEstimate({
    required this.entered,
    required this.taxable,
    required this.tax,
    required this.total,
  });

  final double entered;
  final double taxable;
  final double tax;
  final double total;
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
            hasPreview: true),
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
