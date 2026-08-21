import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.api, required this.credit});
  final ApiClient api;
  final bool credit;
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String get _endpoint =>
      widget.credit ? '/invoices/credit-notes' : '/invoices/debit-notes';
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
      final d = await widget.api.get(_endpoint);
      _items =
          (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    try {
      final raw = await widget.api.get('/invoices', query: {'limit': 100});
      final data = raw is Map ? raw['items'] : raw;
      final docs = (data as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((i) => ['POSTED', 'SENT', 'PARTIALLY_PAID', 'PAID']
              .contains(i['status']))
          .toList();
      if (!mounted) return;
      if (docs.isEmpty) {
        showMessage(context, 'No posted invoice is available.', error: true);
        return;
      }
      final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => _NoteEditor(
                  api: widget.api, credit: widget.credit, invoices: docs)));
      if (saved == true) _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _action(Map<String, dynamic> r, String action) async {
    try {
      if (action == 'delete') {
        await widget.api.delete('$_endpoint/${r['id']}');
      } else {
        await widget.api.post('$_endpoint/${r['id']}/$action');
      }
      if (mounted) {
        showMessage(
            context,
            '${widget.credit ? 'Credit' : 'Debit'} note ${action == 'finalize' ? 'posted' : action == 'cancel' ? 'cancelled' : 'removed'}.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: widget.credit ? 'Credit Notes' : 'Debit Notes',
        subtitle: widget.credit
            ? 'Reduce customer receivables/output GST; optionally restock returned goods.'
            : 'Add a price/value debit against a customer with full GST posting.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            label: Text(widget.credit ? 'New credit note' : 'New debit note'),
          ),
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: widget.credit
                            ? Icons.assignment_return_outlined
                            : Icons.note_add_outlined,
                        title: 'No ${widget.credit ? 'credit' : 'debit'} notes',
                        message:
                            'Create a note from a posted invoice when a value adjustment is required.',
                        action: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create note')),
                      )
                    : Column(
                        children: _items.map((r) {
                          final number = widget.credit
                              ? r['credit_note_number']
                              : r['debit_note_number'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                    child: Icon(widget.credit
                                        ? Icons.assignment_return_outlined
                                        : Icons.note_add_outlined)),
                                title: Row(children: [
                                  Expanded(
                                      child: Text('$number',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  Text(money(r['total']),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                ]),
                                subtitle: Text(
                                    '${r['contact_name'] ?? ''} • ${displayDate(r['issue_date'])} • ${r['status'] ?? ''}\n${r['reason'] ?? ''}'),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) => _action(r, v),
                                  itemBuilder: (_) {
                                    final status =
                                        '${r['status'] ?? ''}'.toUpperCase();
                                    return [
                                      if (status == 'DRAFT')
                                        const PopupMenuItem(
                                            value: 'finalize',
                                            child: Text('Finalize / post')),
                                      if (status == 'DRAFT')
                                        const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete draft')),
                                      if (status == 'POSTED')
                                        const PopupMenuItem(
                                            value: 'cancel',
                                            child: Text('Cancel & reverse')),
                                    ];
                                  },
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
      );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor(
      {required this.api, required this.credit, required this.invoices});
  final ApiClient api;
  final bool credit;
  final List<Map<String, dynamic>> invoices;
  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  String? _invoiceId;
  Map<String, dynamic>? _invoice;
  String? _productId;
  DateTime _date = DateTime.now();
  final _reason = TextEditingController(),
      _qty = TextEditingController(text: '1'),
      _rate = TextEditingController(),
      _discount = TextEditingController(text: '0'),
      _hsn = TextEditingController(),
      _gst = TextEditingController();
  bool _restock = false, _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _invoiceId = '${widget.invoices.first['id']}';
    _loadInvoice();
  }

  @override
  void dispose() {
    for (final c in [_reason, _qty, _rate, _discount, _hsn, _gst]) c.dispose();
    super.dispose();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = Map<String, dynamic>.from(
          await widget.api.get('/invoices/$_invoiceId') as Map);
      final lines = d['lines'] is List ? d['lines'] as List : const [];
      _invoice = d;
      if (lines.isNotEmpty) {
        final l = Map<String, dynamic>.from(lines.first as Map);
        _productId = '${l['product_id']}';
        _rate.text = '${l['rate'] ?? 0}';
        _hsn.text = '${l['hsn_sac'] ?? ''}';
        _gst.text = '${l['gst_rate'] ?? 0}';
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic>? get _selectedLine {
    if (_invoice?['lines'] is! List) return null;
    for (final raw in _invoice!['lines'] as List) {
      final l = Map<String, dynamic>.from(raw as Map);
      if ('${l['product_id']}' == _productId) return l;
    }
    return null;
  }

  void _selectProduct(String? v) {
    setState(() => _productId = v);
    final l = _selectedLine;
    if (l != null) {
      _rate.text = '${l['rate'] ?? 0}';
      _hsn.text = '${l['hsn_sac'] ?? ''}';
      _gst.text = '${l['gst_rate'] ?? 0}';
    }
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qty.text) ?? 0,
        rate = double.tryParse(_rate.text) ?? -1;
    if (_reason.text.trim().isEmpty ||
        qty <= 0 ||
        rate < 0 ||
        _productId == null) {
      showMessage(context, 'Reason, item, quantity and rate are required.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'invoice_id': _invoiceId,
        'issue_date': apiDate(_date),
        'reason': _reason.text.trim(),
        'line_items': [
          {
            'product_id': _productId,
            'quantity': qty,
            'rate': rate,
            'discount': double.tryParse(_discount.text) ?? 0,
            'hsn_sac': _hsn.text.trim(),
            'gst_rate': double.tryParse(_gst.text) ?? 0
          }
        ]
      };
      if (widget.credit) body['restock_items'] = _restock;
      await widget.api.post(
          widget.credit ? '/invoices/credit-notes' : '/invoices/debit-notes',
          body: body);
      if (mounted) {
        showMessage(context,
            '${widget.credit ? 'Credit' : 'Debit'} note saved as draft. Finalize it to post to the ledger.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text('New ${widget.credit ? 'credit' : 'debit'} note'),
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Posting…' : 'Post note')))
          ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(children: [
                    SectionCard(
                        title: 'Source invoice',
                        child: Wrap(spacing: 12, runSpacing: 12, children: [
                          SizedBox(
                              width: 520,
                              child: DropdownButtonFormField<String>(
                                  value: _invoiceId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Posted invoice'),
                                  items: widget.invoices
                                      .map((i) => DropdownMenuItem(
                                          value: '${i['id']}',
                                          child: Text(
                                              '${i['invoice_number']} • ${i['contact_name']} • ${money(i['total'])}')))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() => _invoiceId = v);
                                    _loadInvoice();
                                  })),
                          SizedBox(
                              width: 220,
                              child: InkWell(
                                  onTap: () async {
                                    final d = await pickDate(context, _date);
                                    if (d != null) setState(() => _date = d);
                                  },
                                  child: InputDecorator(
                                      decoration: const InputDecoration(
                                          labelText: 'Note date'),
                                      child: Text(displayDate(
                                          _date.toIso8601String()))))),
                          SizedBox(
                              width: 760,
                              child: TextField(
                                  controller: _reason,
                                  decoration: const InputDecoration(
                                      labelText: 'Reason *'))),
                          if (widget.credit)
                            SizedBox(
                                width: 320,
                                child: SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Restock returned goods'),
                                    value: _restock,
                                    onChanged: (v) =>
                                        setState(() => _restock = v)))
                        ])),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator())
                    else if (_error != null)
                      ErrorPanel(message: _error!, onRetry: _loadInvoice)
                    else
                      SectionCard(
                          title: 'Adjustment line',
                          child: Wrap(spacing: 12, runSpacing: 12, children: [
                            SizedBox(
                                width: 370,
                                child: DropdownButtonFormField<String>(
                                    value: _productId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Invoice item'),
                                    items: (_invoice?['lines'] as List? ??
                                            const [])
                                        .map((raw) {
                                      final l =
                                          Map<String, dynamic>.from(raw as Map);
                                      return DropdownMenuItem(
                                          value: '${l['product_id']}',
                                          child: Text(
                                              '${l['product_name'] ?? l['description'] ?? 'Item'}'));
                                    }).toList(),
                                    onChanged: _selectProduct)),
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
                                width: 150,
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
                            const SizedBox(
                                width: 760,
                                child: Text(
                                    'The backend recalculates the GST split from this adjustment and posts a balanced reversing/additional journal entry.',
                                    style: TextStyle(
                                        color: AppColors.muted, fontSize: 12)))
                          ]))
                  ])))));
}
