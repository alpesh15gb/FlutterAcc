import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import 'tax_document_editor_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _error;
  String _status = 'ALL';
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
    if (context.mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final q = <String, dynamic>{'page': 1, 'limit': 100};
      if (_status != 'ALL') q['status'] = _status;
      if (_search.text.trim().isNotEmpty) q['search'] = _search.text.trim();
      final r = await Future.wait([
        widget.api.get('/invoices', query: q),
        widget.api.get('/invoices/stats'),
      ]);
      final data = Map<String, dynamic>.from(r[0] as Map);
      if (context.mounted) {
        setState(() {
          _items = ((data['items'] as List?) ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _stats = Map<String, dynamic>.from(r[1] as Map);
        });
      }
    } catch (e) {
      if (context.mounted) setState(() => _error = e.toString());
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newInvoice() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaxDocumentEditorScreen(api: widget.api, kindName: 'invoice'),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _editInvoice(String id) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaxDocumentEditorScreen(
          api: widget.api,
          kindName: 'invoice',
          initialId: id,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    Map<String, dynamic> detail = row;
    try {
      detail = Map<String, dynamic>.from(
        await widget.api.get('/invoices/$id') as Map,
      );
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
      return;
    }
    if (!context.mounted) return;
    final status = detail['status']?.toString().toUpperCase() ?? '';
    final eInvoiceStatus =
        detail['e_invoice_status']?.toString().toUpperCase() ?? 'PENDING';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Invoice ${detail['invoice_number'] ?? ''}'),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(child: _invoiceDetail(detail)),
        ),
        actions: [
          if (status == 'DRAFT')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _editInvoice(id);
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          if (status == 'DRAFT')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _mutate(id, 'finalize', 'Finalize invoice');
              },
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Finalize'),
            ),
          if (status == 'DRAFT')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _delete(id);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          if ((status == 'POSTED' ||
                  status == 'PARTIALLY_PAID' ||
                  status == 'SENT') &&
              eInvoiceStatus != 'GENERATED')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _generateEInvoice(id);
              },
              icon: const Icon(Icons.qr_code_2_rounded),
              label: Text(
                eInvoiceStatus == 'FAILED' ? 'Retry e-invoice' : 'Generate IRN',
              ),
            ),
          if (eInvoiceStatus == 'GENERATED')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _cancelEInvoice(id);
              },
              icon: const Icon(Icons.qr_code_2_outlined),
              label: const Text('Cancel IRN'),
            ),
          if (status == 'POSTED' || status == 'PARTIALLY_PAID')
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _mutate(id, 'cancel', 'Cancel invoice', destructive: true);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel'),
            ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _mutate(id, 'clone', 'Clone invoice');
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Clone'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _downloadPdf(detail);
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _invoiceDetail(Map<String, dynamic> data) {
    final lines =
        (data['lines'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _detailRow(
          'Customer',
          data['contact'] is Map
              ? (data['contact'] as Map)['name']
              : data['contact_name'],
        ),
        _detailRow('Status', data['status']),
        _detailRow('Invoice date', displayDate(data['issue_date'])),
        _detailRow('Due date', displayDate(data['due_date'])),
        _detailRow('Place of supply', data['pos_state_code']),
        _detailRow('Supply type', data['supply_type']),
        _detailRow(
          'Rate entry mode',
          data['is_gst_inclusive'] == true
              ? 'GST INCLUDED in entered rate'
              : 'GST EXCLUDED; GST added on top',
        ),
        _detailRow('Reverse charge', data['is_rcm'] == true ? 'Yes' : 'No'),
        _detailRow('Subtotal', money(data['subtotal'])),
        _detailRow(
          'GST',
          money(
            (num.tryParse('${data['cgst_amount'] ?? 0}') ?? 0) +
                (num.tryParse('${data['sgst_amount'] ?? 0}') ?? 0) +
                (num.tryParse('${data['igst_amount'] ?? 0}') ?? 0) +
                (num.tryParse('${data['utgst_amount'] ?? 0}') ?? 0) +
                (num.tryParse('${data['cess_amount'] ?? 0}') ?? 0),
          ),
        ),
        _detailRow('TDS', money(data['tds_amount'])),
        _detailRow('TCS', money(data['tcs_amount'])),
        _detailRow('Total', money(data['total'])),
        _detailRow('Paid', money(data['amount_paid'])),
        if (data['irn'] != null) _detailRow('IRN', data['irn']),
        if (data['e_invoice_status'] != null)
          _detailRow('E-invoice', data['e_invoice_status']),
        if (lines.isNotEmpty) ...[
          const Divider(height: 28),
          Text(
            'Items (${lines.length})',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${line['product_name'] ?? line['description'] ?? 'Item'} • '
                'Qty ${displayValue(line['quantity'])} • '
                'Rate ${money(line['rate'])} ${data['is_gst_inclusive'] == true ? '(incl. GST)' : '(excl. GST)'} • '
                'GST ${displayValue(line['gst_rate'])}% • ${money(line['total'])}',
              ),
            ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, Object? value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 145,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: SelectableText(displayValue(value))),
          ],
        ),
      );

  Future<bool> _confirm(String title) async =>
      (await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: const Text(
            'This changes posted accounting history or document status. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(title),
            ),
          ],
        ),
      )) ==
      true;

  Future<void> _mutate(
    String id,
    String suffix,
    String label, {
    bool destructive = false,
  }) async {
    if (destructive && !await _confirm(label)) return;
    try {
      await widget.api.post('/invoices/$id/$suffix');
      if (context.mounted) showMessage(context, '$label completed.');
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _generateEInvoice(String id) async {
    try {
      final data = await widget.api.post('/invoices/$id/e-invoice');
      final irn = data is Map ? data['irn']?.toString() : null;
      if (context.mounted) {
        showMessage(
          context,
          irn == null ? 'E-invoice generated.' : 'IRN generated: $irn',
        );
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _cancelEInvoice(String id) async {
    String reason = '2';
    final remarks = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Cancel e-invoice IRN'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(
                    labelText: 'Cancellation reason',
                  ),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Duplicate')),
                    DropdownMenuItem(
                      value: '2',
                      child: Text('Data entry mistake / order cancelled'),
                    ),
                    DropdownMenuItem(value: '3', child: Text('Other')),
                    DropdownMenuItem(value: '4', child: Text('Other reason')),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => reason = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remarks,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The backend enforces the statutory cancellation window and IRP rules.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel IRN'),
            ),
          ],
        ),
      ),
    );
    final note = remarks.text.trim();
    remarks.dispose();
    if (confirmed != true) return;
    try {
      await widget.api.post(
        '/invoices/$id/e-invoice/cancel',
        body: {
          'cancel_reason': reason,
          'cancel_remarks': note.isEmpty ? null : note,
        },
      );
      if (context.mounted) showMessage(context, 'E-invoice IRN cancelled.');
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(String id) async {
    if (!await _confirm('Delete draft')) return;
    try {
      await widget.api.delete('/invoices/$id');
      if (context.mounted) showMessage(context, 'Draft invoice deleted.');
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _downloadPdf(Map<String, dynamic> invoice) async {
    final id = invoice['id']?.toString();
    if (id == null) return;
    try {
      final bytes = await widget.api.download('/invoices/$id/print');
      final number = invoice['invoice_number']?.toString().replaceAll(
                RegExp(r'[^A-Za-z0-9._-]'),
                '_',
              ) ??
          id;
      final saved = await saveDownloadedFile(bytes, 'Invoice_$number.pdf');
      if (context.mounted) {
        showMessage(context, saved ? 'Invoice PDF saved.' : 'Save cancelled.');
      }
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Sales Invoices',
        subtitle: 'GST invoices, collections status and customer receivables.',
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          FilledButton.icon(
            onPressed: _newInvoice,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New invoice'),
          ),
        ],
        child: Column(
          children: [
            _statsBar(),
            const SizedBox(height: 14),
            SectionCard(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 330,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search invoice or customer',
                      ),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 400), _load);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'ALL', child: Text('All statuses')),
                        DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                        DropdownMenuItem(
                            value: 'POSTED', child: Text('Posted')),
                        DropdownMenuItem(
                          value: 'PARTIALLY_PAID',
                          child: Text('Partially paid'),
                        ),
                        DropdownMenuItem(value: 'PAID', child: Text('Paid')),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('Cancelled'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _status = v);
                          _load();
                        }
                      },
                    ),
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
                icon: Icons.receipt_long_outlined,
                title: 'No invoices found',
                message: 'Create a GST invoice to start sales tracking.',
                action: FilledButton.icon(
                  onPressed: _newInvoice,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create invoice'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) => c.maxWidth >= 950
                    ? _table()
                    : Column(children: _items.map(_card).toList()),
              ),
          ],
        ),
      );

  Widget _statsBar() => LayoutBuilder(
        builder: (context, c) {
          final cards = [
            (
              'Total',
              _stats['total_amount'],
              Icons.receipt_long_outlined,
              AppColors.primary,
            ),
            (
              'Collected',
              _stats['collected'],
              Icons.check_circle_outline_rounded,
              AppColors.success,
            ),
            (
              'Outstanding',
              _stats['outstanding'],
              Icons.schedule_rounded,
              AppColors.warning,
            ),
            (
              'Overdue',
              _stats['overdue'],
              Icons.error_outline_rounded,
              AppColors.danger,
            ),
          ];
          final cols = c.maxWidth >= 900
              ? 4
              : c.maxWidth >= 520
                  ? 2
                  : 1;
          const gap = 10.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: cards
                .map(
                  (e) => SizedBox(
                    width: w,
                    child: MetricCard(
                      label: e.$1,
                      value: shortMoney(e.$2),
                      icon: e.$3,
                      tone: e.$4,
                    ),
                  ),
                )
                .toList(),
          );
        },
      );

  Widget _table() => SectionCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Invoice')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Due')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: Text('')),
            ],
            rows: _items
                .map(
                  (i) => DataRow(
                    onSelectChanged: (_) => _open(i),
                    cells: [
                      DataCell(
                        Text(
                          i['invoice_number']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(Text(i['contact_name']?.toString() ?? '')),
                      DataCell(Text(displayDate(i['issue_date']))),
                      DataCell(Text(displayDate(i['due_date']))),
                      DataCell(_statusChip(i['status']?.toString() ?? '')),
                      DataCell(Text(money(i['total']))),
                      DataCell(
                        Text(
                          money(
                            (num.tryParse('${i['total']}') ?? 0) -
                                (num.tryParse('${i['amount_paid']}') ?? 0),
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          onPressed: () => _open(i),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      );

  Widget _card(Map<String, dynamic> i) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Card(
          child: InkWell(
            onTap: () => _open(i),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i['invoice_number']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _statusChip(i['status']?.toString() ?? ''),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i['contact_name']?.toString() ?? '',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                      Text(
                        money(i['total']),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        displayDate(i['issue_date']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Balance ${money((num.tryParse('${i['total']}') ?? 0) - (num.tryParse('${i['amount_paid']}') ?? 0))}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _statusChip(String s) {
    final u = s.toUpperCase();
    final color = u == 'PAID'
        ? AppColors.success
        : u == 'CANCELLED'
            ? AppColors.danger
            : u == 'DRAFT'
                ? AppColors.warning
                : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        u,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
