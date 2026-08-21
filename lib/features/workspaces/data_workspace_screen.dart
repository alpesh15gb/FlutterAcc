import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/workspace_catalog.dart';
import '../purchases/bill_scan_screen.dart';
import '../sales/tax_document_editor_screen.dart';

class DataWorkspaceScreen extends StatefulWidget {
  const DataWorkspaceScreen(
      {super.key, required this.api, required this.config});

  final ApiClient api;
  final WorkspaceConfig config;

  @override
  State<DataWorkspaceScreen> createState() => _DataWorkspaceScreenState();
}

class _DataWorkspaceScreenState extends State<DataWorkspaceScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
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

  List<Map<String, dynamic>> _normalize(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data is Map) {
      for (final key in ['items', 'results', 'data', 'entries', 'records']) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return [];
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final query = <String, dynamic>{};
      final text = _search.text.trim();
      if (text.isNotEmpty) query['search'] = text;
      final data = await widget.api.get(widget.config.endpoint, query: query);
      if (mounted) setState(() => _items = _normalize(data));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scanBill() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => BillScanScreen(api: widget.api),
    ));
    if (saved == true) _load();
  }

  Future<void> _create() async {
    if (widget.config.editor == WorkspaceEditor.taxDocument &&
        widget.config.documentKind != null) {
      final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => TaxDocumentEditorScreen(
          api: widget.api,
          kindName: widget.config.documentKind!,
        ),
      ));
      if (saved == true) _load();
      return;
    }
    showMessage(context,
        'Creation for this workflow is handled by its dedicated accounting flow.');
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    final kind = widget.config.documentKind;
    if (id == null || kind == null) return;
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => TaxDocumentEditorScreen(
          api: widget.api, kindName: kind, initialId: id),
    ));
    if (changed == true) _load();
  }

  Future<Map<String, dynamic>> _detail(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null) return item;
    try {
      final data = await widget.api.get('${widget.config.endpoint}/$id');
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      // Some list-only endpoints intentionally do not expose a detail route.
    }
    return item;
  }

  Future<void> _open(Map<String, dynamic> item) async {
    var detail = item;
    try {
      detail = await _detail(item);
    } catch (_) {}
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(children: [
          Icon(widget.config.icon),
          const SizedBox(width: 10),
          Expanded(child: Text(_recordTitle(detail))),
        ]),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(child: _detailBody(detail)),
        ),
        actions: [
          ..._actions(detail).map((action) => TextButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _runAction(action, detail);
                },
                icon: Icon(action.icon),
                label: Text(action.label),
              )),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close')),
        ],
      ),
    );
  }

  String _recordTitle(Map<String, dynamic> item) {
    for (final key in [
      'invoice_number',
      'bill_number',
      'proforma_number',
      'so_number',
      'po_number',
      'challan_number',
      'return_number',
      'payment_number',
      'name',
    ]) {
      final value = item[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return widget.config.title;
  }

  Widget _detailBody(Map<String, dynamic> item) {
    final preferred = <String>[
      'status',
      'contact_name',
      'issue_date',
      'order_date',
      'challan_date',
      'due_date',
      'total',
      'amount_paid',
      'amount_received',
      'reference_number',
      'notes',
    ];
    final keys = <String>[
      ...preferred.where(item.containsKey),
      ...item.keys.where((key) =>
          !preferred.contains(key) && key != 'lines' && key != 'contact'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final key in keys)
        if (item[key] != null && item[key] is! Map && item[key] is! List)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 165,
                  child: Text(titleCase(key),
                      style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600))),
              Expanded(child: SelectableText(_formattedDetail(key, item[key]))),
            ]),
          ),
      if (item['lines'] is List) ...[
        const Divider(height: 28),
        Text('Line items (${(item['lines'] as List).length})',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final raw in (item['lines'] as List).whereType<Map>())
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${raw['product_name'] ?? raw['description'] ?? 'Item'}  •  '
              'Qty ${displayValue(raw['quantity'])}  •  '
              'Rate ${money(raw['rate'])} ${item['is_gst_inclusive'] == true ? '(incl. GST)' : '(excl. GST)'}  •  '
              '${money(raw['total'] ?? ((num.tryParse('${raw['quantity']}') ?? 0) * (num.tryParse('${raw['rate']}') ?? 0)))}',
            ),
          ),
      ],
    ]);
  }

  String _formattedDetail(String key, Object? value) {
    if (key == 'is_gst_inclusive') {
      return value == true
          ? 'GST INCLUDED in rate'
          : 'GST EXCLUDED; added on top';
    }
    if (key.contains('date') || key.endsWith('_at')) return displayDate(value);
    if (['total', 'amount_paid', 'amount_received', 'subtotal'].contains(key))
      return money(value);
    return displayValue(value);
  }

  List<_WorkspaceAction> _actions(Map<String, dynamic> item) {
    final status = item['status']?.toString().toUpperCase() ?? '';
    final actions = <_WorkspaceAction>[];
    final id = widget.config.id;

    void add(String label, IconData icon, String kind,
        {String? suffix, bool destructive = false}) {
      actions.add(_WorkspaceAction(label, icon, kind,
          suffix: suffix, destructive: destructive));
    }

    if (widget.config.documentKind != null && status == 'DRAFT') {
      add('Edit', Icons.edit_outlined, 'edit');
    }

    switch (id) {
      case 'proforma':
        if (status == 'DRAFT')
          add('Issue', Icons.send_outlined, 'post', suffix: 'issue');
        if (status == 'ISSUED') {
          add('Convert to invoice', Icons.receipt_long_outlined, 'post',
              suffix: 'convert');
          add('Convert to sales order', Icons.shopping_bag_outlined, 'post',
              suffix: 'convert-to-sales-order');
        }
        if (status != 'CONVERTED' && status != 'CANCELLED')
          add('Cancel', Icons.cancel_outlined, 'post',
              suffix: 'cancel', destructive: true);
        if (status == 'DRAFT')
          add('Delete draft', Icons.delete_outline, 'delete',
              destructive: true);
        add('PDF', Icons.picture_as_pdf_outlined, 'print');
        break;
      case 'sales-orders':
        if (status == 'DRAFT')
          add('Confirm', Icons.check_circle_outline, 'post', suffix: 'confirm');
        if (status == 'DRAFT' || status == 'CONFIRMED')
          add('Mark delivered', Icons.local_shipping_outlined, 'post',
              suffix: 'deliver');
        if (status == 'CONFIRMED')
          add('Create challan', Icons.move_to_inbox_outlined, 'post',
              suffix: 'create-delivery-challan');
        if (status != 'DELIVERED' && status != 'CANCELLED')
          add('Cancel', Icons.cancel_outlined, 'post',
              suffix: 'cancel', destructive: true);
        add('PDF', Icons.picture_as_pdf_outlined, 'print');
        break;
      case 'purchase-orders':
        if (status == 'DRAFT')
          add('Confirm', Icons.check_circle_outline, 'post', suffix: 'confirm');
        if (status == 'DRAFT' || status == 'CONFIRMED')
          add('Mark received', Icons.inventory_2_outlined, 'post',
              suffix: 'receive');
        if (status != 'RECEIVED' && status != 'CANCELLED')
          add('Cancel', Icons.cancel_outlined, 'post',
              suffix: 'cancel', destructive: true);
        add('PDF', Icons.picture_as_pdf_outlined, 'print');
        break;
      case 'challans':
        if (status == 'DRAFT')
          add('Issue / dispatch', Icons.local_shipping_outlined, 'post',
              suffix: 'issue');
        if (status == 'ISSUED')
          add('Convert to invoice', Icons.receipt_long_outlined, 'post',
              suffix: 'convert-to-invoice');
        if (status != 'CANCELLED' && item['converted_to_invoice_id'] == null)
          add('Cancel', Icons.cancel_outlined, 'post',
              suffix: 'cancel', destructive: true);
        add('PDF', Icons.picture_as_pdf_outlined, 'print');
        break;
      case 'bills':
        if (status == 'DRAFT') {
          add('Finalize', Icons.task_alt_outlined, 'post', suffix: 'finalize');
          add('Delete draft', Icons.delete_outline, 'delete',
              destructive: true);
        }
        if (status == 'POSTED' || status == 'PARTIALLY_PAID')
          add('Cancel', Icons.cancel_outlined, 'post',
              suffix: 'cancel', destructive: true);
        add('Clone', Icons.copy_outlined, 'post', suffix: 'clone');
        add('PDF', Icons.picture_as_pdf_outlined, 'print');
        break;
    }
    return actions;
  }

  Future<bool> _confirmLifecycle(String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: const Text(
            'This changes the document/accounting lifecycle on the server. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(label)),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runAction(
      _WorkspaceAction action, Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null) return;
    if (action.kind == 'edit') {
      await _edit(item);
      return;
    }
    if (action.destructive) {
      final ok = await _confirmLifecycle(action.label);
      if (!ok) return;
    }
    try {
      if (action.kind == 'print') {
        final bytes =
            await widget.api.download('${widget.config.endpoint}/$id/print');
        final fileName =
            '${widget.config.id}_${_recordTitle(item).replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.pdf';
        final saved = await saveDownloadedFile(bytes, fileName);
        if (mounted)
          showMessage(context, saved ? 'PDF saved.' : 'Save cancelled.');
        return;
      }
      if (action.kind == 'delete') {
        await widget.api.delete('${widget.config.endpoint}/$id');
      } else {
        final suffix = action.suffix == null ? '' : '/${action.suffix}';
        await widget.api.post('${widget.config.endpoint}/$id$suffix');
      }
      if (mounted) showMessage(context, '${action.label} completed.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.config.editor != WorkspaceEditor.none;
    return PageFrame(
      title: widget.config.title,
      subtitle: widget.config.subtitle,
      actions: [
        IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded)),
        if (widget.config.id == 'bills')
          OutlinedButton.icon(
              onPressed: _scanBill,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Scan bill')),
        if (canCreate)
          FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New')),
      ],
      child: Column(children: [
        SectionCard(
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: widget.config.searchHint),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 450), _load);
                },
              ),
            ),
            const SizedBox(width: 10),
            Text('${_items.length} records',
                style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(50), child: CircularProgressIndicator())
        else if (_error != null)
          ErrorPanel(message: _error!, onRetry: _load)
        else if (_items.isEmpty)
          EmptyState(
            icon: widget.config.icon,
            title: 'No ${widget.config.title.toLowerCase()} yet',
            message: canCreate
                ? 'Create the first record to start this workflow.'
                : 'Records from the backend will appear here.',
            action: canCreate
                ? FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create record'))
                : null,
          )
        else
          _ResponsiveWorkspace(
              items: _items, config: widget.config, onOpen: _open),
      ]),
    );
  }
}

