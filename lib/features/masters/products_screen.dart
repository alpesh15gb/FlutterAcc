import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
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
      final q = <String, dynamic>{'limit': 100};
      if (_type != 'ALL') q['product_type'] = _type;
      if (_search.text.trim().isNotEmpty) q['search'] = _search.text.trim();
      final d = await widget.api.get('/masters/products', query: q);
      if (mounted)
        setState(() => _items = (d as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _form([Map<String, dynamic>? p]) async {
    final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _ProductDialog(api: widget.api, item: p));
    if (saved == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> p) async {
    final active = p['is_active'] != false;
    try {
      await widget.api
          .put('/masters/products/${p['id']}', body: {'is_active': !active});
      if (mounted) {
        showMessage(context, active ? 'Item deactivated.' : 'Item activated.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('Delete item?'),
                    content: Text(
                        'Delete ${p['name'] ?? 'this item'}? Items used by active invoices, bills, sales orders or challans cannot be deleted.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'))
                    ])) ??
        false;
    if (!ok) return;
    try {
      await widget.api.delete('/masters/products/${p['id']}');
      if (mounted) {
        showMessage(context, 'Item deleted.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _actions(Map<String, dynamic> p) => PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'edit') _form(p);
        if (v == 'toggle') _toggle(p);
        if (v == 'delete') _delete(p);
      },
      itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
                value: 'toggle',
                child:
                    Text(p['is_active'] == false ? 'Activate' : 'Deactivate')),
            const PopupMenuItem(value: 'delete', child: Text('Delete'))
          ]);
  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Items',
      subtitle:
          'Goods and services with HSN/SAC, GST, prices and stock controls.',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        FilledButton.icon(
            onPressed: () => _form(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'))
      ],
      child: Column(children: [
        SectionCard(
            child: Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
              width: 340,
              child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search name, SKU, barcode or HSN'),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _load);
                  })),
          SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ALL', label: Text('All')),
                ButtonSegment(value: 'GOODS', label: Text('Goods')),
                ButtonSegment(value: 'SERVICE', label: Text('Services'))
              ],
              selected: {
                _type
              },
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
                _load();
              })
        ])),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(50), child: CircularProgressIndicator())
        else if (_error != null)
          ErrorPanel(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No items found',
              message:
                  'Add goods or services to use them in sales and purchases.',
              action: FilledButton.icon(
                  onPressed: () => _form(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add item')))
        else
          LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 900
                  ? _table()
                  : Column(children: _items.map(_card).toList()))
      ]));
  Widget _table() => SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('HSN/SAC')),
                DataColumn(label: Text('GST')),
                DataColumn(label: Text('Default sale rate')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Reorder')),
                DataColumn(label: Text(''))
              ],
              rows: _items
                  .map((p) => DataRow(cells: [
                        DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${p['sku'] ?? '—'} • ${p['product_type'] ?? ''}${p['is_active'] == false ? ' • INACTIVE' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.muted))
                            ])),
                        DataCell(Text(p['hsn_sac']?.toString() ?? '')),
                        DataCell(Text('${p['gst_rate'] ?? 0}%')),
                        DataCell(Text(money(p['sales_price']))),
                        DataCell(Text(
                            '${p['current_stock'] ?? 0} ${p['uom'] ?? ''}')),
                        DataCell(Text('${p['reorder_level'] ?? 0}')),
                        DataCell(_actions(p))
                      ]))
                  .toList())));
  Widget _card(Map<String, dynamic> p) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                  child: Icon(p['product_type'] == 'SERVICE'
                      ? Icons.design_services_outlined
                      : Icons.inventory_2_outlined)),
              title: Text(p['name']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                  'HSN/SAC ${p['hsn_sac'] ?? ''} • GST ${p['gst_rate'] ?? 0}%${p['is_active'] == false ? ' • INACTIVE' : ''}\nStock ${p['current_stock'] ?? 0} ${p['uom'] ?? ''}'),
              isThreeLine: true,
              trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(money(p['sales_price']),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    _actions(p)
                  ]))));
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog({required this.api, this.item});
  final ApiClient api;
  final Map<String, dynamic>? item;
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  late final TextEditingController _name,
      _sku,
      _barcode,
      _hsn,
      _uom,
      _sale,
      _purchase,
      _gst,
      _opening,
      _reorder;
  String _type = 'GOODS';
  bool _saving = false;
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    final p = widget.item ?? {};
    _name = TextEditingController(text: p['name']?.toString() ?? '');
    _sku = TextEditingController(text: p['sku']?.toString() ?? '');
    _barcode = TextEditingController(text: p['barcode']?.toString() ?? '');
    _hsn = TextEditingController(text: p['hsn_sac']?.toString() ?? '');
    _uom = TextEditingController(text: p['uom']?.toString() ?? 'PCS');
    _sale = TextEditingController(text: p['sales_price']?.toString() ?? '0');
    _purchase =
        TextEditingController(text: p['purchase_price']?.toString() ?? '0');
    _gst = TextEditingController(text: p['gst_rate']?.toString() ?? '18');
    _opening =
        TextEditingController(text: p['opening_stock']?.toString() ?? '0');
    _reorder =
        TextEditingController(text: p['reorder_level']?.toString() ?? '0');
    _type = p['product_type']?.toString() ?? 'GOODS';
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _barcode,
      _hsn,
      _uom,
      _sale,
      _purchase,
      _gst,
      _opening,
      _reorder
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'sku': _sku.text.trim().isEmpty ? null : _sku.text.trim(),
        'barcode': _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        'hsn_sac': _hsn.text.trim(),
        'product_type': _type,
        'uom': _uom.text.trim().toUpperCase(),
        'sales_price': double.tryParse(_sale.text) ?? 0,
        'purchase_price': double.tryParse(_purchase.text) ?? 0,
        'gst_rate': double.tryParse(_gst.text) ?? 0,
        'opening_stock':
            _type == 'SERVICE' ? 0 : double.tryParse(_opening.text) ?? 0,
        'reorder_level':
            _type == 'SERVICE' ? 0 : double.tryParse(_reorder.text) ?? 0
      };
      if (widget.item == null) {
        await widget.api.post('/masters/products', body: body);
      } else {
        await widget.api
            .put('/masters/products/${widget.item!['id']}', body: body);
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
          title:
              Text(widget.item == null ? 'Add item or service' : 'Edit item'),
          content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                  child: Form(
                      key: _form,
                      child: Wrap(spacing: 12, runSpacing: 12, children: [
                        SizedBox(
                            width: 350,
                            child: TextFormField(
                                controller: _name,
                                decoration:
                                    const InputDecoration(labelText: 'Name'),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null)),
                        SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                                value: _type,
                                decoration:
                                    const InputDecoration(labelText: 'Type'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'GOODS', child: Text('Goods')),
                                  DropdownMenuItem(
                                      value: 'SERVICE', child: Text('Service'))
                                ],
                                onChanged: (v) => setState(() => _type = v!))),
                        SizedBox(
                            width: 180,
                            child: TextFormField(
                                controller: _hsn,
                                keyboardType: TextInputType.number,
                                maxLength: 8,
                                decoration: const InputDecoration(
                                    labelText: 'HSN / SAC', counterText: ''),
                                validator: (v) => (v?.length ?? 0) >= 6
                                    ? null
                                    : 'Use 6–8 digits')),
                        SizedBox(
                            width: 130,
                            child: TextFormField(
                                controller: _uom,
                                decoration:
                                    const InputDecoration(labelText: 'UOM'))),
                        SizedBox(
                            width: 220,
                            child: TextFormField(
                                controller: _sku,
                                decoration:
                                    const InputDecoration(labelText: 'SKU'))),
                        SizedBox(
                            width: 220,
                            child: TextFormField(
                                controller: _barcode,
                                decoration: const InputDecoration(
                                    labelText: 'Barcode'))),
                        SizedBox(
                            width: 160,
                            child: TextFormField(
                                controller: _sale,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Default sale rate'))),
                        SizedBox(
                            width: 160,
                            child: TextFormField(
                                controller: _purchase,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Default purchase rate'))),
                        SizedBox(
                            width: 130,
                            child: TextFormField(
                                controller: _gst,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    const InputDecoration(labelText: 'GST %'))),
                        if (_type == 'GOODS')
                          SizedBox(
                              width: 160,
                              child: TextFormField(
                                  controller: _opening,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Opening stock'))),
                        if (_type == 'GOODS')
                          SizedBox(
                              width: 160,
                              child: TextFormField(
                                  controller: _reorder,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Reorder level')))
                      ])))),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'))
          ]);
}
