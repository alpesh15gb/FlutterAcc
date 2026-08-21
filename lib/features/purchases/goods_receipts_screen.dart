import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class GoodsReceiptsScreen extends StatefulWidget {
  const GoodsReceiptsScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<GoodsReceiptsScreen> createState() => _GoodsReceiptsScreenState();
}

class _GoodsReceiptsScreenState extends State<GoodsReceiptsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic d) {
    if (d is List) {
      return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (d is Map && d['items'] is List) {
      return (d['items'] as List)
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
      _items =
          _rows(await widget.api.get('/goods-receipts', query: {'limit': 100}));
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    try {
      final poRows = _rows(
          await widget.api.get('/purchase-orders', query: {'limit': 100}));
      final warehouses =
          _rows(await widget.api.get('/warehouses', query: {'limit': 100}))
              .where((w) => w['is_active'] != false)
              .toList();
      if (!mounted) return;
      if (poRows.isEmpty) {
        showMessage(context, 'Create a purchase order before receiving goods.',
            error: true);
        return;
      }
      final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => _GoodsReceiptEditor(
                  api: widget.api,
                  purchaseOrders: poRows,
                  warehouses: warehouses)));
      if (saved == true) _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _action(Map<String, dynamic> r, String action) async {
    try {
      await widget.api.post('/goods-receipts/${r['id']}/$action');
      if (mounted) {
        showMessage(
            context,
            action == 'confirm'
                ? 'Goods receipt confirmed; stock updated.'
                : 'Goods receipt cancelled.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Goods Receipts (GRN)',
        subtitle:
            'Receive items against purchase orders and update warehouse stock only after confirmation.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New GRN')),
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.move_to_inbox_outlined,
                        title: 'No goods receipts',
                        message: 'Receive a purchase order when stock arrives.',
                        action: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New GRN')),
                      )
                    : Column(
                        children: _items.map((r) {
                          final status = '${r['status'] ?? ''}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.move_to_inbox_outlined)),
                                title: Row(children: [
                                  Expanded(
                                      child: Text(
                                          '${r['receipt_number'] ?? ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800))),
                                  Chip(label: Text(status)),
                                ]),
                                subtitle: Text(
                                    '${r['contact_name'] ?? 'Vendor'} • PO ${r['po_number'] ?? '—'} • ${displayDate(r['receipt_date'])}'),
                                trailing: status == 'DRAFT'
                                    ? PopupMenuButton<String>(
                                        onSelected: (v) => _action(r, v),
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                              value: 'confirm',
                                              child: Text(
                                                  'Confirm & receive stock')),
                                          PopupMenuItem(
                                              value: 'cancel',
                                              child: Text('Cancel')),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
      );
}

class _GoodsReceiptEditor extends StatefulWidget {
  const _GoodsReceiptEditor(
      {required this.api,
      required this.purchaseOrders,
      required this.warehouses});
  final ApiClient api;
  final List<Map<String, dynamic>> purchaseOrders, warehouses;
  @override
  State<_GoodsReceiptEditor> createState() => _GoodsReceiptEditorState();
}

class _GoodsReceiptEditorState extends State<_GoodsReceiptEditor> {
  String? _poId;
  Map<String, dynamic>? _po;
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  List<_ReceiveLine> _lines = [];
  bool _loading = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _poId = '${widget.purchaseOrders.first['id']}';
    _loadPo();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = Map<String, dynamic>.from(
          await widget.api.get('/purchase-orders/$_poId') as Map);
      for (final l in _lines) {
        l.dispose();
      }
      final raw = d['lines'] is List ? d['lines'] as List : const [];
      _lines = raw.map((e) {
        final x = Map<String, dynamic>.from(e as Map);
        return _ReceiveLine(
            data: x,
            warehouseId: widget.warehouses.isEmpty
                ? null
                : '${widget.warehouses.first['id']}');
      }).toList();
      _po = d;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final active = _lines
        .where((l) => (double.tryParse(l.received.text) ?? 0) > 0)
        .toList();
    if (active.isEmpty) {
      showMessage(context, 'Enter a received quantity for at least one item.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.post('/goods-receipts', body: {
        'purchase_order_id': _poId,
        'receipt_date': apiDate(_date),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'lines': active
            .map((l) => {
                  'purchase_order_line_id': l.data['id'],
                  'product_id': l.data['product_id'],
                  'quantity_ordered':
                      double.tryParse('${l.data['quantity']}') ?? 0,
                  'quantity_received': double.tryParse(l.received.text) ?? 0,
                  'warehouse_id': l.warehouseId,
                  'lot_number':
                      l.lot.text.trim().isEmpty ? null : l.lot.text.trim(),
                  'batch_number':
                      l.batch.text.trim().isEmpty ? null : l.batch.text.trim()
                })
            .toList()
      });
      if (mounted) {
        showMessage(context, 'GRN draft created. Confirm it to update stock.');
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
      appBar: AppBar(title: const Text('New goods receipt'), actions: [
        Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save draft')))
      ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1150),
                  child: Column(children: [
                    SectionCard(
                        title: 'Purchase order',
                        child: Wrap(spacing: 12, runSpacing: 12, children: [
                          SizedBox(
                              width: 460,
                              child: DropdownButtonFormField<String>(
                                  initialValue: _poId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Purchase order'),
                                  items: widget.purchaseOrders
                                      .map((p) => DropdownMenuItem(
                                          value: '${p['id']}',
                                          child: Text(
                                              '${p['po_number'] ?? ''} • ${p['contact_name'] ?? ''}')))
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() => _poId = v);
                                    _loadPo();
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
                                          labelText: 'Receipt date'),
                                      child: Text(displayDate(
                                          _date.toIso8601String()))))),
                          SizedBox(
                              width: 420,
                              child: TextField(
                                  controller: _notes,
                                  decoration: const InputDecoration(
                                      labelText: 'Notes')))
                        ])),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                          padding: EdgeInsets.all(50),
                          child: CircularProgressIndicator())
                    else if (_error != null)
                      ErrorPanel(message: _error!, onRetry: _loadPo)
                    else
                      SectionCard(
                          title: 'Items to receive',
                          child: Column(children: [
                            if (_po != null)
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      '${_po!['contact']?['name'] ?? ''}',
                                      style: const TextStyle(
                                          color: AppColors.muted))),
                            const SizedBox(height: 8),
                            ..._lines.map((l) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 7),
                                child: Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SizedBox(
                                          width: 290,
                                          child: Text(
                                              '${l.data['product_name'] ?? l.data['description'] ?? 'Item'}',
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w700))),
                                      SizedBox(
                                          width: 110,
                                          child: Text(
                                              'Ordered\n${formatNumber(l.data['quantity'])}')),
                                      SizedBox(
                                          width: 110,
                                          child: Text(
                                              'Remaining\n${formatNumber(l.data['quantity_remaining'] ?? l.data['quantity'])}')),
                                      SizedBox(
                                          width: 140,
                                          child: TextField(
                                              controller: l.received,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                  decimal: true),
                                              decoration: const InputDecoration(
                                                  labelText: 'Receive qty'))),
                                      SizedBox(
                                          width: 220,
                                          child: DropdownButtonFormField<
                                                  String>(
                                              initialValue: l.warehouseId,
                                              isExpanded: true,
                                              decoration: const InputDecoration(
                                                  labelText: 'Warehouse'),
                                              items: widget.warehouses
                                                  .map((w) => DropdownMenuItem(
                                                      value: '${w['id']}',
                                                      child:
                                                          Text('${w['name']}')))
                                                  .toList(),
                                              onChanged: (v) => setState(
                                                  () => l.warehouseId = v))),
                                      SizedBox(
                                          width: 140,
                                          child: TextField(
                                              controller: l.batch,
                                              decoration: const InputDecoration(
                                                  labelText: 'Batch'))),
                                      SizedBox(
                                          width: 140,
                                          child: TextField(
                                              controller: l.lot,
                                              decoration: const InputDecoration(
                                                  labelText: 'Lot')))
                                    ])))
                          ]))
                  ])))));
}

class _ReceiveLine {
  _ReceiveLine({required this.data, required this.warehouseId}) {
    final remaining = double.tryParse(
            '${data['quantity_remaining'] ?? data['quantity'] ?? 0}') ??
        0;
    received.text = remaining > 0
        ? remaining.toStringAsFixed(remaining % 1 == 0 ? 0 : 2)
        : '';
  }
  final Map<String, dynamic> data;
  String? warehouseId;
  final received = TextEditingController(),
      batch = TextEditingController(),
      lot = TextEditingController();
  void dispose() {
    received.dispose();
    batch.dispose();
    lot.dispose();
  }
}
