import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _journals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        widget.api.get('/masters/accounts', query: {'limit': 500}),
        widget.api.get('/accounting/journals', query: {'limit': 200}),
      ]);
      if (!context.mounted) return;
      setState(() {
        _accounts = _rows(result[0]);
        _journals = _rows(result[1]);
      });
    } catch (e) {
      if (context.mounted) setState(() => _error = e.toString());
    } finally {
      if (context.mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accountEditor([Map<String, dynamic>? account]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _AccountDialog(
        api: widget.api,
        existing: account,
        accounts: _accounts,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleAccount(Map<String, dynamic> account) async {
    final active = account['is_active'] != false;
    try {
      await widget.api.put('/masters/accounts/${account['id']}', body: {
        'is_active': !active,
      });
      if (context.mounted) {
        showMessage(
            context, active ? 'Account deactivated.' : 'Account activated.');
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete ledger account?'),
        content: Text(
          '${account['code'] ?? ''} ${account['name'] ?? ''}\n\n'
          'Accounts with balances, journal activity or child accounts cannot be deleted. '
          'Deactivate those accounts instead.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.api.delete('/masters/accounts/${account['id']}');
      if (context.mounted) showMessage(context, 'Account deleted.');
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _seedDefaults() async {
    try {
      final result = await widget.api.post('/masters/accounts/seed-defaults');
      if (context.mounted) {
        final data = result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{};
        showMessage(
            context, '${data['message'] ?? 'Standard accounts checked.'}');
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _dedupeContactAccounts() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Merge duplicate party ledgers?'),
        content: const Text(
          'The backend will merge duplicate auto-created customer/vendor ledgers and '
          'repoint journal lines to the retained account. This is an accounting repair action.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run repair')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final result =
          await widget.api.post('/masters/accounts/dedupe-contact-accounts');
      if (context.mounted) {
        final data = result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{};
        showMessage(context,
            'Merged ${data['merged_accounts'] ?? 0} duplicate account(s).');
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _recalculateBalances() async {
    try {
      final result = await widget.api.post('/accounting/recalculate-balances');
      if (context.mounted) {
        final data = result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{};
        showMessage(context, '${data['message'] ?? 'Balances recalculated.'}');
      }
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _showLedger(Map<String, dynamic> account) async {
    try {
      final raw = await widget.api
          .get('/accounting/ledger/${account['id']}', query: {'limit': 500});
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _LedgerDialog(data: data),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _newJournal() async {
    if (_accounts.where((a) => a['is_active'] != false).length < 2) {
      showMessage(context, 'Create at least two active ledger accounts first.',
          error: true);
      return;
    }
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _JournalEditor(api: widget.api, accounts: _accounts),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _newContra() async {
    final cashBank = _accounts
        .where((a) =>
            a['is_active'] != false && a['account_group'] == 'Cash & Bank')
        .toList();
    if (cashBank.length < 2) {
      showMessage(context,
          'Contra entries need at least two active Cash & Bank accounts.',
          error: true);
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ContraDialog(api: widget.api, accounts: cashBank),
    );
    if (saved == true) _load();
  }

  Future<void> _reverseJournal(Map<String, dynamic> journal) async {
    final reason = TextEditingController();
    var reversalDate = DateTime.now();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Reverse ${journal['reference_number'] ?? 'journal'}'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () async {
                  final picked = await pickDate(context, reversalDate);
                  if (picked != null) setLocal(() => reversalDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Reversal date'),
                  child: Text(displayDate(reversalDate.toIso8601String())),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Reason *'),
              ),
              const SizedBox(height: 10),
              const Text(
                'The original entry remains immutable. A new equal-and-opposite journal is posted.',
                style: TextStyle(color: AppColors.muted),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (reason.text.trim().length < 3) {
                  showMessage(context,
                      'Enter a reversal reason (at least 3 characters).',
                      error: true);
                  return;
                }
                Navigator.pop(dialogContext, {
                  'reversal_date': apiDate(reversalDate),
                  'reason': reason.text.trim(),
                });
              },
              child: const Text('Post reversal'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (result == null) return;
    try {
      await widget.api
          .post('/accounting/journals/${journal['id']}/reverse', body: result);
      if (context.mounted) showMessage(context, 'Journal reversal posted.');
      await _load();
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Accounting',
      subtitle:
          'Chart of accounts, ledgers, contra transfers and immutable double-entry journals.',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        if (_tabs.index == 0)
          PopupMenuButton<String>(
            tooltip: 'Accounting tools',
            onSelected: (value) {
              if (value == 'seed') _seedDefaults();
              if (value == 'dedupe') _dedupeContactAccounts();
              if (value == 'recalc') _recalculateBalances();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'seed', child: Text('Seed/check standard accounts')),
              PopupMenuItem(
                  value: 'dedupe',
                  child: Text('Merge duplicate party ledgers')),
              PopupMenuItem(
                  value: 'recalc', child: Text('Recalculate balances')),
            ],
          )
        else
          OutlinedButton.icon(
            onPressed: _newContra,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Contra'),
          ),
        FilledButton.icon(
          onPressed: () => _tabs.index == 0 ? _accountEditor() : _newJournal(),
          icon: const Icon(Icons.add_rounded),
          label: Text(_tabs.index == 0 ? 'New account' : 'New journal'),
        ),
      ],
      child: Column(children: [
        SectionCard(
          child: TabBar(
            controller: _tabs,
            onTap: (_) => setState(() {}),
            tabs: const [
              Tab(
                  icon: Icon(Icons.account_tree_outlined),
                  text: 'Chart of Accounts'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Journals'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(50), child: CircularProgressIndicator())
        else if (_error != null)
          ErrorPanel(message: _error!, onRetry: _load)
        else
          AnimatedBuilder(
            animation: _tabs,
            builder: (context, _) =>
                _tabs.index == 0 ? _accountsView() : _journalsView(),
          ),
      ]),
    );
  }

  Widget _accountsView() {
    if (_accounts.isEmpty) {
      return EmptyState(
        icon: Icons.account_tree_outlined,
        title: 'No accounts',
        message:
            'Provision the standard Indian bookkeeping ledger structure or create an account.',
        action: Wrap(spacing: 8, children: [
          FilledButton.icon(
              onPressed: _seedDefaults,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Seed defaults')),
          OutlinedButton.icon(
              onPressed: () => _accountEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create account')),
        ]),
      );
    }
    return SectionCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Code')),
            DataColumn(label: Text('Account')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Group')),
            DataColumn(label: Text('Opening'), numeric: true),
            DataColumn(label: Text('Current'), numeric: true),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _accounts.map((a) {
            final active = a['is_active'] != false;
            return DataRow(cells: [
              DataCell(Text('${a['code'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(InkWell(
                  onTap: () => _showLedger(a),
                  child: Text('${a['name'] ?? ''}',
                      style: const TextStyle(
                          decoration: TextDecoration.underline)))),
              DataCell(Text('${a['account_type'] ?? ''}')),
              DataCell(Text('${a['account_group'] ?? '—'}')),
              DataCell(Text(money(a['opening_balance']))),
              DataCell(Text(money(a['current_balance']),
                  style: const TextStyle(fontWeight: FontWeight.w800))),
              DataCell(Text(active ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.success : AppColors.muted))),
              DataCell(PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'ledger') _showLedger(a);
                  if (value == 'edit') _accountEditor(a);
                  if (value == 'toggle') _toggleAccount(a);
                  if (value == 'delete') _deleteAccount(a);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'ledger', child: Text('View ledger')),
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit account')),
                  PopupMenuItem(
                      value: 'toggle',
                      child: Text(active ? 'Deactivate' : 'Activate')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete if unused')),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _journalsView() {
    if (_journals.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: 'No journals',
        message:
            'Operational documents post automatically. Use manual journals for adjustments and contra for cash/bank transfers.',
        action: Wrap(spacing: 8, children: [
          FilledButton.icon(
              onPressed: _newJournal,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New journal')),
          OutlinedButton.icon(
              onPressed: _newContra,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Contra')),
        ]),
      );
    }
    return Column(
      children: _journals.map((j) {
        final lines = j['lines'] is List ? j['lines'] as List : const [];
        final source = '${j['source_type'] ?? ''}';
        final canReverse = (source == 'MANUAL' || source == 'CONTRA') &&
            j['reversal_transaction_id'] == null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                  child: Icon(source == 'CONTRA'
                      ? Icons.swap_horiz_rounded
                      : Icons.menu_book_outlined)),
              title: Row(children: [
                Expanded(
                    child: Text('${j['reference_number'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                Text(displayDate(j['entry_date'])),
                const SizedBox(width: 6),
                if (canReverse)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'reverse') _reverseJournal(j);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'reverse', child: Text('Reverse journal'))
                    ],
                  ),
              ]),
              subtitle: Text(
                  '${j['description'] ?? ''} • $source${j['reversal_transaction_id'] != null ? ' • REVERSED' : ''}'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    children: lines.map((raw) {
                      final line = Map<String, dynamic>.from(raw as Map);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  '${line['account_code'] ?? ''} ${line['account_name'] ?? ''}')),
                          Text(
                            '${line['direction'] ?? ''}  ${money(line['amount'])}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: line['direction'] == 'DEBIT'
                                  ? AppColors.primary
                                  : AppColors.success,
                            ),
                          ),
                        ]),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({
    required this.api,
    required this.accounts,
    this.existing,
  });
  final ApiClient api;
  final List<Map<String, dynamic>> accounts;
  final Map<String, dynamic>? existing;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _group;
  late final TextEditingController _opening;
  late String _type;
  String? _parentId;
  bool _active = true;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing ?? const <String, dynamic>{};
    _name = TextEditingController(text: '${a['name'] ?? ''}');
    _code = TextEditingController(text: '${a['code'] ?? ''}');
    _group = TextEditingController(text: '${a['account_group'] ?? ''}');
    _opening = TextEditingController(text: '${a['opening_balance'] ?? 0}');
    _type = '${a['account_type'] ?? 'ASSET'}';
    _parentId = a['parent_id']?.toString();
    _active = a['is_active'] != false;
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _group, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _code.text.trim().isEmpty) {
      showMessage(context, 'Name and code are required.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_editing) {
        await widget.api
            .put('/masters/accounts/${widget.existing!['id']}', body: {
          'name': _name.text.trim(),
          'code': _code.text.trim().toUpperCase(),
          'parent_id': _parentId,
          'opening_balance': double.tryParse(_opening.text) ?? 0,
          'is_active': _active,
        });
      } else {
        await widget.api.post('/masters/accounts', body: {
          'name': _name.text.trim(),
          'code': _code.text.trim().toUpperCase(),
          'account_type': _type,
          'account_group':
              _group.text.trim().isEmpty ? null : _group.text.trim(),
          'parent_id': _parentId,
          'opening_balance': double.tryParse(_opening.text) ?? 0,
        });
      }
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentChoices = widget.accounts.where((a) {
      if (widget.existing != null &&
          '${a['id']}' == '${widget.existing!['id']}') {
        return false;
      }
      return '${a['account_type']}' == _type && a['is_active'] != false;
    }).toList();
    if (_parentId != null &&
        !parentChoices.any((a) => '${a['id']}' == _parentId)) {
      _parentId = null;
    }

    return AlertDialog(
      title: Text(_editing ? 'Edit ledger account' : 'Create ledger account'),
      content: SizedBox(
        width: 580,
        child: Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: 270,
              child: TextField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Account name'))),
          SizedBox(
              width: 190,
              child: TextField(
                  controller: _code,
                  decoration: const InputDecoration(labelText: 'Code'))),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'ASSET', child: Text('Asset')),
                DropdownMenuItem(value: 'LIABILITY', child: Text('Liability')),
                DropdownMenuItem(value: 'EQUITY', child: Text('Equity')),
                DropdownMenuItem(value: 'REVENUE', child: Text('Revenue')),
                DropdownMenuItem(value: 'EXPENSE', child: Text('Expense')),
              ],
              onChanged: _editing ? null : (v) => setState(() => _type = v!),
            ),
          ),
          SizedBox(
              width: 270,
              child: TextField(
                  controller: _group,
                  enabled: !_editing,
                  decoration:
                      const InputDecoration(labelText: 'Account group'))),
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String?>(
              initialValue: _parentId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Parent account (optional)'),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('No parent')),
                ...parentChoices.map((a) => DropdownMenuItem<String?>(
                    value: '${a['id']}',
                    child: Text('${a['code']} • ${a['name']}'))),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
          ),
          SizedBox(
              width: 190,
              child: TextField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  decoration:
                      const InputDecoration(labelText: 'Opening balance'))),
          if (_editing)
            SizedBox(
              width: 230,
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active account'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
                _saving ? 'Saving…' : (_editing ? 'Save changes' : 'Create'))),
      ],
    );
  }
}

class _LedgerDialog extends StatelessWidget {
  const _LedgerDialog({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final lines = data['lines'] is List ? data['lines'] as List : const [];
    return AlertDialog(
      title: Text(
          '${data['account_code'] ?? ''} • ${data['account_name'] ?? 'Ledger'}'),
      content: SizedBox(
        width: 900,
        height: 560,
        child: Column(children: [
          Row(children: [
            Expanded(
                child: _LedgerMetric(
                    label: 'Opening', value: money(data['opening_balance']))),
            const SizedBox(width: 10),
            Expanded(
                child: _LedgerMetric(
                    label: 'Closing', value: money(data['closing_balance']))),
            const SizedBox(width: 10),
            Expanded(
                child: _LedgerMetric(
                    label: 'Entries',
                    value: '${data['total_lines'] ?? lines.length}')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: lines.isEmpty
                ? const Center(child: Text('No ledger movements.'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Reference')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Debit'), numeric: true),
                          DataColumn(label: Text('Credit'), numeric: true),
                          DataColumn(label: Text('Running'), numeric: true),
                        ],
                        rows: lines.map((raw) {
                          final line = Map<String, dynamic>.from(raw as Map);
                          return DataRow(cells: [
                            DataCell(Text(displayDate(line['entry_date']))),
                            DataCell(Text('${line['reference_number'] ?? ''}')),
                            DataCell(SizedBox(
                                width: 260,
                                child: Text(
                                    '${line['description'] ?? line['narration'] ?? ''}'))),
                            DataCell(Text(money(line['debit_amount']))),
                            DataCell(Text(money(line['credit_amount']))),
                            DataCell(Text(money(line['running_balance']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }
}

class _LedgerMetric extends StatelessWidget {
  const _LedgerMetric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
      );
}

class _ContraDialog extends StatefulWidget {
  const _ContraDialog({required this.api, required this.accounts});
  final ApiClient api;
  final List<Map<String, dynamic>> accounts;

  @override
  State<_ContraDialog> createState() => _ContraDialogState();
}

class _ContraDialogState extends State<_ContraDialog> {
  String? _debitId;
  String? _creditId;
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _reference = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (_debitId == null ||
        _creditId == null ||
        _debitId == _creditId ||
        amount <= 0) {
      showMessage(context,
          'Choose two different Cash & Bank accounts and a positive amount.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.post('/accounting/contra', body: {
        'entry_date': apiDate(_date),
        'debit_account_id': _debitId,
        'credit_account_id': _creditId,
        'amount': amount,
        'description':
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
      });
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Cash / bank contra transfer'),
        content: SizedBox(
          width: 600,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            InkWell(
              onTap: () async {
                final d = await pickDate(context, _date);
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Entry date'),
                  child: Text(displayDate(_date.toIso8601String()))),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _debitId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Money moves into (debit) *'),
              items: widget.accounts
                  .map((a) => DropdownMenuItem(
                      value: '${a['id']}',
                      child: Text('${a['code']} • ${a['name']}')))
                  .toList(),
              onChanged: (v) => setState(() => _debitId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _creditId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Money moves out of (credit) *'),
              items: widget.accounts
                  .map((a) => DropdownMenuItem(
                      value: '${a['id']}',
                      child: Text('${a['code']} • ${a['name']}')))
                  .toList(),
              onChanged: (v) => setState(() => _creditId = v),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Amount *'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _reference,
                      decoration:
                          const InputDecoration(labelText: 'Reference'))),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Posting…' : 'Post contra')),
        ],
      );
}

class _JournalEditor extends StatefulWidget {
  const _JournalEditor({required this.api, required this.accounts});
  final ApiClient api;
  final List<Map<String, dynamic>> accounts;
  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  final _description = TextEditingController();
  final _reference = TextEditingController();
  DateTime _date = DateTime.now();
  final List<_JournalLineDraft> _lines = [
    _JournalLineDraft(direction: 'DEBIT'),
    _JournalLineDraft(direction: 'CREDIT'),
  ];
  bool _saving = false;

  List<Map<String, dynamic>> get _activeAccounts =>
      widget.accounts.where((a) => a['is_active'] != false).toList();
  double get _debits => _lines
      .where((l) => l.direction == 'DEBIT')
      .fold(0, (s, l) => s + (double.tryParse(l.amount.text) ?? 0));
  double get _credits => _lines
      .where((l) => l.direction == 'CREDIT')
      .fold(0, (s, l) => s + (double.tryParse(l.amount.text) ?? 0));

  @override
  void dispose() {
    _description.dispose();
    _reference.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_description.text.trim().isEmpty) {
      showMessage(context, 'Description is required.', error: true);
      return;
    }
    if (_lines.any((l) =>
        l.accountId == null || (double.tryParse(l.amount.text) ?? 0) <= 0)) {
      showMessage(context, 'Every line needs an account and positive amount.',
          error: true);
      return;
    }
    if ((_debits - _credits).abs() > .005) {
      showMessage(
          context, 'Journal is out of balance. Debits must equal credits.',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.post('/accounting/journals', body: {
        'entry_date': apiDate(_date),
        'reference_number':
            _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'description': _description.text.trim(),
        'lines': _lines
            .map((l) => {
                  'account_id': l.accountId,
                  'amount': double.tryParse(l.amount.text) ?? 0,
                  'direction': l.direction,
                  'narration': l.narration.text.trim().isEmpty
                      ? null
                      : l.narration.text.trim(),
                })
            .toList(),
      });
      if (context.mounted) Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }

  void _addLine() =>
      setState(() => _lines.add(_JournalLineDraft(direction: 'DEBIT')));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Manual journal'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Posting…' : 'Post journal'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: Column(children: [
                SectionCard(
                  title: 'Journal header',
                  child: Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(
                      width: 220,
                      child: InkWell(
                        onTap: () async {
                          final d = await pickDate(context, _date);
                          if (d != null) setState(() => _date = d);
                        },
                        child: InputDecorator(
                            decoration:
                                const InputDecoration(labelText: 'Entry date'),
                            child: Text(displayDate(_date.toIso8601String()))),
                      ),
                    ),
                    SizedBox(
                        width: 260,
                        child: TextField(
                            controller: _reference,
                            decoration: const InputDecoration(
                                labelText: 'Reference (optional)'))),
                    SizedBox(
                        width: 480,
                        child: TextField(
                            controller: _description,
                            decoration: const InputDecoration(
                                labelText: 'Description *'))),
                  ]),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Double-entry lines',
                  trailing: TextButton.icon(
                      onPressed: _addLine,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add line')),
                  child: Column(children: [
                    for (var i = 0; i < _lines.length; i++) ...[
                      _JournalLineEditor(
                        line: _lines[i],
                        accounts: _activeAccounts,
                        onChanged: () => setState(() {}),
                        onRemove: _lines.length <= 2
                            ? null
                            : () {
                                setState(() {
                                  _lines.removeAt(i).dispose();
                                });
                              },
                      ),
                      if (i != _lines.length - 1) const Divider(height: 22),
                    ],
                    const Divider(height: 24),
                    Row(children: [
                      Expanded(
                          child: Text('Debits ${money(_debits)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      Expanded(
                          child: Text('Credits ${money(_credits)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                    ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: (_debits - _credits).abs() <= .005 && _debits > 0
                            ? 1
                            : .35),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _JournalLineEditor extends StatelessWidget {
  const _JournalLineEditor({
    required this.line,
    required this.accounts,
    required this.onChanged,
    this.onRemove,
  });
  final _JournalLineDraft line;
  final List<Map<String, dynamic>> accounts;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 330,
            child: DropdownButtonFormField<String>(
              initialValue: line.accountId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Account'),
              items: accounts
                  .map((a) => DropdownMenuItem<String>(
                      value: '${a['id']}',
                      child: Text('${a['code'] ?? ''} • ${a['name'] ?? ''}')))
                  .toList(),
              onChanged: (v) {
                line.accountId = v;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 145,
            child: DropdownButtonFormField<String>(
              initialValue: line.direction,
              decoration: const InputDecoration(labelText: 'Direction'),
              items: const [
                DropdownMenuItem(value: 'DEBIT', child: Text('Debit')),
                DropdownMenuItem(value: 'CREDIT', child: Text('Credit')),
              ],
              onChanged: (v) {
                line.direction = v!;
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: line.amount,
              onChanged: (_) => onChanged(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
          ),
          SizedBox(
              width: 260,
              child: TextField(
                  controller: line.narration,
                  decoration: const InputDecoration(labelText: 'Narration'))),
          if (onRemove != null)
            IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded)),
        ],
      );
}

class _JournalLineDraft {
  _JournalLineDraft({required this.direction});
  String? accountId;
  String direction;
  final amount = TextEditingController();
  final narration = TextEditingController();
  void dispose() {
    amount.dispose();
    narration.dispose();
  }
}