class _WorkspaceAction {
  const _WorkspaceAction(this.label, this.icon, this.kind,
      {this.suffix, this.destructive = false});
  final String label;
  final IconData icon;
  final String kind;
  final String? suffix;
  final bool destructive;
}

class _ResponsiveWorkspace extends StatelessWidget {
  const _ResponsiveWorkspace(
      {required this.items, required this.config, required this.onOpen});

  final List<Map<String, dynamic>> items;
  final WorkspaceConfig config;
  final ValueChanged<Map<String, dynamic>> onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 850) return _table(context);
        return Column(
            children: items
                .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _card(context, item)))
                .toList());
      });

  Widget _table(BuildContext context) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            ...config.columns.map((c) => DataColumn(
                label: Text(c.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)))),
            const DataColumn(label: Text('')),
          ],
          rows: items
              .map((item) => DataRow(
                    onSelectChanged: (_) => onOpen(item),
                    cells: [
                      ...config.columns
                          .map((column) => DataCell(_value(column, item))),
                      DataCell(IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          tooltip: 'Open',
                          onPressed: () => onOpen(item))),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> item) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpen(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            for (var i = 0; i < config.columns.length; i++) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 105,
                    child: Text(config.columns[i].label,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12))),
                Expanded(
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: _value(config.columns[i], item))),
              ]),
              if (i != config.columns.length - 1) const SizedBox(height: 7),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _value(WorkspaceColumn column, Map<String, dynamic> item) {
    final raw = _path(item, column.key);
    final text = column.taxMode
        ? (raw == true ? 'GST INCLUDED' : 'GST EXCLUDED')
        : column.money
            ? money(raw)
            : column.date
                ? displayDate(raw)
                : displayValue(raw);
    if (column.status) {
      final normalized = text.toUpperCase();
      final color = normalized.contains('PAID') ||
              normalized.contains('POSTED') ||
              normalized.contains('ACTIVE') ||
              normalized.contains('COMPLETE') ||
              normalized.contains('CONFIRMED') ||
              normalized.contains('ISSUED')
          ? AppColors.success
          : normalized.contains('CANCEL') || normalized.contains('FAILED')
              ? AppColors.danger
              : normalized.contains('DRAFT') || normalized.contains('PENDING')
                  ? AppColors.warning
                  : AppColors.primary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: color.withOpacity(.08),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      );
    }
    return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  Object? _path(Map<String, dynamic> item, String key) {
    Object? value = item;
    for (final part in key.split('.')) {
      if (value is Map) {
        value = value[part];
      } else {
        return null;
      }
    }
    return value;
  }
}
