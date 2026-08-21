import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key, required this.api, required this.purchase});
  final ApiClient api;
  final bool purchase;

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  String get _endpoint =>
      widget.purchase ? '/returns/purchase' : '/returns/sales';

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
      final data = await widget.api.get(_endpoint, query: {'limit': 100});
      _items = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    try {
      final sourcePath = widget.purchase ? '/bills' : '/invoices';
      final raw = await widget.api.get(sourcePath, query: {'limit': 100});
      final source = raw is Map ? raw['items'] : raw;
      final docs = (source as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where(
            (e) => widget.purchase
                ? ['POSTED', 'PARTIALLY_PAID', 'PAID'].contains(e['status'])
                : [
                    'POSTED',
                    'SENT',
                    'PARTIALLY_PAID',
                    'PAID',
                  ].contains(e['status']),
          )
          .toList();
      if (!mounted) return;
      if (docs.isEmpty) {
        showMessage(
          context,
          'No eligible posted ${widget.purchase ? 'bills' : 'invoices'} found.',
          error: true,
        );
        return;
      }
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _ReturnEditor(
            api: widget.api,
            purchase: widget.purchase,
            documents: docs,
          ),
        ),
      );
      if (saved == true) _load();
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> item) async {
    try {
      await widget.api.post('$_endpoint/${item['id']}/cancel');
      if (mounted) {
        showMessage(context, 'Return cancelled and reversed.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.purchase ? 'Purchase Returns' : 'Sales Returns',
    subtitle: widget.purchase
        ? 'Return supplier goods against posted bill lines and reverse stock/input GST.'
        : 'Accept customer returns against posted invoice lines and reverse revenue/output GST.',
    actions: [
      IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          widget.purchase ? 'New purchase return' : 'New sales return',
        ),
      ),
    ],
    child: _loading
        ? const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null
        ? ErrorPanel(message: _error!, onRetry: _load)
        : _items.isEmpty
        ? EmptyState(
            icon: Icons.assignment_return_outlined,
            title: 'No returns',
            message: 'Returns created from posted source documents will appear here.',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create return'),
            ),
          )
        : Column(
            children: _items.map((r) {
              final status = '${r['status'] ?? ''}';
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.assignment_return_outlined),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${r['return_number'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          money(r['total']),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${r['contact_name'] ?? ''} • ${displayDate(r['issue_date'])} • $status',
                    ),
                    trailing: status == 'POSTED'
                        ? PopupMenuButton<String>(
                            onSelected: (_) => _cancel(r),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'cancel',
                                child: Text('Cancel return'),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
  );
}

class _ReturnEditor extends StatefulWidget {
  const _ReturnEditor({
    required this.api,
    required this.purchase,
    required this.documents,
  });
  final ApiClient api;
  final bool purchase;
  final List<Map<String, dynamic>> documents;

  @override
  State<_ReturnEditor> createState() => _ReturnEditorState();
}

class _ReturnEditorState extends State<_ReturnEditor> {
  String? _documentId;
  Map<String, dynamic>? _detail;
  List<_ReturnLineDraft> _lines = [];
  DateTime _date = DateTime.now();
  final _notes = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _documentId = '${widget.documents.first['id']}';
    _loadDetail();
  }

  @override
  void dispose() {
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = widget.purchase
          ? '/bills/$_documentId'
          : '/invoices/$_documentId';
      final data = Map<String, dynamic>.from(await widget.api.get(path) as Map);
      for (final line in _lines) {
        line.dispose();
      }
      final rawLines = data['lines'] is List ? data['lines'] as List : const [];
      _lines = rawLines.map((raw) {
        final line = Map<String, dynamic>.from(raw as Map);
        return _ReturnLineDraft(line: line);
      }).toList();
      _detail = data;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_detail == null) return;
    final chosen = _lines
        .where((l) => (double.tryParse(l.quantity.text) ?? 0) > 0)
        .toList();
    if (chosen.isEmpty) {
      showMessage(
        context,
        'Enter a return quantity for at least one line.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final lineItems = chosen.map((l) {
        final line = l.line;
        return {
          widget.purchase ? 'bill_line_id' : 'invoice_line_id': line['id'],
          'product_id': line['product_id'],
          'description': l.description.text.trim().isEmpty
              ? null
              : l.description.text.trim(),
          'quantity': double.tryParse(l.quantity.text) ?? 0,
          'rate': line['rate'] ?? 0,
          'hsn_sac': line['hsn_sac'],
          'gst_rate': line['gst_rate'] ?? 0,
        };
      }).toList();
      await widget.api.post(
        widget.purchase ? '/returns/purchase' : '/returns/sales',
        body: {
          widget.purchase ? 'bill_id' : 'invoice_id': _detail!['id'],
          'contact_id': _detail!['contact_id'],
          'issue_date': apiDate(_date),
          'pos_state_code': _detail!['pos_state_code'],
          'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          'line_items': lineItems,
        },
      );
      if (mounted) {
        showMessage(
          context,
          '${widget.purchase ? 'Purchase' : 'Sales'} return posted.',
        );
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
      title: Text(widget.purchase ? 'New purchase return' : 'New sales return'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Posting…' : 'Post return'),
          ),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            children: [
              SectionCard(
                title: 'Source document',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 500,
                      child: DropdownButtonFormField<String>(
                        value: _documentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: widget.purchase
                              ? 'Posted vendor bill'
                              : 'Posted customer invoice',
                        ),
                        items: widget.documents
                            .map(
                              (d) => DropdownMenuItem<String>(
                                value: '${d['id']}',
                                child: Text(
                                  '${widget.purchase ? d['bill_number'] : d['invoice_number']} • ${d['contact_name']} • ${money(d['total'])}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          setState(() => _documentId = v);
                          _loadDetail();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: InkWell(
                        onTap: () async {
                          final d = await pickDate(context, _date);
                          if (d != null) setState(() => _date = d);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Return date',
                          ),
                          child: Text(displayDate(_date.toIso8601String())),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _notes,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ),
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
                ErrorPanel(message: _error!, onRetry: _loadDetail)
              else
                SectionCard(
                  title: 'Return quantities',
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Enter only the quantities being returned. Tax amounts are derived from the original posted line.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._lines.map(
                        (l) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              SizedBox(
                                width: 330,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l.line['product_name'] ?? l.line['description'] ?? 'Item'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'HSN ${l.line['hsn_sac'] ?? ''} • GST ${l.line['gst_rate'] ?? 0}% • source qty ${formatNumber(l.line['quantity'])}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: TextField(
                                  controller: l.quantity,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Return qty',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 430,
                                child: TextField(
                                  controller: l.description,
                                  decoration: const InputDecoration(
                                    labelText: 'Line reason / description',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ReturnLineDraft {
  _ReturnLineDraft({required this.line}) {
    description.text = '${line['description'] ?? ''}';
  }
  final Map<String, dynamic> line;
  final quantity = TextEditingController();
  final description = TextEditingController();
  void dispose() {
    quantity.dispose();
    description.dispose();
  }
}
