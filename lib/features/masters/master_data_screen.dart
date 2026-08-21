import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _taxes = [];
  List<Map<String, dynamic>> _terms = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : const [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait([
        widget.api.get('/masters/expense-categories'),
        widget.api.get('/masters/tax-templates'),
        widget.api.get('/masters/payment-terms'),
        widget.api.get('/masters/accounts', query: {'limit': 500}),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = _rows(result[0]);
        _taxes = _rows(result[1]);
        _terms = _rows(result[2]);
        _accounts = _rows(result[3]);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _categoryEditor([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final description = TextEditingController(
      text: '${existing?['description'] ?? ''}',
    );
    String? accountId = existing?['linked_account_id']?.toString();
    var active = existing?['is_active'] != false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            existing == null ? 'New expense category' : 'Edit expense category',
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Category name *',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Linked expense/purchase ledger',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Backend default purchase account'),
                    ),
                    ..._accounts
                        .where((a) => a['is_active'] != false)
                        .map(
                          (a) => DropdownMenuItem<String?>(
                            value: '${a['id']}',
                            child: Text('${a['code']} • ${a['name']}'),
                          ),
                        ),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v),
                ),
                if (existing != null)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  showMessage(
                    context,
                    'Category name is required.',
                    error: true,
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'description': description.text.trim().isEmpty
                      ? null
                      : description.text.trim(),
                  'linked_account_id': accountId,
                  if (existing != null) 'is_active': active,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    if (result == null) return;
    try {
      if (existing == null) {
        await widget.api.post('/masters/expense-categories', body: result);
      } else {
        await widget.api.put(
          '/masters/expense-categories/${existing['id']}',
          body: result,
        );
      }
      if (mounted) showMessage(context, 'Expense category saved.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final ok = await _confirm(
      'Delete expense category?',
      'Delete ${category['name']}? Existing expenses may prevent deletion. Deactivation is safer for historical data.',
    );
    if (!ok) return;
    try {
      await widget.api.delete('/masters/expense-categories/${category['id']}');
      if (mounted) showMessage(context, 'Expense category deleted.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _taxEditor([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final rate = TextEditingController(text: '${existing?['rate'] ?? ''}');
    var active = existing?['is_active'] != false;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(existing == null ? 'New GST rate' : 'Edit GST rate'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rate,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Rate % *'),
                ),
                if (existing != null)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(rate.text);
                if (name.text.trim().isEmpty ||
                    parsed == null ||
                    parsed < 0 ||
                    parsed > 100) {
                  showMessage(
                    context,
                    'Enter a name and GST rate from 0 to 100.',
                    error: true,
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': name.text.trim(),
                  'rate': parsed,
                  if (existing != null) 'is_active': active,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    rate.dispose();
    if (result == null) return;
    try {
      if (existing == null) {
        await widget.api.post('/masters/tax-templates', body: result);
      } else {
        await widget.api.put(
          '/masters/tax-templates/${existing['id']}',
          body: result,
        );
      }
      if (mounted) showMessage(context, 'GST rate saved.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteTax(Map<String, dynamic> tax) async {
    if (tax['tenant_id'] == null) {
      showMessage(context, 'System GST rates are read-only.', error: true);
      return;
    }
    final ok = await _confirm(
      'Deactivate GST rate?',
      'Deactivate ${tax['name']} (${tax['rate']}%)?',
    );
    if (!ok) return;
    try {
      await widget.api.delete('/masters/tax-templates/${tax['id']}');
      if (mounted) showMessage(context, 'GST rate deactivated.');
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Master Data',
    subtitle: 'Expense categories, GST rate templates and payment terms used across transactions.',
    actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      if (_tabs.index == 0)
        FilledButton.icon(
          onPressed: () => _categoryEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New category'),
        )
      else if (_tabs.index == 1)
        FilledButton.icon(
          onPressed: () => _taxEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Custom GST rate'),
        ),
    ],
    child: Column(
      children: [
        SectionCard(
          child: TabBar(
            controller: _tabs,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(
                icon: Icon(Icons.category_outlined),
                text: 'Expense Categories',
              ),
              Tab(icon: Icon(Icons.percent_rounded), text: 'GST Rates'),
              Tab(icon: Icon(Icons.schedule_outlined), text: 'Payment Terms'),
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
        else
          AnimatedBuilder(
            animation: _tabs,
            builder: (_, __) => switch (_tabs.index) {
              0 => _categoriesView(),
              1 => _taxView(),
              _ => _termsView(),
            },
          ),
      ],
    ),
  );

  Widget _categoriesView() {
    if (_categories.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'No expense categories',
        message: 'Create categories and link them to ledger accounts for expense posting.',
        action: FilledButton.icon(
          onPressed: () => _categoryEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New category'),
        ),
      );
    }
    final byId = {for (final a in _accounts) '${a['id']}': a};
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Linked ledger')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _categories.map((c) {
            final linked = byId['${c['linked_account_id']}'];
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '${c['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 260,
                    child: Text('${c['description'] ?? '—'}'),
                  ),
                ),
                DataCell(
                  Text(
                    linked == null
                        ? 'Backend default'
                        : '${linked['code']} • ${linked['name']}',
                  ),
                ),
                DataCell(
                  Text(
                    c['is_active'] == false ? 'INACTIVE' : 'ACTIVE',
                    style: TextStyle(
                      color: c['is_active'] == false
                          ? AppColors.muted
                          : AppColors.success,
                    ),
                  ),
                ),
                DataCell(
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _categoryEditor(c);
                      if (v == 'delete') _deleteCategory(c);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _taxView() {
    if (_taxes.isEmpty) {
      return const EmptyState(
        icon: Icons.percent_rounded,
        title: 'No GST rate templates',
        message: 'No tax templates are currently configured.',
      );
    }
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Rate'), numeric: true),
            DataColumn(label: Text('Scope')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _taxes.map((t) {
            final custom = t['tenant_id'] != null;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '${t['name'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(Text('${t['rate'] ?? 0}%')),
                DataCell(Text(custom ? 'Company custom' : 'System standard')),
                DataCell(Text(t['is_active'] == false ? 'INACTIVE' : 'ACTIVE')),
                DataCell(
                  custom
                      ? PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _taxEditor(t);
                            if (v == 'delete') _deleteTax(t);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Deactivate'),
                            ),
                          ],
                        )
                      : const Tooltip(
                          message: 'System rate',
                          child: Icon(Icons.lock_outline_rounded, size: 18),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _termsView() {
    if (_terms.isEmpty) {
      return const EmptyState(
        icon: Icons.schedule_outlined,
        title: 'No payment terms',
        message: 'No active payment terms are configured by the backend.',
      );
    }
    return SectionCard(
      title: 'Payment terms',
      child: Column(
        children: _terms
            .map(
              (t) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.schedule_outlined),
                ),
                title: Text(
                  '${t['name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  t['tenant_id'] == null ? 'System standard' : 'Company term',
                ),
                trailing: Text(
                  '${t['due_days'] ?? 0} day(s)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
