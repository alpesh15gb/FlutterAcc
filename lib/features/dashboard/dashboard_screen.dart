import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key,
      required this.api,
      required this.onNavigate,
      required this.companyName});
  final ApiClient api;
  final ValueChanged<String> onNavigate;
  final String companyName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _kpis = {};
  Map<String, dynamic> _gst = {};
  List<Map<String, dynamic>> _revenue = [];
  List<Map<String, dynamic>> _expenses = [];
  Map<String, dynamic> _overdue = {};

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
      final results = await Future.wait([
        widget.api.get('/dashboard/kpis'),
        widget.api.get('/dashboard/metrics'),
        widget.api.get('/dashboard/revenue-trend'),
        widget.api.get('/dashboard/expense-trend'),
        widget.api.get('/dashboard/overdue-alerts'),
      ]);
      if (!mounted) return;
      setState(() {
        _kpis = Map<String, dynamic>.from(results[0] as Map);
        _gst = Map<String, dynamic>.from(results[1] as Map);
        _revenue = (results[2] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _expenses = (results[3] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _overdue = Map<String, dynamic>.from(results[4] as Map);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Dashboard',
      subtitle: '${widget.companyName} • current financial year snapshot',
      actions: [
        IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded))
      ],
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? ErrorPanel(message: _error!, onRetry: _load)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _quickActions(),
                  const SizedBox(height: 14),
                  _metrics(),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, c) {
                    final wide = c.maxWidth >= 980;
                    final trend = SectionCard(
                        title: 'Sales vs expenses',
                        child: _TrendChart(
                            revenue: _revenue, expenses: _expenses));
                    final gst = _gstCard();
                    if (!wide)
                      return Column(
                          children: [trend, const SizedBox(height: 14), gst]);
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: trend),
                          const SizedBox(width: 14),
                          Expanded(child: gst)
                        ]);
                  }),
                  const SizedBox(height: 14),
                  _overdueCard(),
                ]),
    );
  }

  Widget _quickActions() => SectionCard(
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
              onPressed: () => widget.onNavigate('invoices'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New invoice')),
          OutlinedButton.icon(
              onPressed: () => widget.onNavigate('payments'),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record receipt')),
          OutlinedButton.icon(
              onPressed: () => widget.onNavigate('bills'),
              icon: const Icon(Icons.receipt_outlined),
              label: const Text('Purchase bill')),
          OutlinedButton.icon(
              onPressed: () => widget.onNavigate('contacts'),
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add party')),
          OutlinedButton.icon(
              onPressed: () => widget.onNavigate('gst'),
              icon: const Icon(Icons.verified_outlined),
              label: const Text('GST Center')),
        ]),
      );

  Widget _metrics() {
    final cards = [
      (
        'Sales',
        _kpis['total_invoiced'],
        Icons.receipt_long_outlined,
        AppColors.primary
      ),
      (
        'Collected',
        _kpis['total_collected'],
        Icons.account_balance_wallet_outlined,
        AppColors.success
      ),
      (
        'Outstanding',
        _kpis['outstanding'],
        Icons.schedule_rounded,
        AppColors.warning
      ),
      (
        'Overdue',
        _kpis['overdue'],
        Icons.error_outline_rounded,
        AppColors.danger
      ),
      (
        'Expenses',
        _kpis['total_expenses'],
        Icons.payments_outlined,
        const Color(0xFF7A5AF8)
      ),
      (
        'Net profit',
        _kpis['net_profit'],
        Icons.trending_up_rounded,
        AppColors.success
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth;
      final columns = width >= 1200
          ? 6
          : width >= 800
              ? 3
              : width >= 520
                  ? 2
                  : 1;
      final spacing = 12.0;
      final cardWidth = (width - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: cards
            .map((e) => SizedBox(
                width: cardWidth,
                child: MetricCard(
                    label: e.$1,
                    value: shortMoney(e.$2),
                    icon: e.$3,
                    tone: e.$4)))
            .toList(),
      );
    });
  }

  Widget _gstCard() {
    final cgst = num.tryParse('${_gst['cgst_total'] ?? 0}') ?? 0;
    final sgst = num.tryParse('${_gst['sgst_total'] ?? 0}') ?? 0;
    final igst = num.tryParse('${_gst['igst_total'] ?? 0}') ?? 0;
    final cess = num.tryParse('${_gst['cess_total'] ?? 0}') ?? 0;
    return SectionCard(
      title: 'Output GST snapshot',
      child: Column(children: [
        _amountRow('CGST', cgst),
        _amountRow('SGST / UTGST', sgst),
        _amountRow('IGST', igst),
        _amountRow('Cess', cess),
        const Divider(height: 22),
        _amountRow('Total tax', cgst + sgst + igst + cess, bold: true),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: () => widget.onNavigate('gst'),
                child: const Text('Open GST Center'))),
      ]),
    );
  }

  Widget _amountRow(String label, Object amount, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: bold ? null : AppColors.muted))),
          Text(money(amount),
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w700))
        ]),
      );

  Widget _overdueCard() {
    final alerts = ((_overdue['alerts'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return SectionCard(
      title: 'Collections requiring attention',
      trailing: Text('${alerts.length} overdue',
          style: const TextStyle(
              color: AppColors.danger, fontWeight: FontWeight.w700)),
      child: alerts.isEmpty
          ? const EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No overdue invoices',
              message:
                  'There are no overdue receivables in the dashboard alert window.')
          : Column(
              children: alerts
                  .take(8)
                  .map((a) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                            backgroundColor: AppColors.danger.withOpacity(.08),
                            child: const Icon(Icons.schedule_rounded,
                                color: AppColors.danger)),
                        title: Text(
                            '${a['contact_name'] ?? 'Customer'} • ${a['invoice_number'] ?? ''}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${a['days_overdue'] ?? 0} days overdue • due ${displayDate(a['due_date'])}'),
                        trailing: Text(money(a['balance']),
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ))
                  .toList()),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.revenue, required this.expenses});
  final List<Map<String, dynamic>> revenue;
  final List<Map<String, dynamic>> expenses;

  @override
  Widget build(BuildContext context) {
    final keys = <String>{};
    for (final row in [...revenue, ...expenses]) {
      keys.add('${row['year']}-${row['month']}');
    }
    final ordered = keys.toList()..sort();
    final shown =
        ordered.length > 8 ? ordered.sublist(ordered.length - 8) : ordered;
    if (shown.isEmpty)
      return const EmptyState(
          icon: Icons.show_chart_rounded,
          title: 'No trend data',
          message: 'Posted sales and expenses will create a monthly trend.');
    double val(List<Map<String, dynamic>> source, String key) {
      final parts = key.split('-');
      final matches = source.where(
          (r) => '${r['year']}' == parts[0] && '${r['month']}' == parts[1]);
      return matches.isEmpty
          ? 0
          : double.tryParse('${matches.first['total']}') ?? 0;
    }

    final maxValue = shown.fold<double>(1, (max, key) {
      final v = [val(revenue, key), val(expenses, key)]
          .reduce((a, b) => a > b ? a : b);
      return v > max ? v : max;
    });
    return SizedBox(
      height: 245,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: shown.map((key) {
          final r = val(revenue, key);
          final e = val(expenses, key);
          final month = int.tryParse(key.split('-')[1]) ?? 1;
          const labels = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec'
          ];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: (r / maxValue).clamp(.02, 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(.75),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: (e / maxValue).clamp(.02, 1),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(.65),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(5)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(labels[(month - 1).clamp(0, 11)],
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
