import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/json_report_view.dart';

class GstCenterScreen extends StatefulWidget {
  const GstCenterScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<GstCenterScreen> createState() => _GstCenterScreenState();
}

class _GstCenterScreenState extends State<GstCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  bool _loading = false;
  String? _error;
  dynamic _data;
  dynamic _reconciliation;
  List<Map<String, dynamic>> _filings = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (_tabs.indexIsChanging) return;
        if (_tabs.index < 3) _loadReport();
        if (_tabs.index == 4) _loadFilings();
        setState(() {});
      });
    _loadReport();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _endpoint => switch (_tabs.index) {
    0 => '/reports/gst/gstr1',
    1 => '/reports/gst/gstr2',
    _ => '/reports/gst/gstr3b',
  };

  String get _returnType => switch (_tabs.index) {
    0 => 'GSTR1',
    1 => 'GSTR2',
    _ => 'GSTR3B',
  };

  Future<void> _loadReport() async {
    if (_tabs.index >= 3) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(
        _endpoint,
        query: {'start_date': apiDate(_from), 'end_date': apiDate(_to)},
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _data = null;
        });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload2b() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.upload(
        '/gst/gstr2a/upload',
        result.files.single,
      );
      if (mounted) setState(() => _reconciliation = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFilings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.api.get('/gst/returns');
      if (mounted) {
        setState(
          () => _filings = (d as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String format) async {
    if (_tabs.index >= 3) return;
    final report = _returnType.toLowerCase();
    final ext = format == 'pdf' ? 'pdf' : 'xlsx';
    final path = '/gst/$report/${format == 'pdf' ? 'pdf' : 'export'}';
    try {
      final bytes = await widget.api.download(
        path,
        query: {'start_date': apiDate(_from), 'end_date': apiDate(_to)},
      );
      final filename = '${_returnType}_${apiDate(_from)}_${apiDate(_to)}.$ext';
      final saved = await saveDownloadedFile(bytes, filename);
      if (mounted)
        showMessage(context, saved ? '$filename saved.' : 'Save cancelled.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _newFiling() async {
    String type = 'GSTR1';
    String status = 'DRAFT';
    DateTime from = DateTime(_from.year, _from.month, 1);
    DateTime to = DateTime(_to.year, _to.month + 1, 0);
    final arn = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Track GST return period'),
          content: SizedBox(
            width: 600,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Return'),
                    items: const ['GSTR1', 'GSTR2', 'GSTR3B']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => type = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const ['DRAFT', 'READY', 'FILED', 'REVISED']
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(titleCase(v)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => status = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: InkWell(
                    onTap: () async {
                      final d = await pickDate(context, from);
                      if (d != null) setLocal(() => from = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Period start',
                      ),
                      child: Text(displayDate(from.toIso8601String())),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: InkWell(
                    onTap: () async {
                      final d = await pickDate(context, to);
                      if (d != null) setLocal(() => to = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Period end',
                      ),
                      child: Text(displayDate(to.toIso8601String())),
                    ),
                  ),
                ),
                SizedBox(
                  width: 380,
                  child: TextField(
                    controller: arn,
                    decoration: const InputDecoration(
                      labelText: 'ARN (when available)',
                    ),
                  ),
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
              onPressed: () {
                if (to.isBefore(from)) {
                  showMessage(
                    context,
                    'Period end must be on or after period start.',
                    error: true,
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Create tracking record'),
            ),
          ],
        ),
      ),
    );
    final arnValue = arn.text.trim();
    arn.dispose();
    if (ok != true) return;
    try {
      await widget.api.post(
        '/gst/returns',
        body: {
          'return_type': type,
          'period_start': apiDate(from),
          'period_end': apiDate(to),
          'status': status,
          'arn': arnValue.isEmpty ? null : arnValue,
        },
      );
      if (mounted) showMessage(context, 'GST filing period added.');
      await _loadFilings();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _editFiling(Map<String, dynamic> row) async {
    String status = row['status']?.toString() ?? 'DRAFT';
    final arn = TextEditingController(text: row['arn']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(
            '${row['return_type']} • ${displayDate(row['period_start'])}',
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Filing status'),
                  items: const ['DRAFT', 'READY', 'FILED', 'REVISED']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(titleCase(v)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setLocal(() => status = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: arn,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'ARN'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Marking a period FILED activates backend filing locks that protect GST-affecting documents in that period.',
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
              child: const Text('Update status'),
            ),
          ],
        ),
      ),
    );
    final arnValue = arn.text.trim();
    arn.dispose();
    if (ok != true) return;
    try {
      await widget.api.put(
        '/gst/returns/${row['id']}',
        body: {'status': status, 'arn': arnValue.isEmpty ? null : arnValue},
      );
      if (mounted) showMessage(context, 'GST filing status updated.');
      await _loadFilings();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'GST Center',
    subtitle: 'Returns, GSTN exports, 2B reconciliation, filing status and compliance locks.',
    actions: [
      OutlinedButton.icon(
        onPressed: () => _showComplianceGuide(context),
        icon: const Icon(Icons.info_outline_rounded),
        label: const Text('GST workflow'),
      ),
    ],
    child: Column(
      children: [
        SectionCard(
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'GSTR-1'),
                  Tab(text: 'GSTR-2 / Purchases'),
                  Tab(text: 'GSTR-3B'),
                  Tab(text: 'GSTR-2B Reconciliation'),
                  Tab(text: 'Filing Tracker'),
                ],
              ),
              const SizedBox(height: 14),
              if (_tabs.index < 3)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 210,
                      child: _DateInput(
                        label: 'From',
                        value: _from,
                        onChanged: (d) => setState(() => _from = d),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: _DateInput(
                        label: 'To',
                        value: _to,
                        onChanged: (d) => setState(() => _to = d),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _loading ? null : _loadReport,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Compile report'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () => _export('xlsx'),
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('GSTN Excel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : () => _export('pdf'),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ],
                )
              else if (_tabs.index == 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _upload2b,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload GST portal JSON'),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _newFiling,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Track filing period'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loadFilings,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
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
          ErrorPanel(
            message: _error!,
            onRetry: _tabs.index < 3
                ? _loadReport
                : _tabs.index == 3
                ? null
                : _loadFilings,
          )
        else if (_tabs.index < 3)
          JsonReportView(data: _data)
        else if (_tabs.index == 3)
          _reconciliationView()
        else
          _filingsView(),
      ],
    ),
  );

  Widget _filingsView() {
    if (_filings.isEmpty) {
      return EmptyState(
        icon: Icons.verified_user_outlined,
        title: 'No GST filing periods tracked',
        message: 'Track a GSTR-1, GSTR-2 or GSTR-3B period and mark it ready/filed when the return is submitted.',
        action: FilledButton.icon(
          onPressed: _newFiling,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Track filing period'),
        ),
      );
    }
    return Column(
      children: _filings
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Card(
                child: ListTile(
                  onTap: () => _editFiling(r),
                  leading: CircleAvatar(
                    child: Icon(
                      r['status'] == 'FILED'
                          ? Icons.lock_outline_rounded
                          : Icons.fact_check_outlined,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${r['return_type']} • ${displayDate(r['period_start'])} – ${displayDate(r['period_end'])}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Chip(label: Text('${r['status'] ?? ''}')),
                    ],
                  ),
                  subtitle: Text(
                    r['arn'] == null ? 'ARN not recorded' : 'ARN ${r['arn']}',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _reconciliationView() {
    if (_reconciliation == null) {
      return SectionCard(
        child: EmptyState(
          icon: Icons.compare_arrows_rounded,
          title: 'Reconcile GSTR-2B',
          message: 'Upload the B2B JSON downloaded from the GST portal. The backend compares GSTIN, invoice number, value and tax against purchase bills.',
          action: FilledButton.icon(
            onPressed: _upload2b,
            icon: const Icon(Icons.upload_rounded),
            label: const Text('Select JSON'),
          ),
        ),
      );
    }
    final map = Map<String, dynamic>.from(_reconciliation as Map);
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final stats = [
              ('Matched', map['matched'], AppColors.success),
              ('Partial', map['partially_matched'], AppColors.warning),
              ('Unmatched', map['unmatched'], AppColors.danger),
              ('Suppliers / rows', map['total_suppliers'], AppColors.primary),
            ];
            final cols = c.maxWidth >= 800
                ? 4
                : c.maxWidth >= 450
                ? 2
                : 1;
            const gap = 10.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: stats
                  .map(
                    (s) => SizedBox(
                      width: w,
                      child: MetricCard(
                        label: s.$1,
                        value: '${s.$2 ?? 0}',
                        icon: Icons.receipt_long_outlined,
                        tone: s.$3,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        JsonReportView(data: map),
      ],
    );
  }

  void _showComplianceGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GST workflow'),
        content: const SizedBox(
          width: 560,
          child: Text(
            '1. Keep party GSTIN/state and item HSN/SAC accurate.\n\n'
            '2. Use place of supply on every taxable document.\n\n'
            '3. Review GSTR-1 outward supplies and GSTR-2 inward books.\n\n'
            '4. Upload GSTR-2B JSON and resolve partial/unmatched ITC exceptions.\n\n'
            '5. Review GSTR-3B, export GSTN workbooks/PDFs and track the filing period.\n\n'
            '6. Marking a period FILED engages backend mutation locks for affected GST documents.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
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
