import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/json_report_view.dart';

class FinancialYearsScreen extends StatefulWidget {
  const FinancialYearsScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<FinancialYearsScreen> createState() => _FinancialYearsScreenState();
}

class _FinancialYearsScreenState extends State<FinancialYearsScreen> {
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _periods = [];
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
      final years = await widget.api.get('/financial-years');
      final periods = await widget.api.get('/accounting/periods');
      _items = (years as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _periods = (periods as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final now = DateTime.now();
    var start = DateTime(now.month >= 4 ? now.year : now.year - 1, 4, 1);
    var end = DateTime(start.year + 1, 3, 31);
    final name = TextEditingController(
      text: 'FY ${start.year}-${(end.year % 100).toString().padLeft(2, '0')}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create financial year'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text(displayDate(start.toIso8601String())),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final d = await pickDate(context, start);
                    if (d != null) setLocal(() => start = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End date'),
                  subtitle: Text(displayDate(end.toIso8601String())),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final d = await pickDate(context, end);
                    if (d != null) setLocal(() => end = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty || end.isBefore(start)) {
                  showMessage(
                    context,
                    'Enter a valid name and date range.',
                    error: true,
                  );
                  return;
                }
                try {
                  await widget.api.post(
                    '/financial-years',
                    body: {
                      'name': name.text.trim(),
                      'start_date': apiDate(start),
                      'end_date': apiDate(end),
                    },
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted)
                    showMessage(context, e.toString(), error: true);
                }
              },
              child: const Text('Create & switch'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (ok == true) {
      showMessage(context, 'Financial year created and selected.');
      _load();
    }
  }

  Future<void> _switch(Map<String, dynamic> fy) async {
    try {
      await widget.api.post(
        '/financial-years/switch',
        body: {'financial_year_id': fy['id']},
      );
      if (mounted) {
        showMessage(context, 'Switched to ${fy['name']}.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _yearEnd(Map<String, dynamic> fy) async {
    try {
      final report = await widget.api.get(
        '/financial-years/${fy['id']}/dashboard',
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Year-end • ${fy['name']}'),
          content: SizedBox(
            width: 760,
            height: 560,
            child: SingleChildScrollView(child: JsonReportView(data: report)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (report is Map && report['closing_allowed'] == true)
              FilledButton(
                onPressed: () async {
                  try {
                    await widget.api.post('/financial-years/${fy['id']}/close');
                    if (context.mounted) {
                      Navigator.pop(context);
                      showMessage(context, 'Financial year closed.');
                      _load();
                    }
                  } catch (e) {
                    if (context.mounted)
                      showMessage(context, e.toString(), error: true);
                  }
                },
                child: const Text('Close financial year'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _reopen(Map<String, dynamic> fy) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reopen ${fy['name']}?'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reopening reverses year-end roll-forward (opening balances and inventory carry-forward) and requires a reason.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (reason.text.trim().isEmpty) {
                showMessage(context, 'A reason is required.', error: true);
                return;
              }
              try {
                await widget.api.post(
                  '/financial-years/${fy['id']}/reopen',
                  query: {'reason': reason.text.trim()},
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                if (context.mounted)
                  showMessage(context, e.toString(), error: true);
              }
            },
            child: const Text('Reopen'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (ok == true) {
      showMessage(context, 'Financial year reopened.');
      _load();
    }
  }

  Future<void> _lockPeriod({
    required bool lock,
    Map<String, dynamic>? existing,
  }) async {
    var date = existing != null
        ? (DateTime.tryParse('${existing['start_date']}') ?? DateTime.now())
        : DateTime(DateTime.now().year, DateTime.now().month, 1);
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            lock ? 'Lock accounting period' : 'Unlock accounting period',
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Period month'),
                  subtitle: Text(
                    '${date.year}-${date.month.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final d = await pickDate(context, date);
                    if (d != null)
                      setLocal(() => date = DateTime(d.year, d.month, 1));
                  },
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api.post(
                    '/accounting/periods/${lock ? 'lock' : 'unlock'}',
                    body: {
                      'period_date': apiDate(date),
                      'note': note.text.trim().isEmpty
                          ? null
                          : note.text.trim(),
                    },
                  );
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted)
                    showMessage(context, e.toString(), error: true);
                }
              },
              child: Text(lock ? 'Lock' : 'Unlock'),
            ),
          ],
        ),
      ),
    );
    note.dispose();
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Financial Years',
    subtitle: 'Switch books, inspect close readiness, reopen closed years and lock monthly posting periods.',
    actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New financial year'),
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
              if (_items.isEmpty)
                const EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'No financial years',
                  message:
                      'Create an April–March financial year to begin posting.',
                )
              else
                ..._items.map((fy) {
                  final current = fy['is_current'] == true;
                  final status = '${fy['status'] ?? ''}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  (current
                                          ? AppColors.success
                                          : AppColors.primary)
                                      .withOpacity(.09),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.calendar_month_outlined,
                              color: current
                                  ? AppColors.success
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${fy['name'] ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (current) ...[
                                      const SizedBox(width: 8),
                                      const Chip(label: Text('Current')),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${displayDate(fy['start_date'])} – ${displayDate(fy['end_date'])} • ${fy['transaction_count'] ?? 0} transactions',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Chip(label: Text(status)),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'switch') _switch(fy);
                              if (v == 'yearEnd') _yearEnd(fy);
                              if (v == 'reopen') _reopen(fy);
                            },
                            itemBuilder: (_) => [
                              if (!current &&
                                  !['LOCKED', 'ARCHIVED'].contains(status))
                                const PopupMenuItem(
                                  value: 'switch',
                                  child: Text('Switch to this year'),
                                ),
                              const PopupMenuItem(
                                value: 'yearEnd',
                                child: Text('Year-end dashboard'),
                              ),
                              if (['LOCKED', 'ARCHIVED'].contains(status))
                                const PopupMenuItem(
                                  value: 'reopen',
                                  child: Text('Reopen year'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              SectionCard(
                title: 'Accounting period locks',
                trailing: TextButton.icon(
                  onPressed: () => _lockPeriod(lock: true),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock period'),
                ),
                child: _periods.isEmpty
                    ? const Text(
                        'No monthly periods have been locked yet. Locking a month blocks posting into that period.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    : Column(
                        children: _periods
                            .map(
                              (p) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${p['period_name'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${displayDate(p['start_date'])} – ${displayDate(p['end_date'])}',
                                ),
                                trailing: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  children: [
                                    Chip(
                                      label: Text(
                                        p['is_closed'] == true
                                            ? 'Locked'
                                            : 'Open',
                                      ),
                                    ),
                                    if (p['is_closed'] == true)
                                      TextButton(
                                        onPressed: () => _lockPeriod(
                                          lock: false,
                                          existing: p,
                                        ),
                                        child: const Text('Unlock'),
                                      )
                                    else
                                      TextButton(
                                        onPressed: () => _lockPeriod(
                                          lock: true,
                                          existing: p,
                                        ),
                                        child: const Text('Lock'),
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
  );
}
