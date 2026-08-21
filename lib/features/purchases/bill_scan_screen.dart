import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class BillScanScreen extends StatefulWidget {
  const BillScanScreen({super.key, required this.api});
  final ApiClient api;

  @override
  State<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends State<BillScanScreen> {
  final _vendor = TextEditingController();
  final _gstin = TextEditingController();
  final _address = TextEditingController();
  final _stateCode = TextEditingController();
  final _billNumber = TextEditingController();
  final _pos = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now();
  String? _vendorId;
  List<_ScannedLine> _lines = [];
  List<String> _warnings = [];
  bool _scanning = false;
  bool _saving = false;
  String? _progress;
  double? _confidence;

  @override
  void dispose() {
    for (final c in [
      _vendor,
      _gstin,
      _address,
      _stateCode,
      _billNumber,
      _pos,
      _reference,
      _notes
    ]) {
      c.dispose();
    }
    for (final line in _lines) line.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'tiff',
        'bmp',
        'webp',
        'pdf'
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _scanning = true;
      _progress = 'Uploading bill…';
    });
    try {
      final response = await widget.api.upload(
        '/bills/scan-preview',
        result.files.single,
        fields: const {'confidence': '0.30'},
      );
      dynamic preview = response;
      if (response is Map &&
          response['job_id'] != null &&
          response['status']?.toString() != 'done' &&
          response['vendor'] == null) {
        final jobId = response['job_id'].toString();
        preview = await _poll(jobId);
      }
      if (preview is! Map)
        throw ApiException('The scanner returned an invalid preview.');
      _applyPreview(Map<String, dynamic>.from(preview));
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted)
        setState(() {
          _scanning = false;
          _progress = null;
        });
    }
  }

  Future<dynamic> _poll(String jobId) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      if (!mounted) throw ApiException('Scan cancelled.');
      setState(() => _progress = 'Reading bill… ${attempt + 1}');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      try {
        final response = await widget.api.get('/bills/scan-status/$jobId');
        if (response is Map) {
          if (response['vendor'] != null || response['line_items'] != null)
            return response;
          final status = response['status']?.toString().toLowerCase();
          if (status == 'failed')
            throw ApiException(
                response['error']?.toString() ?? 'Bill scan failed.');
          final progress = response['progress']?.toString();
          if (progress != null && progress.isNotEmpty && mounted)
            setState(() => _progress = progress);
        }
      } on ApiException catch (e) {
        if (e.statusCode == 404 && attempt < 3) continue;
        rethrow;
      }
    }
    throw ApiException(
        'The OCR scan did not finish. Try again or enter the bill manually.');
  }

  void _applyPreview(Map<String, dynamic> data) {
    final vendor = data['vendor'] is Map
        ? Map<String, dynamic>.from(data['vendor'] as Map)
        : <String, dynamic>{};
    _vendorId = vendor['id']?.toString();
    _vendor.text = vendor['name']?.toString() ?? '';
    _gstin.text = vendor['gstin']?.toString() ?? '';
    _address.text = vendor['address']?.toString() ?? '';
    _stateCode.text = vendor['state_code']?.toString() ?? '';
    _billNumber.text = data['bill_number']?.toString() ?? '';
    _issueDate = DateTime.tryParse(data['bill_date']?.toString() ?? '') ??
        DateTime.now();
    _dueDate =
        DateTime.tryParse(data['due_date']?.toString() ?? '') ?? _issueDate;
    _pos.text = _stateCode.text.length == 2 ? _stateCode.text : '';
    _confidence = double.tryParse('${data['confidence'] ?? ''}');
    _warnings =
        ((data['warnings'] as List?) ?? []).map((e) => e.toString()).toList();
    for (final line in _lines) line.dispose();
    _lines = ((data['line_items'] as List?) ?? [])
        .whereType<Map>()
        .map((raw) => _ScannedLine.fromMap(Map<String, dynamic>.from(raw)))
        .toList();
    if (_lines.isEmpty) _lines.add(_ScannedLine());
    setState(() {});
  }

  String? _validate() {
    if (_vendor.text.trim().isEmpty) return 'Vendor name is required.';
    if (_pos.text.trim().length != 2 || int.tryParse(_pos.text.trim()) == null)
      return 'Place of supply must be a two-digit GST state code.';
    if (_dueDate.isBefore(_issueDate))
      return 'Due date cannot be before bill date.';
    if (_lines.isEmpty) return 'Add at least one bill line.';
    for (var i = 0; i < _lines.length; i++) {
      final line = _lines[i];
      if (line.name.text.trim().isEmpty)
        return 'Line ${i + 1}: item name is required.';
      if ((double.tryParse(line.quantity.text) ?? 0) <= 0)
        return 'Line ${i + 1}: quantity must be greater than zero.';
      if ((double.tryParse(line.rate.text) ?? -1) < 0)
        return 'Line ${i + 1}: rate cannot be negative.';
      final hsn = line.hsn.text.trim();
      if (hsn.length < 4 || int.tryParse(hsn) == null)
        return 'Line ${i + 1}: enter a valid HSN/SAC.';
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      showMessage(context, error, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = {
        'vendor': {
          if (_vendorId != null) 'contact_id': _vendorId,
          'name': _vendor.text.trim(),
          'gstin': _gstin.text.trim().isEmpty
              ? null
              : _gstin.text.trim().toUpperCase(),
          'address': _address.text.trim(),
          'state_code': _stateCode.text.trim(),
        },
        'bill': {
          'bill_number': _billNumber.text.trim(),
          'issue_date': apiDate(_issueDate),
          'due_date': apiDate(_dueDate),
          'pos_state_code': _pos.text.trim(),
          'reference_number':
              _reference.text.trim().isEmpty ? null : _reference.text.trim(),
          'notes': _notes.text.trim(),
        },
        'line_items': _lines.map((line) => line.payload).toList(),
      };
      final result = await widget.api.post('/bills/scan-save', body: payload);
      if (mounted) {
        final number = result is Map ? result['bill_number']?.toString() : null;
        showMessage(
            context,
            number == null
                ? 'Draft bill created.'
                : 'Draft bill $number created.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Scan purchase bill'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                  onPressed: _saving || _scanning ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save draft')),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(children: [
                SectionCard(
                  title: 'OCR capture',
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                            'Upload a vendor bill image or PDF. OCR suggestions stay editable and are saved only as a draft for review.',
                            style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _scanning ? null : _pickAndScan,
                          icon: _scanning
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.document_scanner_outlined),
                          label: Text(_scanning
                              ? (_progress ?? 'Scanning…')
                              : 'Choose bill image / PDF'),
                        ),
                        if (_confidence != null) ...[
                          const SizedBox(height: 10),
                          Text(
                              'OCR confidence ${(100 * _confidence!).toStringAsFixed(0)}%',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                        if (_warnings.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final warning in _warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        size: 18, color: AppColors.warning),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(warning)),
                                  ]),
                            ),
                        ],
                      ]),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Vendor & bill',
                  child: Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(
                        width: 320,
                        child: TextField(
                            controller: _vendor,
                            decoration: const InputDecoration(
                                labelText: 'Vendor name'))),
                    SizedBox(
                        width: 220,
                        child: TextField(
                            controller: _gstin,
                            maxLength: 15,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                                labelText: 'GSTIN', counterText: ''))),
                    SizedBox(
                        width: 110,
                        child: TextField(
                            controller: _stateCode,
                            maxLength: 2,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Vendor state', counterText: ''))),
                    SizedBox(
                        width: 220,
                        child: TextField(
                            controller: _billNumber,
                            decoration: const InputDecoration(
                                labelText: 'Supplier bill number'))),
                    SizedBox(
                        width: 210,
                        child: _ScanDateField(
                            label: 'Bill date',
                            value: _issueDate,
                            onChanged: (v) => setState(() => _issueDate = v))),
                    SizedBox(
                        width: 210,
                        child: _ScanDateField(
                            label: 'Due date',
                            value: _dueDate,
                            onChanged: (v) => setState(() => _dueDate = v))),
                    SizedBox(
                        width: 140,
                        child: TextField(
                            controller: _pos,
                            maxLength: 2,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Place of supply',
                                counterText: ''))),
                    SizedBox(
                        width: 260,
                        child: TextField(
                            controller: _reference,
                            decoration:
                                const InputDecoration(labelText: 'Reference'))),
                    SizedBox(
                        width: 720,
                        child: TextField(
                            controller: _address,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Vendor address'))),
                    SizedBox(
                        width: 720,
                        child: TextField(
                            controller: _notes,
                            maxLines: 2,
                            decoration:
                                const InputDecoration(labelText: 'Notes'))),
                  ]),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Scanned items',
                  trailing: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_ScannedLine())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add line'),
                  ),
                  child: Column(children: [
                    for (var i = 0; i < _lines.length; i++) ...[
                      _lineEditor(i, _lines[i]),
                      if (i != _lines.length - 1) const Divider(height: 24),
                    ],
                  ]),
                ),
                const SizedBox(height: 18),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: _saving || _scanning ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label:
                            Text(_saving ? 'Saving…' : 'Create draft bill'))),
              ]),
            ),
          ),
        ),
      );

  Widget _lineEditor(int index, _ScannedLine line) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Line ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          if (_lines.length > 1)
            IconButton(
              onPressed: () => setState(() {
                final removed = _lines.removeAt(index);
                removed.dispose();
              }),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
        ]),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: 310,
              child: TextField(
                  controller: line.name,
                  decoration: InputDecoration(
                      labelText: line.productId == null
                          ? 'Item name (new if saved)'
                          : 'Item name'))),
          SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                  value: line.productType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'GOODS', child: Text('Goods')),
                    DropdownMenuItem(value: 'SERVICE', child: Text('Service'))
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => line.productType = v);
                  })),
          SizedBox(
              width: 100,
              child: TextField(
                  controller: line.quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qty'))),
          SizedBox(
              width: 135,
              child: TextField(
                  controller: line.rate,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rate'))),
          SizedBox(
              width: 130,
              child: TextField(
                  controller: line.hsn,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'HSN/SAC'))),
          SizedBox(
              width: 105,
              child: TextField(
                  controller: line.gst,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'GST %'))),
        ]),
      ]);
}

