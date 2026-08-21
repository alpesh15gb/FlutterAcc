import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.api, required this.vendor});
  final ApiClient api;
  final bool vendor;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String get endpoint =>
      widget.vendor ? '/payments/disbursements' : '/payments/receipts';
  String get title => widget.vendor ? 'Vendor Payments' : 'Customer Receipts';

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
      final data = await widget.api.get(endpoint, query: {'limit': 100});
      if (context.mounted) {
        setState(() => _items = (data as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (e) {
      if (context.mounted) setState(() => _error = e.toString());
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              PaymentEditorScreen(api: widget.api, vendor: widget.vendor)),
    );
    if (saved == true) _load();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null) return;
    try {
      final detail = Map<String, dynamic>.from(
          await widget.api.get('$endpoint/$id') as Map);
      if (!context.mounted) return;
      final allocations =
          (detail['allocations'] as List?)?.whereType<Map>().toList() ??
              const <Map>[];
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
              '${widget.vendor ? 'Payment' : 'Receipt'} ${detail['payment_number'] ?? ''}'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detail('Status', detail['status']),
                    _detail('Date', displayDate(detail['payment_date'])),
                    _detail('Mode', detail['payment_mode']),
                    _detail('Amount', money(detail['amount'])),
                    _detail('Reference', detail['reference_number']),
                    _detail('Description', detail['description']),
                    if (!widget.vendor)
                      _detail('Advance supply', detail['advance_supply_type']),
                    if (detail['cancellation_reason'] != null)
                      _detail(
                          'Cancellation reason', detail['cancellation_reason']),
                    if (allocations.isNotEmpty) ...[
                      const Divider(height: 28),
                      Text('Allocations (${allocations.length})',
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final a in allocations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                              '${widget.vendor ? 'Bill' : 'Invoice'} ${a[widget.vendor ? 'bill_id' : 'invoice_id'] ?? ''} • ${money(a['amount'])}'),
                        ),
                    ],
                  ]),
            ),
          ),
          actions: [
            if (detail['status'] != 'CANCELLED')
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _cancel(detail);
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Cancel & reverse'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _detail(String label, Object? value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.muted, fontWeight: FontWeight.w600))),
          Expanded(child: SelectableText(displayValue(value))),
        ]),
      );

  Future<void> _cancel(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
              'Cancel ${widget.vendor ? 'vendor payment' : 'customer receipt'}?'),
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: reason,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Reason *')),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final d = await pickDate(context, date);
                  if (d != null) setLocal(() => date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Cancellation date',
                      suffixIcon: Icon(Icons.calendar_month_outlined)),
                  child: Text(displayDate(date.toIso8601String())),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                  'The backend will reverse allocations, customer/vendor credit and the ledger only when downstream dependencies allow it.',
                  style: TextStyle(color: AppColors.muted)),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Back')),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length < 3) {
                  showMessage(context,
                      'Enter at least 3 characters for the cancellation reason.',
                      error: true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Cancel & reverse'),
            ),
          ],
        ),
      ),
    );
    final note = reason.text.trim();
    reason.dispose();
    if (ok != true) return;
    try {
      await widget.api.post('$endpoint/${row['id']}/cancel', body: {
        'reason': note,
        'cancellation_date': apiDate(date),
      });
      if (context.mounted) {
        showMessage(context,
            '${widget.vendor ? 'Payment' : 'Receipt'} cancelled and reversed.');
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: title,
        subtitle: widget.vendor
            ? 'Pay suppliers, allocate disbursements to bills and reverse them safely when required.'
            : 'Record customer collections, allocate receipts to invoices and manage advance credit.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          FilledButton.icon(
            onPressed: _create,
            icon: Icon(widget.vendor
                ? Icons.north_east_rounded
                : Icons.south_west_rounded),
            label: Text(widget.vendor ? 'Record payment' : 'Record receipt'),
          ),
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(50), child: CircularProgressIndicator())
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No ${title.toLowerCase()}',
                        message: widget.vendor
                            ? 'Record a vendor payment when bills are settled.'
                            : 'Record a receipt when a customer pays an invoice.',
                        action: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(widget.vendor
                                ? 'Record payment'
                                : 'Record receipt')),
                      )
                    : LayoutBuilder(
                        builder: (context, c) => c.maxWidth >= 850
                            ? _table()
                            : Column(children: _items.map(_card).toList())),
      );

  Widget _table() => SectionCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Number')),
              DataColumn(label: Text('Party')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Mode')),
              DataColumn(label: Text('Amount'), numeric: true),
              DataColumn(label: Text('Status')),
            ],
            rows: _items
                .map((p) => DataRow(
                      onSelectChanged: (_) => _open(p),
                      cells: [
                        DataCell(Text(p['payment_number']?.toString() ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800))),
                        DataCell(Text(p['contact_name']?.toString() ?? '')),
                        DataCell(Text(displayDate(p['payment_date']))),
                        DataCell(Text(p['payment_mode']?.toString() ?? '')),
                        DataCell(Text(money(p['amount']))),
                        DataCell(Text(p['status']?.toString() ?? '')),
                      ],
                    ))
                .toList(),
          ),
        ),
      );

  Widget _card(Map<String, dynamic> p) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Card(
          child: ListTile(
            onTap: () => _open(p),
            leading: CircleAvatar(
              backgroundColor:
                  (widget.vendor ? AppColors.danger : AppColors.success)
                      .withValues(alpha: .08),
              child: Icon(
                  widget.vendor
                      ? Icons.north_east_rounded
                      : Icons.south_west_rounded,
                  color: widget.vendor ? AppColors.danger : AppColors.success),
            ),
            title: Row(children: [
              Expanded(
                  child: Text(p['contact_name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(money(p['amount']),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            subtitle: Text(
                '${p['payment_number'] ?? ''} • ${p['payment_mode'] ?? ''} • ${displayDate(p['payment_date'])} • ${p['status'] ?? ''}'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        ),
      );
}

class PaymentEditorScreen extends StatefulWidget {
  const PaymentEditorScreen(
      {super.key, required this.api, required this.vendor});
  final ApiClient api;
  final bool vendor;
  @override
  State<PaymentEditorScreen> createState() => _PaymentEditorScreenState();
}

class _PaymentEditorScreenState extends State<PaymentEditorScreen> {
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _outstanding = [];
  String? _contactId;
  String _mode = 'BANK';
  String _advanceSupplyType = 'GOODS';
  DateTime _date = DateTime.now();
  final _number = TextEditingController(),
      _amount = TextEditingController(),
      _reference = TextEditingController(),
      _description = TextEditingController();
  final Map<String, TextEditingController> _allocations = {};
  bool _loading = true, _saving = false;
  String? _error;
  String get endpoint =>
      widget.vendor ? '/payments/disbursements' : '/payments/receipts';
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _number.dispose();
    _amount.dispose();
    _reference.dispose();
    _description.dispose();
    for (final c in _allocations.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final d = await widget.api.get('/masters/contacts', query: {
        'contact_type': widget.vendor ? 'VENDOR' : 'CUSTOMER',
        'limit': 100
      });
      if (context.mounted) {
        setState(() => _contacts = (d as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList());
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseContact(String? id) async {
    setState(() => _contactId = id);
    for (final c in _allocations.values) {
      c.dispose();
    }
    _allocations.clear();
    _outstanding = [];
    if (id == null) return;
    setState(() => _loading = true);
    try {
      final path = widget.vendor
          ? '/payments/disbursements/outstanding/$id'
          : '/payments/receipts/outstanding/$id';
      final d = await widget.api.get(path);
      if (context.mounted) {
        setState(() {
          _outstanding = (d as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          for (final row in _outstanding) {
            _allocations[row['id'].toString()] =
                TextEditingController(text: '0');
          }
        });
      }
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  double get allocated =>
      _allocations.values.fold(0, (s, c) => s + (double.tryParse(c.text) ?? 0));
  void _fillOutstanding() {
    for (final row in _outstanding) {
      _allocations[row['id'].toString()]!.text = '${row['outstanding'] ?? 0}';
    }
    setState(() => _amount.text = allocated.toStringAsFixed(2));
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (_contactId == null || amount <= 0) {
      showMessage(
          context, 'Select a party and enter a positive payment amount.',
          error: true);
      return;
    }
    if (allocated > amount + .005) {
      showMessage(context, 'Allocated amount cannot exceed the payment amount.',
          error: true);
      return;
    }
    final allocations = <Map<String, dynamic>>[];
    for (final row in _outstanding) {
      final v = double.tryParse(_allocations[row['id'].toString()]!.text) ?? 0;
      if (v > 0) {
        allocations.add(
            {widget.vendor ? 'bill_id' : 'invoice_id': row['id'], 'amount': v});
      }
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'contact_id': _contactId,
        'payment_number':
            _number.text.trim().isEmpty ? null : _number.text.trim(),
        'payment_date': apiDate(_date),
        'payment_mode': _mode,
        'amount': amount,
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'allocations': allocations
      };
      if (!widget.vendor && amount - allocated > .005) {
        body['advance_supply_type'] = _advanceSupplyType;
      }
      await widget.api.post(endpoint, body: body);
      if (context.mounted) {
        showMessage(
            context,
            widget.vendor
                ? 'Vendor payment posted.'
                : 'Customer receipt posted.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.vendor
              ? 'Record vendor payment'
              : 'Record customer receipt'),
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(_saving ? 'Posting…' : 'Post')))
          ]),
      body: _error != null
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorPanel(message: _error!))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(children: [
                        SectionCard(
                            title: 'Payment details',
                            child: Wrap(spacing: 12, runSpacing: 12, children: [
                              SizedBox(
                                  width: 330,
                                  child: DropdownButtonFormField<String>(
                                      initialValue: _contactId,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText: widget.vendor
                                              ? 'Vendor'
                                              : 'Customer'),
                                      items: _contacts
                                          .map((c) => DropdownMenuItem(
                                              value: c['id']?.toString(),
                                              child: Text(
                                                  c['name']?.toString() ?? '',
                                                  overflow:
                                                      TextOverflow.ellipsis)))
                                          .toList(),
                                      onChanged: _chooseContact)),
                              SizedBox(
                                  width: 200,
                                  child: TextField(
                                      controller: _number,
                                      decoration: const InputDecoration(
                                          labelText: 'Payment number',
                                          hintText: 'Auto if blank'))),
                              SizedBox(
                                  width: 200,
                                  child: InkWell(
                                      onTap: () async {
                                        final d =
                                            await pickDate(context, _date);
                                        if (d != null) {
                                          setState(() => _date = d);
                                        }
                                      },
                                      child: InputDecorator(
                                          decoration: const InputDecoration(
                                              labelText: 'Payment date',
                                              suffixIcon: Icon(Icons
                                                  .calendar_month_outlined)),
                                          child: Text(displayDate(
                                              _date.toIso8601String()))))),
                              SizedBox(
                                  width: 190,
                                  child: DropdownButtonFormField<String>(
                                      initialValue: _mode,
                                      decoration: const InputDecoration(
                                          labelText: 'Mode'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'CASH', child: Text('Cash')),
                                        DropdownMenuItem(
                                            value: 'BANK', child: Text('Bank')),
                                        DropdownMenuItem(
                                            value: 'UPI', child: Text('UPI')),
                                        DropdownMenuItem(
                                            value: 'POS', child: Text('POS')),
                                        DropdownMenuItem(
                                            value: 'CHEQUE',
                                            child: Text('Cheque')),
                                        DropdownMenuItem(
                                            value: 'NEFT_RTGS',
                                            child: Text('NEFT / RTGS')),
                                        DropdownMenuItem(
                                            value: 'OTHER',
                                            child: Text('Other'))
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _mode = v!))),
                              SizedBox(
                                  width: 190,
                                  child: TextField(
                                      controller: _amount,
                                      onChanged: (_) => setState(() {}),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: const InputDecoration(
                                          labelText: 'Amount'))),
                              SizedBox(
                                  width: 250,
                                  child: TextField(
                                      controller: _reference,
                                      decoration: const InputDecoration(
                                          labelText: 'Reference / UTR'))),
                              SizedBox(
                                  width: 480,
                                  child: TextField(
                                      controller: _description,
                                      decoration: const InputDecoration(
                                          labelText: 'Description')))
                            ])),
                        const SizedBox(height: 14),
                        SectionCard(
                            title: widget.vendor
                                ? 'Allocate to bills'
                                : 'Allocate to invoices',
                            trailing: TextButton(
                                onPressed: _outstanding.isEmpty
                                    ? null
                                    : _fillOutstanding,
                                child: const Text('Allocate all')),
                            child: _loading
                                ? const Padding(
                                    padding: EdgeInsets.all(30),
                                    child: CircularProgressIndicator())
                                : _contactId == null
                                    ? const Text(
                                        'Select a party to load outstanding documents.',
                                        style:
                                            TextStyle(color: AppColors.muted))
                                    : _outstanding.isEmpty
                                        ? const Text(
                                            'No outstanding documents for this party.',
                                            style: TextStyle(
                                                color: AppColors.muted))
                                        : Column(
                                            children: _outstanding.map((row) {
                                            final id = row['id'].toString();
                                            final number = row[widget.vendor
                                                ? 'bill_number'
                                                : 'invoice_number'];
                                            return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                child: Row(children: [
                                                  Expanded(
                                                      child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                        Text(
                                                            number?.toString() ??
                                                                '',
                                                            style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700)),
                                                        Text(
                                                            'Due ${displayDate(row['due_date'])} • Outstanding ${money(row['outstanding'])}',
                                                            style: const TextStyle(
                                                                fontSize: 11,
                                                                color: AppColors
                                                                    .muted))
                                                      ])),
                                                  SizedBox(
                                                      width: 160,
                                                      child: TextField(
                                                          controller:
                                                              _allocations[id],
                                                          onChanged: (_) =>
                                                              setState(() {}),
                                                          keyboardType:
                                                              const TextInputType
                                                                  .numberWithOptions(
                                                                  decimal:
                                                                      true),
                                                          decoration:
                                                              const InputDecoration(
                                                                  labelText:
                                                                      'Allocate')))
                                                ]));
                                          }).toList())),
                        const SizedBox(height: 14),
                        if (!widget.vendor &&
                            ((double.tryParse(_amount.text) ?? 0) - allocated) >
                                .005)
                          SectionCard(
                              title: 'Customer advance',
                              child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    SizedBox(
                                        width: 240,
                                        child: DropdownButtonFormField<String>(
                                            initialValue: _advanceSupplyType,
                                            decoration: const InputDecoration(
                                                labelText: 'Intended supply'),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'GOODS',
                                                  child: Text('Goods')),
                                              DropdownMenuItem(
                                                  value: 'SERVICES',
                                                  child: Text('Services'))
                                            ],
                                            onChanged: (v) => setState(() =>
                                                _advanceSupplyType = v!))),
                                    const SizedBox(
                                        width: 560,
                                        child: Text(
                                            'Unallocated receipts become customer credit. Taxable service advances are rejected by the backend and need the dedicated taxable advance workflow.',
                                            style: TextStyle(
                                                color: AppColors.muted)))
                                  ])),
                        if (!widget.vendor &&
                            ((double.tryParse(_amount.text) ?? 0) - allocated) >
                                .005)
                          const SizedBox(height: 14),
                        SectionCard(
                            child: Row(children: [
                          Expanded(
                              child: Text(
                                  'Payment ${money(double.tryParse(_amount.text) ?? 0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          Expanded(
                              child: Text('Allocated ${money(allocated)}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                          Expanded(
                              child: Text(
                                  'Unallocated ${money((double.tryParse(_amount.text) ?? 0) - allocated)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)))
                        ]))
                      ])))));
}
