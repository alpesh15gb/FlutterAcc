import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/json_report_view.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _from = DateTime(
    DateTime.now().month >= 4 ? DateTime.now().year : DateTime.now().year - 1,
    4,
    1,
  );
  DateTime _to = DateTime.now();
  String _selected = 'profit-loss';
  bool _loading = false;
  bool _exporting = false;
  String? _error;
  dynamic _data;
  List<Map<String, dynamic>> _contacts = [];
  String? _contactId;

  static const _reports = <_ReportDef>[
    _ReportDef(
      'profit-loss',
      'Profit & Loss',
      Icons.trending_up_rounded,
      'Revenue, expenses and net profit',
      '/accounting/profit-loss',
      _ReportQuery.range,
      exportBase: '/reports/profit-loss',
    ),
    _ReportDef(
      'balance-sheet',
      'Balance Sheet',
      Icons.account_balance_outlined,
      'Assets, liabilities and equity',
      '/reports/balance-sheet',
      _ReportQuery.asOf,
      exportBase: '/reports/balance-sheet',
    ),
    _ReportDef(
      'trial-balance',
      'Trial Balance',
      Icons.balance_rounded,
      'Opening, movement and closing balances',
      '/reports/trial-balance',
      _ReportQuery.asOf,
      exportBase: '/reports/trial-balance',
    ),
    _ReportDef(
      'cash-flow',
      'Cash Flow',
      Icons.waterfall_chart_rounded,
      'Operating, investing and financing cash movement',
      '/reports/cash-flow',
      _ReportQuery.range,
      exportBase: '/reports/cash-flow',
    ),
    _ReportDef(
      'party-statement',
      'Party Statement',
      Icons.people_alt_outlined,
      'Customer/vendor ledger with running balance and outstanding summary',
      '/reports/party-statement',
      _ReportQuery.party,
      exportBase: '/reports/party-statement',
    ),
    _ReportDef(
      'sales-analytics',
      'Sales Analytics',
      Icons.insights_rounded,
      'Sales totals and top customers',
      '/reports/analytics/sales',
      _ReportQuery.range,
    ),
    _ReportDef(
      'purchase-analytics',
      'Purchase Analytics',
      Icons.shopping_cart_outlined,
      'Purchase totals and top vendors',
      '/reports/analytics/purchases',
      _ReportQuery.range,
    ),
    _ReportDef(
      'ar-aging',
      'Receivable Aging',
      Icons.schedule_rounded,
      'Customer outstanding by age bucket',
      '/reports/aging/receivables',
      _ReportQuery.asOf,
      exportBase: '/reports/aging/receivables',
    ),
    _ReportDef(
      'ap-aging',
      'Payable Aging',
      Icons.timelapse_rounded,
      'Vendor outstanding by age bucket',
      '/reports/aging/payables',
      _ReportQuery.asOf,
      exportBase: '/reports/aging/payables',
    ),
    _ReportDef(
      'outstanding-ar',
      'Outstanding Receivables',
      Icons.call_received_rounded,
      'Unpaid and partly paid sales invoices',
      '/reports/outstanding/receivables',
      _ReportQuery.asOf,
      exportBase: '/reports/outstanding/receivables',
    ),
    _ReportDef(
      'outstanding-ap',
      'Outstanding Payables',
      Icons.call_made_rounded,
      'Unpaid and partly paid vendor bills',
      '/reports/outstanding/payables',
      _ReportQuery.asOf,
      exportBase: '/reports/outstanding/payables',
    ),
    _ReportDef(
      'day-book',
      'Day Book',
      Icons.menu_book_outlined,
      'Daily transaction activity across accounting vouchers',
      '/reports/day-book',
      _ReportQuery.range,
    ),
    _ReportDef(
      'stock-register',
      'Stock Register',
      Icons.inventory_outlined,
      'Stock movement and valuation report',
      '/reports/stock-register',
      _ReportQuery.range,
    ),
    _ReportDef(
      'tds',
      'TDS Report',
      Icons.percent_rounded,
      'Tax deducted at source',
      '/reports/tds',
      _ReportQuery.range,
    ),
    _ReportDef(
      'tcs',
      'TCS Report',
      Icons.receipt_long_outlined,
      'Tax collected at source',
      '/reports/tcs',
      _ReportQuery.range,
    ),
  ];

  _ReportDef get selected => _reports.firstWhere((r) => r.id == _selected);

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _load();
  }

  Future<void> _loadContacts() async {
    try {
      final data =
          await widget.api.get('/masters/contacts', query: {'limit': 100});
      final contacts = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _contactId ??=
            contacts.isEmpty ? null : contacts.first['id']?.toString();
      });
    } catch (_) {
      // Party selection remains disabled until contacts can be loaded.
    }
  }

  Map<String, dynamic> _queryFor(_ReportDef report) {
    switch (report.query) {
      case _ReportQuery.range:
        return {'start_date': apiDate(_from), 'end_date': apiDate(_to)};
      case _ReportQuery.asOf:
        return {'as_of_date': apiDate(_to)};
      case _ReportQuery.party:
        return {
          if (_contactId != null) 'contact_id': _contactId,
          'start_date': apiDate(_from),
          'end_date': apiDate(_to),
        };
    }
  }

  Future<void> _load() async {
    final report = selected;
    if (report.query == _ReportQuery.party && _contactId == null) {
      if (mounted) {
        setState(() {
          _data = null;
          _error = 'Create or load a party before running a party statement.';
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await widget.api.get(report.endpoint, query: _queryFor(report));
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _data = null;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String format) async {
    final report = selected;
    if (report.exportBase == null || _exporting) return;
    if (report.query == _ReportQuery.party && _contactId == null) {
      showMessage(context, 'Select a party first.', error: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final bytes = await widget.api.download(
        '${report.exportBase}/$format',
        query: _queryFor(report),
      );
      final ext = format == 'excel' ? 'xlsx' : 'pdf';
      final safe = report.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final saved = await saveDownloadedFile(
        bytes,
        '${safe}_${apiDate(_to)}.$ext',
      );
      if (mounted && saved)
        showMessage(context, '${report.title} $format saved.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'Reports',
        subtitle: 'Financial statements, aging, analytics and statutory books.',
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh report',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1050;
          final nav = _reportNav();
          final body = _reportBody();
          if (!wide)
            return Column(children: [nav, const SizedBox(height: 14), body]);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 285, child: nav),
              const SizedBox(width: 14),
              Expanded(child: body),
            ],
          );
        }),
      );

  Widget _reportNav() => SectionCard(
        title: 'Report library',
        child: Column(
          children: _reports
              .map(
                (report) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                  selected: report.id == _selected,
                  selectedTileColor: AppColors.primary.withOpacity(.07),
                  leading: Icon(report.icon, size: 20),
                  title: Text(
                    report.title,
                    style: TextStyle(
                      fontWeight: report.id == _selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selected = report.id;
                      _data = null;
                      _error = null;
                    });
                    _load();
                  },
                ),
              )
              .toList(),
        ),
      );

  Widget _reportBody() => Column(
        children: [
          SectionCard(
            title: selected.title,
            trailing: Wrap(
              spacing: 6,
              children: [
                if (selected.exportBase != null)
                  PopupMenuButton<String>(
                    enabled: !_exporting,
                    tooltip: 'Export report',
                    onSelected: _export,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                      PopupMenuItem(
                          value: 'excel', child: Text('Export Excel')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_exporting)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.download_outlined, size: 19),
                          const SizedBox(width: 6),
                          const Text('Export'),
                        ],
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Run'),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selected.subtitle,
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (selected.query == _ReportQuery.party)
                      SizedBox(
                        width: 320,
                        child: DropdownButtonFormField<String>(
                          value: _contacts
                                  .any((c) => c['id']?.toString() == _contactId)
                              ? _contactId
                              : null,
                          decoration: const InputDecoration(labelText: 'Party'),
                          items: _contacts
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['id']?.toString(),
                                  child: Text(c['name']?.toString() ?? 'Party'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _contactId = value),
                        ),
                      ),
                    if (selected.query == _ReportQuery.range ||
                        selected.query == _ReportQuery.party)
                      SizedBox(
                        width: 210,
                        child: _DateInput(
                          label: 'From',
                          value: _from,
                          onChanged: (v) => setState(() => _from = v),
                        ),
                      ),
                    SizedBox(
                      width: 210,
                      child: _DateInput(
                        label: selected.query == _ReportQuery.asOf
                            ? 'As of'
                            : 'To',
                        value: _to,
                        onChanged: (v) => setState(() => _to = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const SectionCard(
              child: Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_error != null)
            ErrorPanel(message: _error!, onRetry: _load)
          else
            JsonReportView(data: _data),
        ],
      );
}

enum _ReportQuery { range, asOf, party }

class _ReportDef {
  const _ReportDef(
    this.id,
    this.title,
    this.icon,
    this.subtitle,
    this.endpoint,
    this.query, {
    this.exportBase,
  });

  final String id;
  final String title;
  final String subtitle;
  final String endpoint;
  final IconData icon;
  final _ReportQuery query;
  final String? exportBase;
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final d = await pickDate(context, value);
          if (d != null) onChanged(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Text(displayDate(value.toIso8601String())),
        ),
      );
}
