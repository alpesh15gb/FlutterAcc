import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen> {
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _statements = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _reconciliations = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _detailLoading = false;
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
      final r = await Future.wait([
        widget.api.get('/masters/banking-profiles'),
        widget.api.get(
          '/bank-reconciliation/statements',
          query: {'limit': 100},
        ),
        widget.api.get(
          '/bank-reconciliation/reconciliations',
          query: {'limit': 500},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _profiles = _rows(r[0]);
        _statements = _rows(r[1]);
        _reconciliations = _rows(r[2]);
      });
      final selectedId = _selected?['id']?.toString();
      if (selectedId != null) {
        final current = _statements
            .where((s) => '${s['id']}' == selectedId)
            .firstOrNull;
        if (current != null) await _selectStatement(current);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectStatement(Map<String, dynamic> stmt) async {
    setState(() {
      _selected = stmt;
      _detailLoading = true;
    });
    try {
      final id = stmt['id'];
      final r = await Future.wait([
        widget.api.get('/bank-reconciliation/statements/$id/stats'),
        widget.api.get('/bank-reconciliation/statements/$id/transactions'),
        widget.api.get('/bank-reconciliation/statements/$id/suggestions'),
        widget.api.get(
          '/bank-reconciliation/reconciliations',
          query: {'limit': 500},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from(r[0] as Map);
        _transactions = _rows(r[1]);
        _suggestions = _rows(r[2]);
        _reconciliations = _rows(r[3]);
      });
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _newBank([Map<String, dynamic>? bank]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BankDialog(api: widget.api, item: bank),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleBank(Map<String, dynamic> bank) async {
    try {
      await widget.api.put(
        '/masters/banking-profiles/${bank['id']}',
        body: {'is_active': bank['is_active'] == false},
      );
      if (mounted) {
        showMessage(
          context,
          bank['is_active'] == false
              ? 'Bank account activated.'
              : 'Bank account deactivated.',
        );
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteBank(Map<String, dynamic> bank) async {
    if (!await _confirm(
      'Delete bank profile?',
      'Delete ${bank['bank_name'] ?? 'this bank account'} from master data?',
    ))
      return;
    try {
      await widget.api.delete('/masters/banking-profiles/${bank['id']}');
      if (mounted) {
        showMessage(context, 'Bank profile deleted.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _upload() async {
    final activeProfiles = _profiles
        .where((p) => p['is_active'] != false)
        .toList();
    if (activeProfiles.isEmpty) {
      showMessage(
        context,
        'Create an active bank profile before importing a statement.',
        error: true,
      );
      return;
    }
    String? profileId = '${activeProfiles.first['id']}';
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose bank account'),
        content: SizedBox(
          width: 440,
          child: DropdownButtonFormField<String>(
            value: profileId,
            isExpanded: true,
            items: activeProfiles
                .map(
                  (p) => DropdownMenuItem(
                    value: '${p['id']}',
                    child: Text(
                      '${p['bank_name'] ?? ''} • ${p['account_number'] ?? ''}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => profileId = v,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, profileId),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'xlsx', 'xls'],
      withData: true,
    );
    if (file == null) return;
    try {
      final data = await widget.api.upload(
        '/bank-reconciliation/upload',
        file.files.single,
        query: {'banking_profile_id': chosen},
      );
      if (mounted)
        showMessage(
          context,
          'Imported ${data['transactions_imported'] ?? ''} bank transactions.',
        );
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _deleteStatement(Map<String, dynamic> statement) async {
    if (!await _confirm(
      'Delete imported statement?',
      'Statements with reconciled transactions cannot be deleted until those reconciliations are undone.',
    ))
      return;
    try {
      await widget.api.delete(
        '/bank-reconciliation/statements/${statement['id']}',
      );
      if (mounted) {
        setState(() {
          if (_selected?['id'] == statement['id']) {
            _selected = null;
            _transactions = [];
            _stats = null;
          }
        });
        showMessage(context, 'Bank statement deleted.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _autoMatch() async {
    final id = _selected?['id'];
    if (id == null) return;
    try {
      final data = await widget.api.post(
        '/bank-reconciliation/statements/$id/auto-match',
      );
      if (mounted)
        showMessage(
          context,
          'Auto-matched ${data['matched'] ?? 0} transactions.',
        );
      await _selectStatement(_selected!);
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Map<String, dynamic>? _suggestionFor(String transactionId) {
    for (final s in _suggestions) {
      if ('${s['transaction_id']}' == transactionId) return s;
    }
    return null;
  }

  Map<String, dynamic>? _reconciliationFor(String transactionId) {
    for (final r in _reconciliations) {
      if ('${r['bank_transaction_id']}' == transactionId) return r;
    }
    return null;
  }

  Future<void> _manualMatch(Map<String, dynamic> txn) async {
    final suggestion = _suggestionFor('${txn['id']}');
    final suggestions = suggestion?['suggested_matches'] is List
        ? (suggestion!['suggested_matches'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
        : <Map<String, dynamic>>[];

    List<Map<String, dynamic>> candidates = suggestions;
    if (candidates.isEmpty) {
      try {
        final result = await Future.wait([
          widget.api.get('/payments/receipts', query: {'limit': 100}),
          widget.api.get('/payments/disbursements', query: {'limit': 100}),
        ]);
        candidates = [
          ..._rows(result[0])
              .where((p) => p['status'] != 'CANCELLED')
              .map(
                (p) => {
                  'type': 'payment',
                  'id': p['id'],
                  'amount': p['amount'],
                  'date': p['payment_date'],
                  'reference': p['payment_number'],
                  'score': null,
                },
              ),
          ..._rows(result[1])
              .where((p) => p['status'] != 'CANCELLED')
              .map(
                (p) => {
                  'type': 'bill_payment',
                  'id': p['id'],
                  'amount': p['amount'],
                  'date': p['payment_date'],
                  'reference': p['payment_number'],
                  'score': null,
                },
              ),
        ];
      } catch (e) {
        if (mounted) showMessage(context, e.toString(), error: true);
        return;
      }
    }
    if (!mounted) return;
    if (candidates.isEmpty) {
      showMessage(
        context,
        'No active receipt or disbursement is available to match.',
        error: true,
      );
      return;
    }

    String? selectedId = '${candidates.first['id']}';
    final notes = TextEditingController();
    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Reconcile bank transaction'),
          content: SizedBox(
            width: 680,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${displayDate(txn['transaction_date'])} • ${money(txn['amount'])}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  txn['description']?.toString() ?? '',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Receipt / disbursement',
                  ),
                  items: candidates
                      .map(
                        (c) => DropdownMenuItem(
                          value: '${c['id']}',
                          child: Text(
                            '${c['type'] == 'payment' ? 'Receipt' : 'Vendor payment'} • ${money(c['amount'])} • ${c['date'] ?? ''}${c['score'] == null ? '' : ' • score ${c['score']}'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => selectedId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final candidate = candidates.firstWhere(
                  (c) => '${c['id']}' == selectedId,
                );
                Navigator.pop(context, candidate);
              },
              child: const Text('Reconcile'),
            ),
          ],
        ),
      ),
    );
    final noteText = notes.text.trim();
    notes.dispose();
    if (chosen == null) return;
    try {
      await widget.api.post(
        '/bank-reconciliation/transactions/${txn['id']}/reconcile',
        body: {
          'payment_id': chosen['type'] == 'payment' ? chosen['id'] : null,
          'bill_payment_id': chosen['type'] == 'bill_payment'
              ? chosen['id']
              : null,
          'amount': (num.tryParse('${txn['amount']}') ?? 0).abs(),
          'notes': noteText.isEmpty
              ? 'Manually reconciled from Flutter app'
              : noteText,
        },
      );
      if (mounted) {
        showMessage(context, 'Transaction reconciled.');
        _selectStatement(_selected!);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _undo(Map<String, dynamic> txn) async {
    final recon = _reconciliationFor('${txn['id']}');
    if (recon == null) {
      showMessage(
        context,
        'Reconciliation record was not found. Refresh the statement.',
        error: true,
      );
      return;
    }
    try {
      await widget.api.post(
        '/bank-reconciliation/reconciliations/${recon['id']}/undo',
      );
      if (mounted) {
        showMessage(context, 'Reconciliation undone.');
        _selectStatement(_selected!);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Banking & Reconciliation',
    subtitle: 'Indian bank profiles, statement imports, suggestions, manual matching and reversals.',
    actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      OutlinedButton.icon(
        onPressed: () => _newBank(),
        icon: const Icon(Icons.account_balance_outlined),
        label: const Text('Add bank'),
      ),
      FilledButton.icon(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Import statement'),
      ),
    ],
    child: _loading
        ? const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null
        ? ErrorPanel(message: _error!, onRetry: _load)
        : Column(
            children: [
              _profilesCard(),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 1000;
                  final left = _statementList();
                  final right = _selected == null
                      ? _emptyDetail()
                      : _statementDetail();
                  if (!wide)
                    return Column(
                      children: [left, const SizedBox(height: 14), right],
                    );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 390, child: left),
                      const SizedBox(width: 14),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
            ],
          ),
  );

  Widget _profilesCard() => SectionCard(
    title: 'Bank accounts',
    child: _profiles.isEmpty
        ? const Text(
            'No bank profiles configured.',
            style: TextStyle(color: AppColors.muted),
          )
        : Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _profiles
                .map(
                  (p) => Container(
                    width: 310,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          color: p['is_active'] == false
                              ? AppColors.muted
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['bank_name']?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${p['account_number'] ?? ''} • ${p['ifsc_code'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                p['is_active'] == false
                                    ? 'Inactive'
                                    : (p['is_primary'] == true
                                          ? 'Primary'
                                          : 'Active'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _newBank(p);
                            if (v == 'toggle') _toggleBank(p);
                            if (v == 'delete') _deleteBank(p);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                p['is_active'] == false
                                    ? 'Activate'
                                    : 'Deactivate',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
  );

  Widget _statementList() => SectionCard(
    title: 'Imported statements',
    child: _statements.isEmpty
        ? EmptyState(
            icon: Icons.upload_file_outlined,
            title: 'No statements',
            message:
                'Import CSV or Excel from SBI, HDFC, ICICI or another bank.',
            action: FilledButton.icon(
              onPressed: _upload,
              icon: const Icon(Icons.upload_rounded),
              label: const Text('Import statement'),
            ),
          )
        : Column(
            children: _statements
                .map(
                  (s) => ListTile(
                    selected: _selected?['id'] == s['id'],
                    selectedTileColor: AppColors.primary.withOpacity(.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const CircleAvatar(
                      child: Icon(Icons.description_outlined),
                    ),
                    title: Text(
                      '${s['bank_name'] ?? 'Bank'} • ${displayDate(s['statement_date'])}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${s['account_number'] ?? ''} • ${s['status'] ?? ''}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'open') _selectStatement(s);
                        if (v == 'delete') _deleteStatement(s);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'open', child: Text('Open')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete statement'),
                        ),
                      ],
                    ),
                    onTap: () => _selectStatement(s),
                  ),
                )
                .toList(),
          ),
  );

  Widget _emptyDetail() => const SectionCard(
    child: EmptyState(
      icon: Icons.compare_arrows_rounded,
      title: 'Select a bank statement',
      message:
          'Review transactions, match suggestions and reconciliation status.',
    ),
  );

  Widget _statementDetail() {
    if (_detailLoading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final s = _stats ?? {};
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final metrics = [
              (
                'Transactions',
                s['total_transactions'],
                Icons.list_alt_rounded,
                AppColors.primary,
              ),
              (
                'Reconciled',
                s['reconciled'],
                Icons.check_circle_outline_rounded,
                AppColors.success,
              ),
              (
                'Pending',
                s['pending'],
                Icons.schedule_rounded,
                AppColors.warning,
              ),
              (
                'Matched %',
                '${s['reconciliation_pct'] ?? 0}%',
                Icons.donut_large_rounded,
                AppColors.primary,
              ),
            ];
            final cols = c.maxWidth >= 750 ? 4 : 2;
            final gap = 10.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metrics
                  .map(
                    (m) => SizedBox(
                      width: w,
                      child: MetricCard(
                        label: m.$1,
                        value: '${m.$2 ?? 0}',
                        icon: m.$3,
                        tone: m.$4,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Transactions',
          trailing: FilledButton.icon(
            onPressed: _autoMatch,
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Auto-match'),
          ),
          child: _transactions.isEmpty
              ? const Text('No transactions')
              : Column(
                  children: _transactions.map((t) {
                    final amount = num.tryParse('${t['amount']}') ?? 0;
                    final reconciled = t['status'] == 'RECONCILED';
                    final suggestion = _suggestionFor('${t['id']}');
                    final suggestionCount =
                        suggestion?['suggested_matches'] is List
                        ? (suggestion!['suggested_matches'] as List).length
                        : 0;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            (amount >= 0 ? AppColors.success : AppColors.danger)
                                .withOpacity(.08),
                        child: Icon(
                          amount >= 0
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: amount >= 0
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                      title: Text(
                        t['description']?.toString() ?? 'Bank transaction',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${displayDate(t['transaction_date'])} • ${t['reference_number'] ?? 'No reference'} • ${t['status'] ?? ''}${!reconciled && suggestionCount > 0 ? ' • $suggestionCount suggestion(s)' : ''}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            money(t['amount']),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (reconciled)
                            TextButton(
                              onPressed: () => _undo(t),
                              child: const Text('Undo'),
                            )
                          else
                            FilledButton.tonal(
                              onPressed: () => _manualMatch(t),
                              child: Text(
                                suggestionCount > 0 ? 'Review match' : 'Match',
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;
}

class _BankDialog extends StatefulWidget {
  const _BankDialog({required this.api, this.item});
  final ApiClient api;
  final Map<String, dynamic>? item;

  @override
  State<_BankDialog> createState() => _BankDialogState();
}

class _BankDialogState extends State<_BankDialog> {
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _ifsc;
  late final TextEditingController _branch;
  late final TextEditingController _holder;
  late final TextEditingController _upi;
  bool _primary = false;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.item ?? {};
    _bank = TextEditingController(text: p['bank_name']?.toString() ?? '');
    _account = TextEditingController(
      text: p['account_number']?.toString() ?? '',
    );
    _ifsc = TextEditingController(text: p['ifsc_code']?.toString() ?? '');
    _branch = TextEditingController(text: p['branch_name']?.toString() ?? '');
    _holder = TextEditingController(
      text: p['account_holder_name']?.toString() ?? '',
    );
    _upi = TextEditingController(text: p['upi_id']?.toString() ?? '');
    _primary = p['is_primary'] == true;
    _active = p['is_active'] != false;
  }

  @override
  void dispose() {
    for (final c in [_bank, _account, _ifsc, _branch, _holder, _upi])
      c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_bank.text.trim().isEmpty ||
        _account.text.trim().isEmpty ||
        _ifsc.text.trim().length != 11 ||
        _holder.text.trim().isEmpty) {
      showMessage(
        context,
        'Bank, account number, 11-character IFSC and holder name are required.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'bank_name': _bank.text.trim(),
        'account_number': _account.text.trim(),
        'ifsc_code': _ifsc.text.trim().toUpperCase(),
        'branch_name': _branch.text.trim().isEmpty ? null : _branch.text.trim(),
        'account_holder_name': _holder.text.trim(),
        'upi_id': _upi.text.trim().isEmpty ? null : _upi.text.trim(),
        'is_primary': _primary,
        if (widget.item != null) 'is_active': _active,
      };
      if (widget.item == null) {
        await widget.api.post('/masters/banking-profiles', body: body);
      } else {
        await widget.api.put(
          '/masters/banking-profiles/${widget.item!['id']}',
          body: body,
        );
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
    title: Text(widget.item == null ? 'Add bank account' : 'Edit bank account'),
    content: SizedBox(
      width: 650,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _bank,
              decoration: const InputDecoration(labelText: 'Bank name'),
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _account,
              decoration: const InputDecoration(labelText: 'Account number'),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _ifsc,
              textCapitalization: TextCapitalization.characters,
              maxLength: 11,
              decoration: const InputDecoration(
                labelText: 'IFSC',
                counterText: '',
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _branch,
              decoration: const InputDecoration(labelText: 'Branch'),
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _holder,
              decoration: const InputDecoration(labelText: 'Account holder'),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _upi,
              decoration: const InputDecoration(labelText: 'UPI ID'),
            ),
          ),
          FilterChip(
            label: const Text('Primary account'),
            selected: _primary,
            onSelected: (v) => setState(() => _primary = v),
          ),
          if (widget.item != null)
            FilterChip(
              label: const Text('Active'),
              selected: _active,
              onSelected: (v) => setState(() => _active = v),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}

List<Map<String, dynamic>> _rows(dynamic data) {
  if (data is List)
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  if (data is Map) {
    for (final key in const ['items', 'results', 'entries']) {
      if (data[key] is List) {
        return (data[key] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
  }
  return [];
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
