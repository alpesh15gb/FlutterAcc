import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.api,
    required this.credit,
  });

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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await widget.api.get(_endpoint);
      if (!mounted) return;
      setState(() {
        _items = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    try {
      final raw = await widget.api.get('/invoices', query: {'limit': 100});
      final data = raw is Map ? raw['items'] : raw;
      final invoices = (data as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((invoice) => const {
                'POSTED',
                'SENT',
                'PARTIALLY_PAID',
                'PAID',
              }.contains('${invoice['status']}'.toUpperCase()))
          .toList();

      if (!mounted) return;
      if (invoices.isEmpty) {
        showMessage(context, 'No posted invoice is available.', error: true);
        return;
      }

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _NoteEditor(
            api: widget.api,
            credit: widget.credit,
            invoices: invoices,
          ),
        ),
      );
      if (saved == true) _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _action(Map<String, dynamic> row, String action) async {
    try {
      if (action == 'delete') {
        await widget.api.delete('$_endpoint/${row['id']}');
      } else {
        await widget.api.post('$_endpoint/${row['id']}/$action');
      }
      if (!mounted) return;
      showMessage(
        context,
        '${widget.credit ? 'Credit' : 'Debit'} note '
        '${action == 'finalize' ? 'posted' : action == 'cancel' ? 'cancelled and reversed' : 'removed'}.',
      );
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: widget.credit ? 'Credit Notes' : 'Debit Notes',
        subtitle: widget.credit
            ? 'Reduce customer receivables/output GST using the source invoice tax basis.'
            : 'Add a value debit using the source invoice tax basis.',
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
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: widget.credit
                            ? Icons.assignment_return_outlined
                            : Icons.note_add_outlined,
                        title:
                            'No ${widget.credit ? 'credit' : 'debit'} notes',
                        message:
                            'Create a note from a posted invoice when a value adjustment is required.',
                        action: FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create note'),
                        ),
                      )
                    : Column(
                        children: _items.map((row) {
                          final status =
                              '${row['status'] ?? ''}'.toUpperCase();
                          final number = widget.credit
                              ? row['credit_note_number']
                              : row['debit_note_number'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    widget.credit
                                        ? Icons.assignment_return_outlined
                                        : Icons.note_add_outlined,
                                  ),
                                ),
                                title: Row(children: [
                                  Expanded(
                                    child: Text(
                                      '$number',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  Text(
                                    money(row['total']),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900),
                                  ),
                                ]),
                                subtitle: Text(
                                  '${row['contact_name'] ?? ''} • '
                                  '${displayDate(row['issue_date'])} • $status\n'
                                  '${row['reason'] ?? ''}',
                                ),
                                isThreeLine: true,
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) => _action(row, value),
                                  itemBuilder: (_) => [
                                    if (status == 'DRAFT')
                                      const PopupMenuItem(
                                        value: 'finalize',
                                        child: Text('Finalize / post'),
                                      ),
                                    if (status == 'DRAFT')
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete draft'),
                                      ),
                                    if (status == 'POSTED')
                                      const PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel & reverse'),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
      );
}

class _NoteEditor extends StatefulWidget {
  const _NoteEditor({
    required this.api,
    required this.credit,
    required this.invoices,
  });

  final ApiClient api;
  final bool credit;
  final List<Map<String, dynamic>> invoices;

  @override
  State<_NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<_NoteEditor> {
  String? _invoiceId;
  Map<String, dynamic>? _invoice;
  String? _lineId;
  DateTime _date = DateTime.now();

  final _reason = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _rate = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _hsn = TextEditingController();
  final _gst = TextEditingController();

  bool _restock = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _sourceInclusive => _invoice?['is_gst_inclusive'] == true;

  @override
  void initState() {
    super.initState();
    _invoiceId = '${widget.invoices.first['id']}';
    _loadInvoice();
  }

  @override
  void dispose() {
    for (final c in [_reason, _qty, _rate, _discount, _hsn, _gst]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _invoiceLines =>
      (_invoice?['lines'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Map<String, dynamic>? get _selectedLine {
    for (final line in _invoiceLines) {
      if ('${line['id']}' == _lineId) return line;
    }
    return null;
  }

  double _taxableUnitRate(Map<String, dynamic> line) {
    final quantity = num.tryParse('${line['quantity'] ?? 0}')?.toDouble() ?? 0;
    final subtotal = num.tryParse('${line['subtotal'] ?? ''}')?.toDouble();
    if (quantity > 0 && subtotal != null) return subtotal / quantity;
    return num.tryParse('${line['rate'] ?? 0}')?.toDouble() ?? 0;
  }

  void _syncLine(Map<String, dynamic> line) {
    _lineId = '${line['id']}';
    _qty.text = '1';

    // The credit/debit-note API expects an EXCLUSIVE taxable rate. For an
    // inclusive source invoice, use the posted taxable unit value so GST is
    // never added a second time.
    final rate = _sourceInclusive
        ? _taxableUnitRate(line)
        : (num.tryParse('${line['rate'] ?? 0}')?.toDouble() ?? 0);
    _rate.text = formatNumber(rate);
    _discount.text = '0';
    _hsn.text = '${line['hsn_sac'] ?? ''}';
    _gst.text = '${line['gst_rate'] ?? 0}';
  }

  Future<void> _loadInvoice() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = Map<String, dynamic>.from(
        await widget.api.get('/invoices/$_invoiceId') as Map,
      );
      if (!mounted) return;
      setState(() {
        _invoice = data;
        final lines = _invoiceLines;
        if (lines.isNotEmpty) _syncLine(lines.first);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectLine(String? lineId) {
    final match = _invoiceLines.where((line) => '${line['id']}' == lineId);
    if (match.isEmpty) return;
    setState(() => _syncLine(match.first));
  }

  Future<void> _save() async {
    final quantity = double.tryParse(_qty.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? -1;
    if (_reason.text.trim().isEmpty ||
        quantity <= 0 ||
        rate < 0 ||
        _selectedLine == null) {
      showMessage(
        context,
        'Reason, source line, quantity and taxable rate are required.',
        error: true,
      );
      return;
    }

    final sourceQuantity =
        num.tryParse('${_selectedLine!['quantity'] ?? 0}')?.toDouble() ?? 0;
    if (quantity > sourceQuantity) {
      showMessage(
        context,
        'Adjustment quantity cannot exceed source quantity '
        '${formatNumber(sourceQuantity)}.',
        error: true,
      );
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
            'product_id': _selectedLine!['product_id'],
            'quantity': quantity,
            'rate': rate,
            'discount': double.tryParse(_discount.text) ?? 0,
            'hsn_sac': _hsn.text.trim(),
            'gst_rate': double.tryParse(_gst.text) ?? 0,
          }
        ],
      };
      if (widget.credit) body['restock_items'] = _restock;

      await widget.api.post(
        widget.credit ? '/invoices/credit-notes' : '/invoices/debit-notes',
        body: body,
      );

      if (!mounted) return;
      showMessage(
        context,
        '${widget.credit ? 'Credit' : 'Debit'} note saved as draft. '
        'Finalize it to post to the ledger.',
      );
      Navigator.pop(context, true);
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
                label: Text(_saving ? 'Saving…' : 'Save draft'),
              ),
            ),
          ],
        ),
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
                        decoration:
                            const InputDecoration(labelText: 'Posted invoice'),
                        items: widget.invoices
                            .map(
                              (invoice) => DropdownMenuItem(
                                value: '${invoice['id']}',
                                child: Text(
                                  '${invoice['invoice_number']} • '
                                  '${invoice['contact_name']} • '
                                  '${money(invoice['total'])}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _invoiceId = value);
                          _loadInvoice();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: InkWell(
                        onTap: () async {
                          final picked = await pickDate(context, _date);
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Note date'),
                          child: Text(displayDate(_date.toIso8601String())),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 760,
                      child: TextField(
                        controller: _reason,
                        decoration:
                            const InputDecoration(labelText: 'Reason *'),
                      ),
                    ),
                    if (widget.credit)
                      SizedBox(
                        width: 320,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Restock returned goods'),
                          value: _restock,
                          onChanged: (value) =>
                              setState(() => _restock = value),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 14),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator(),
                  )
                else if (_error != null)
                  ErrorPanel(message: _error!, onRetry: _loadInvoice)
                else ...[
                  SectionCard(
                    title: 'GST rate handling',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_sourceInclusive
                                ? AppColors.success
                                : AppColors.primary)
                            .withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _sourceInclusive
                            ? 'Source invoice rates INCLUDE GST. ApexBooks converts the selected source line to its posted TAXABLE rate before sending the note, preventing GST from being added twice.'
                            : 'Source invoice rates EXCLUDE GST. The note uses the source taxable rate and GST is calculated once on top.',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Adjustment line',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 370,
                          child: DropdownButtonFormField<String>(
                            value: _lineId,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Invoice line'),
                            items: _invoiceLines.map((line) {
                              return DropdownMenuItem(
                                value: '${line['id']}',
                                child: Text(
                                  '${line['product_name'] ?? line['description'] ?? 'Item'} • '
                                  'Qty ${formatNumber(line['quantity'])}',
                                ),
                              );
                            }).toList(),
                            onChanged: _selectLine,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _qty,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(labelText: 'Qty'),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _rate,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Taxable rate (GST excluded)',
                              helperText: 'Backend note basis',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _discount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'Discount'),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _hsn,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'HSN/SAC'),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _gst,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration:
                                const InputDecoration(labelText: 'GST %'),
                          ),
                        ),
                        const SizedBox(
                          width: 760,
                          child: Text(
                            'The source document determines the economic value. '
                            'For GST-inclusive invoices the taxable value is derived '
                            'from the posted source line before this note is created.',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );
}