class _ScannedLine {
  _ScannedLine();

  factory _ScannedLine.fromMap(Map<String, dynamic> raw) {
    final line = _ScannedLine();
    line.productId = raw['product_id']?.toString();
    line.productType =
        raw['product_type']?.toString().toUpperCase() == 'SERVICE'
            ? 'SERVICE'
            : 'GOODS';
    line.name.text = raw['product_name']?.toString() ?? '';
    line.quantity.text = raw['quantity']?.toString() ?? '1';
    line.rate.text = raw['rate']?.toString() ?? '0';
    line.hsn.text = raw['hsn_sac']?.toString() ?? '';
    line.gst.text = raw['gst_rate']?.toString() ?? '0';
    return line;
  }

  String? productId;
  String productType = 'GOODS';
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final rate = TextEditingController(text: '0');
  final hsn = TextEditingController();
  final gst = TextEditingController(text: '18');

  Map<String, dynamic> get payload => {
        'product_id': productId,
        'product_name': name.text.trim(),
        'product_type': productType,
        'quantity': double.tryParse(quantity.text) ?? 0,
        'rate': double.tryParse(rate.text) ?? 0,
        'hsn_sac': hsn.text.trim(),
        'gst_rate': double.tryParse(gst.text) ?? 0,
      };

  void dispose() {
    name.dispose();
    quantity.dispose();
    rate.dispose();
    hsn.dispose();
    gst.dispose();
  }
}

class _ScanDateField extends StatelessWidget {
  const _ScanDateField(
      {required this.label, required this.value, required this.onChanged});
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final picked = await pickDate(context, value);
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_month_outlined)),
          child: Text(displayDate(value.toIso8601String())),
        ),
      );
}
