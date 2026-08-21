import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      final data = await widget.api.get('/expenses', query: {'limit': 100});
      if (context.mounted) {
        setState(() => _items = (data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
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
      MaterialPageRoute(builder: (_) => ExpenseEditorScreen(api: widget.api)),
    );
    if (saved == true) _load();
  }

  Future<void> _manageCategories() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseCategoriesDialog(api: widget.api),
    );
    if (changed == true) _load();
  }

  Future<void> _detail(Map<String, dynamic> row) async {
    try {
      final raw = await widget.api.get('/expenses/${row['id']}');
      if (!context.mounted) return;
      final detail = Map<String, dynamic>.from(raw as Map);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(children: [
            Expanded(child: Text('${detail['expense_number'] ?? 'Expense'}')),
            _statusChip('${detail['status'] ?? ''}'),
          ]),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 24, runSpacing: 14, children: [
                    _detailField('Date', displayDate(detail['expense_date'])),
                    _detailField(
                        'Category', '${detail['category_name'] ?? '—'}'),
                    _detailField('Vendor', '${detail['vendor_name'] ?? '—'}'),
                    _detailField(
                        'Reference', '${detail['reference_number'] ?? '—'}'),
                    _detailField('Taxable', money(detail['amount'])),
                    _detailField('GST rate', '${detail['gst_rate'] ?? 0}%'),
                    _detailField('CGST', money(detail['cgst_amount'])),
                    _detailField('SGST', money(detail['sgst_amount'])),
                    _detailField('IGST', money(detail['igst_amount'])),
                    _detailField('Total', money(detail['total'])),
                  ]),
                  if ('${detail['description'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('${detail['description']}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                  if ('${detail['notes'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${detail['notes']}',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
            if (detail['status'] == 'DRAFT')
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final saved = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExpenseEditorScreen(
                          api: widget.api, initialId: '${detail['id']}'),
                    ),
                  );
                  if (saved == true) _load();
                },
                child: const Text('Edit draft'),
              ),
            if (detail['status'] == 'DRAFT')
              FilledButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _mutation('${detail['id']}', 'post',
                      'Post this draft expense to the ledger?');
                },
                child: const Text('Post'),
              ),
            if (detail['status'] == 'POSTED')
              FilledButton.tonal(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await _mutation(
                    '${detail['id']}',
                    'cancel',
                    'Cancel this posted expense? The backend will create the accounting reversal and enforce period locks.',
                  );
                },
                child: const Text('Cancel & reverse'),
              ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _clone('${detail['id']}');
              },
              child: const Text('Clone'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _clone(String id) async {
    try {
      final raw = await widget.api.post('/expenses/$id/clone');
      if (!context.mounted) return;
      final clone = Map<String, dynamic>.from(raw as Map);
      showMessage(
          context, 'Expense cloned as ${clone['expense_number'] ?? 'draft'}.');
      await _load();
      if (!context.mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ExpenseEditorScreen(api: widget.api, initialId: '${clone['id']}'),
        ),
      );
      if (saved == true) _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _mutation(String id, String action, String warning) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(action == 'post' ? 'Post expense' : 'Cancel expense'),
        content: Text(warning),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.post('/expenses/$id/$action');
      if (context.mounted) {
        showMessage(
            context,
            action == 'post'
                ? 'Expense posted.'
                : 'Expense cancelled and reversed.');
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Widget _statusChip(String status) => Chip(
        label: Text(titleCase(status)),
        visualDensity: VisualDensity.compact,
      );

  Widget _detailField(String label, String value) => SizedBox(
        width: 190,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Expenses',
        subtitle:
            'Operating spend with input GST, categories and auditable ledger reversals.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          OutlinedButton.icon(
            onPressed: _manageCategories,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Categories'),
          ),
          FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New expense')),
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(50), child: CircularProgressIndicator())
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? EmptyState(
                        icon: Icons.payments_outlined,
                        title: 'No expenses',
                        message:
                            'Record rent, travel, utilities and other operating expenses.',
                        action: FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New expense')),
                      )
                    : LayoutBuilder(
                        builder: (context, c) => c.maxWidth >= 850
                            ? _table()
                            : Column(children: _items.map(_card).toList()),
                      ),
      );

  Widget _table() => SectionCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Expense')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Vendor')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Status')),
            ],
            rows: _items
                .map(
                  (e) => DataRow(
                    onSelectChanged: (_) => _detail(e),
                    cells: [
                      DataCell(Text('${e['expense_number'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                      DataCell(Text(displayDate(e['expense_date']))),
                      DataCell(Text('${e['category_name'] ?? '—'}')),
                      DataCell(Text('${e['vendor_name'] ?? '—'}')),
                      DataCell(SizedBox(
                          width: 220,
                          child: Text('${e['description'] ?? '—'}',
                              overflow: TextOverflow.ellipsis))),
                      DataCell(Text(money(e['total']))),
                      DataCell(_statusChip('${e['status'] ?? ''}')),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      );

  Widget _card(Map<String, dynamic> e) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Card(
          child: ListTile(
            onTap: () => _detail(e),
            leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
            trailing: const Icon(Icons.chevron_right_rounded),
            title: Row(children: [
              Expanded(
                  child: Text('${e['category_name'] ?? 'Expense'}',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(money(e['total']),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            subtitle: Text(
                '${e['vendor_name'] ?? e['description'] ?? ''}\n${displayDate(e['expense_date'])} • ${e['expense_number'] ?? ''} • ${e['status'] ?? ''}'),
            isThreeLine: true,
          ),
        ),
      );
}

class ExpenseEditorScreen extends StatefulWidget {
  const ExpenseEditorScreen({super.key, required this.api, this.initialId});
  final ApiClient api;
  final String? initialId;

  @override
  State<ExpenseEditorScreen> createState() => _ExpenseEditorScreenState();
}

class _ExpenseEditorScreenState extends State<ExpenseEditorScreen> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _cashAccounts = [];
  String? _categoryId;
  String? _accountId;
  DateTime _date = DateTime.now();
  final _vendor = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _gst = TextEditingController(text: '0');
  final _pos = TextEditingController(text: '27');
  final _notes = TextEditingController();
  final _reference = TextEditingController();
  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _saving = false;
  bool _previewing = false;
  String? _error;
  Timer? _debounce;

  bool get _editing => widget.initialId != null;

  @override
  void initState() {
    super.initState();
    _load();
    for (final c in [_amount, _gst, _pos]) {
      c.addListener(_queuePreview);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _vendor,
      _description,
      _amount,
      _gst,
      _pos,
      _notes,
      _reference
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final futures = <Future<dynamic>>[
        widget.api.get('/masters/expense-categories'),
        widget.api.get('/masters/accounts', query: {'limit': 200}),
        if (_editing) widget.api.get('/expenses/${widget.initialId}'),
      ];
      final result = await Future.wait(futures);
      if (!context.mounted) return;
      _categories = (result[0] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _cashAccounts = (result[1] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((a) =>
              a['account_group'] == 'Cash & Bank' &&
              a['account_type'] == 'ASSET')
          .toList();
      if (_editing) {
        final row = Map<String, dynamic>.from(result[2] as Map);
        if (row['status'] != 'DRAFT') {
          throw StateError('Only draft expenses can be edited.');
        }
        _categoryId = '${row['expense_category_id']}';
        _accountId = row['bank_account_id']?.toString();
        _date = DateTime.tryParse('${row['expense_date']}') ?? DateTime.now();
        _vendor.text = '${row['vendor_name'] ?? ''}';
        _description.text = '${row['description'] ?? ''}';
        _amount.text = '${row['amount'] ?? ''}';
        _gst.text = '${row['gst_rate'] ?? 0}';
        _pos.text = '${row['place_of_supply_state_code'] ?? '27'}';
        _notes.text = '${row['notes'] ?? ''}';
        _reference.text = '${row['reference_number'] ?? ''}';
      } else if (_categories.isNotEmpty) {
        _categoryId = '${_categories.first['id']}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  void _queuePreview() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runPreview);
  }

  Future<void> _runPreview() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0 || _pos.text.length != 2) return;
    setState(() => _previewing = true);
    try {
      final data = await widget.api.post('/expenses/preview', body: {
        'amount': amount,
        'gst_rate': double.tryParse(_gst.text) ?? 0,
        'place_of_supply_state_code': _pos.text,
      });
      if (context.mounted) {
        setState(() => _preview = Map<String, dynamic>.from(data as Map));
      }
    } catch (_) {
      // The create/update endpoint remains authoritative if preview is unavailable.
    } finally {
      if (context.mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (_categoryId == null || amount <= 0 || _pos.text.trim().length != 2) {
      showMessage(context,
          'Select a category, enter a positive amount and a 2-digit place of supply.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'expense_category_id': _categoryId,
        'bank_account_id': _accountId,
        'expense_date': apiDate(_date),
        'vendor_name': _vendor.text.trim().isEmpty ? null : _vendor.text.trim(),
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'amount': amount,
        'gst_rate': double.tryParse(_gst.text) ?? 0,
        'place_of_supply_state_code': _pos.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      };
      if (_editing) {
        await widget.api.put('/expenses/${widget.initialId}', body: body);
      } else {
        await widget.api.post('/expenses', body: body);
      }
      if (context.mounted) {
        showMessage(
            context, _editing ? 'Draft expense updated.' : 'Expense posted.');
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
          title: Text(_editing ? 'Edit draft expense' : 'Record expense'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_saving
                    ? 'Saving…'
                    : _editing
                        ? 'Save draft'
                        : 'Post expense'),
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
                        constraints: const BoxConstraints(maxWidth: 960),
                        child: Column(children: [
                          SectionCard(
                            title: 'Expense details',
                            child: Wrap(spacing: 12, runSpacing: 12, children: [
                              SizedBox(
                                width: 300,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _categoryId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Expense category'),
                                  items: _categories
                                      .map((c) => DropdownMenuItem<String>(
                                          value: '${c['id']}',
                                          child: Text('${c['name'] ?? ''}')))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _categoryId = v),
                                ),
                              ),
                              SizedBox(
                                width: 300,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _accountId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Paid from (optional)'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Default cash account')),
                                    ..._cashAccounts.map(
                                      (a) => DropdownMenuItem<String?>(
                                          value: '${a['id']}',
                                          child: Text('${a['name'] ?? ''}')),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _accountId = v),
                                ),
                              ),
                              SizedBox(
                                width: 190,
                                child: InkWell(
                                  onTap: () async {
                                    final d = await pickDate(context, _date);
                                    if (d != null) setState(() => _date = d);
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                        labelText: 'Expense date',
                                        suffixIcon: Icon(
                                            Icons.calendar_month_outlined)),
                                    child: Text(
                                        displayDate(_date.toIso8601String())),
                                  ),
                                ),
                              ),
                              SizedBox(
                                  width: 260,
                                  child: TextField(
                                      controller: _vendor,
                                      decoration: const InputDecoration(
                                          labelText: 'Vendor name'))),
                              SizedBox(
                                  width: 420,
                                  child: TextField(
                                      controller: _description,
                                      decoration: const InputDecoration(
                                          labelText: 'Description'))),
                              SizedBox(
                                width: 190,
                                child: TextField(
                                  controller: _amount,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Taxable amount'),
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _gst,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration:
                                      const InputDecoration(labelText: 'GST %'),
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
                              SizedBox(
                                  width: 260,
                                  child: TextField(
                                      controller: _reference,
                                      decoration: const InputDecoration(
                                          labelText: 'Reference'))),
                              SizedBox(
                                  width: 650,
                                  child: TextField(
                                      controller: _notes,
                                      maxLines: 2,
                                      decoration: const InputDecoration(
                                          labelText: 'Notes'))),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          SectionCard(
                            title: 'Tax preview',
                            trailing: _previewing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : null,
                            child: _preview == null
                                ? const Text(
                                    'Enter amount, GST rate and place of supply to preview taxes.',
                                    style: TextStyle(color: AppColors.muted))
                                : Wrap(spacing: 24, runSpacing: 12, children: [
                                    _previewMetric(
                                        'Taxable', _preview!['amount']),
                                    _previewMetric(
                                        'CGST', _preview!['cgst_amount']),
                                    _previewMetric(
                                        'SGST', _preview!['sgst_amount']),
                                    _previewMetric(
                                        'IGST', _preview!['igst_amount']),
                                    _previewMetric('Total', _preview!['total']),
                                  ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
      );

  Widget _previewMetric(String label, Object? value) => SizedBox(
        width: 130,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(money(value),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}

class _ExpenseCategoriesDialog extends StatefulWidget {
  const _ExpenseCategoriesDialog({required this.api});
  final ApiClient api;

  @override
  State<_ExpenseCategoriesDialog> createState() =>
      _ExpenseCategoriesDialogState();
}

class _ExpenseCategoriesDialogState extends State<_ExpenseCategoriesDialog> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        widget.api.get('/masters/expense-categories'),
        widget.api.get('/masters/accounts', query: {'limit': 200}),
      ]);
      if (!context.mounted) return;
      setState(() {
        _categories = (r[0] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _accounts = (r[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((a) =>
                a['account_type'] == 'EXPENSE' || a['account_type'] == 'ASSET')
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (context.mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseCategoryEditor(
          api: widget.api, accounts: _accounts, row: row),
    );
    if (changed == true) {
      _changed = true;
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete expense category?'),
        content: Text(
            '${row['name'] ?? 'This category'} will no longer be selectable.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.delete('/masters/expense-categories/${row['id']}');
      _changed = true;
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Expense categories'),
        content: SizedBox(
          width: 720,
          height: 480,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ErrorPanel(message: _error!, onRetry: _load)
                  : _categories.isEmpty
                      ? const EmptyState(
                          icon: Icons.category_outlined,
                          title: 'No categories',
                          message:
                              'Create a category and link it to a ledger account.')
                      : ListView.separated(
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = _categories[i];
                            final linked = _accounts
                                .where((a) =>
                                    '${a['id']}' == '${c['linked_account_id']}')
                                .toList();
                            return ListTile(
                              title: Text('${c['name'] ?? ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${c['description'] ?? ''}${linked.isEmpty ? '' : ' • ${linked.first['name']}'}'),
                              trailing: Wrap(children: [
                                IconButton(
                                    onPressed: () => _edit(c),
                                    icon: const Icon(Icons.edit_outlined)),
                                IconButton(
                                    onPressed: () => _delete(c),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded)),
                              ]),
                            );
                          },
                        ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, _changed),
              child: const Text('Done')),
          FilledButton.icon(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add category')),
        ],
      );
}

class _ExpenseCategoryEditor extends StatefulWidget {
  const _ExpenseCategoryEditor(
      {required this.api, required this.accounts, this.row});
  final ApiClient api;
  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic>? row;

  @override
  State<_ExpenseCategoryEditor> createState() => _ExpenseCategoryEditorState();
}

class _ExpenseCategoryEditorState extends State<_ExpenseCategoryEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _accountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: '${widget.row?['name'] ?? ''}');
    _description =
        TextEditingController(text: '${widget.row?['description'] ?? ''}');
    _accountId = widget.row?['linked_account_id']?.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Category name is required.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'name': _name.text.trim(),
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'linked_account_id': _accountId,
      };
      if (widget.row == null) {
        await widget.api.post('/masters/expense-categories', body: body);
      } else {
        await widget.api.put('/masters/expense-categories/${widget.row!['id']}',
            body: body);
      }
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.row == null ? 'Add category' : 'Edit category'),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Category name')),
            const SizedBox(height: 12),
            TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _accountId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Linked ledger account'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Use backend default purchase account')),
                ...widget.accounts.map(
                  (a) => DropdownMenuItem<String?>(
                    value: '${a['id']}',
                    child: Text('${a['code'] ?? ''} • ${a['name'] ?? ''}'),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _accountId = v),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save')),
        ],
      );
}
