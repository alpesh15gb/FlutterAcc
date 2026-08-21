import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/json_report_view.dart';

class ImportToolsScreen extends StatefulWidget {
  const ImportToolsScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<ImportToolsScreen> createState() => _ImportToolsScreenState();
}

class _ImportToolsScreenState extends State<ImportToolsScreen> {
  bool _loading = false;
  String? _error;
  dynamic _result;
  String? _resultTitle;
  PlatformFile? _validatedCsv;
  dynamic _csvValidation;

  Future<PlatformFile?> _pick(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: true,
    );
    return result?.files.single;
  }

  Future<void> _run(String title, Future<dynamic> Function() task) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _resultTitle = title;
    });
    try {
      final data = await task();
      if (mounted) setState(() => _result = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _vyapar() async {
    final file = await _pick(['vyb']);
    if (file == null) return;
    await _run(
      'Vyapar migration result',
      () => widget.api.upload('/import/vyapar', file),
    );
  }

  Future<void> _tally() async {
    final file = await _pick(['xml']);
    if (file == null) return;
    await _run(
      'Tally import result',
      () => widget.api.upload('/tally/import', file),
    );
  }

  Future<void> _csvDryRun() async {
    final file = await _pick(['zip', 'csv']);
    if (file == null) return;
    _validatedCsv = file;
    await _run('CSV validation report', () async {
      final data = await widget.api.upload(
        '/import/csv',
        file,
        query: {'dry_run': 'true'},
      );
      _csvValidation = data;
      return data;
    });
  }

  Future<void> _csvCommit() async {
    final file = _validatedCsv;
    if (file == null) {
      showMessage(context, 'Run CSV validation first.', error: true);
      return;
    }
    final valid = _csvValidation is Map && _csvValidation['valid'] == true;
    if (!valid) {
      showMessage(
        context,
        'The dry-run report is not valid. Fix migration errors before committing.',
        error: true,
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit migration?'),
        content: const Text(
          'The backend will import the validated CSV bundle in one transaction and post accounting entries. Continue only after reviewing the dry-run totals and warnings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Commit import'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _run(
      'CSV import result',
      () => widget.api.upload('/import/csv', file, query: {'dry_run': 'false'}),
    );
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Import & Migration',
    subtitle: 'Move existing Indian accounting data into ApexBooks with validation-first workflows.',
    child: Column(
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final cards = [
              _ToolCardData(
                'Vyapar backup',
                'Import a native .vyb backup including parties, items, invoices, bills, expenses and opening data.',
                Icons.move_to_inbox_rounded,
                _vyapar,
                'Select .vyb',
              ),
              _ToolCardData(
                'Tally XML',
                'Import Tally ledgers, stock items and supported vouchers from XML.',
                Icons.code_rounded,
                _tally,
                'Select XML',
              ),
              _ToolCardData(
                'CSV migration',
                'Validate the exact converter bundle first; commit only after the dry-run balances.',
                Icons.table_chart_outlined,
                _csvDryRun,
                'Validate ZIP / CSV',
              ),
              _ToolCardData(
                'GSTR-2B reconciliation',
                'Use GST Center to upload GST portal JSON and match ITC against purchase bills.',
                Icons.compare_arrows_rounded,
                () {
                  showMessage(
                    context,
                    'Open GST Center → GSTR-2B Reconciliation from the sidebar.',
                  );
                },
                'Open guidance',
              ),
            ];
            final cols = c.maxWidth >= 1050
                ? 4
                : c.maxWidth >= 650
                ? 2
                : 1;
            final gap = 12.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((d) => SizedBox(width: w, child: _toolCard(d)))
                  .toList(),
            );
          },
        ),
        if (_validatedCsv != null) ...[
          const SizedBox(height: 14),
          SectionCard(
            title: 'CSV migration checkpoint',
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Validated file selected: ${_validatedCsv!.name}. Commit remains disabled unless the dry-run returned valid=true.',
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _csvCommit,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Commit validated import'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (_loading)
          const SectionCard(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_error != null)
          ErrorPanel(message: _error!)
        else if (_result != null)
          SectionCard(
            title: _resultTitle,
            child: JsonReportView(data: _result),
          )
        else
          const SectionCard(
            child: EmptyState(
              icon: Icons.upload_file_outlined,
              title: 'Choose a migration source',
              message: 'Imports are executed by the FastAPI backend so posting, stock and GST integrity stay consistent.',
            ),
          ),
      ],
    ),
  );

  Widget _toolCard(_ToolCardData d) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(.08),
            child: Icon(d.icon, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            d.title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            d.subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : d.onTap,
              child: Text(d.action),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ToolCardData {
  const _ToolCardData(
    this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.action,
  );
  final String title, subtitle, action;
  final IconData icon;
  final VoidCallback onTap;
}
