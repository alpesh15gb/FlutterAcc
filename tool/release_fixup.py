from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    actual = text.count(old)
    if actual < count:
        raise SystemExit(f"{path}: expected >= {count}, found {actual}: {old[:120]!r}")
    p.write_text(text.replace(old, new, count), encoding="utf-8")


# ---------------------------------------------------------------------------
# Shared tax document editor
# ---------------------------------------------------------------------------
p = "lib/features/sales/tax_document_editor_screen.dart"
replace(
    p,
    "      final grossLine = (qty * rate - discount).clamp(0, double.infinity);",
    "      final grossLine =\n          (qty * rate - discount).clamp(0.0, double.infinity).toDouble();",
)
replace(
    p,
    """              items: const [
                DropdownMenuItem(value: 'DOMESTIC', child: Text('Domestic')),
                DropdownMenuItem(value: 'EXPORT', child: Text('Export')),
                DropdownMenuItem(value: 'SEZ', child: Text('SEZ')),
                DropdownMenuItem(
                    value: 'DEEMED_EXPORT', child: Text('Deemed export')),
              ],
              onChanged: (value) =>
                  setState(() => _supplyType = value ?? 'DOMESTIC'),
""",
    """              items: const [
                DropdownMenuItem(value: 'DOMESTIC', child: Text('Domestic')),
                DropdownMenuItem(
                    value: 'EXPORT_WITH_TAX', child: Text('Export with tax')),
                DropdownMenuItem(
                    value: 'EXPORT_WITHOUT_TAX',
                    child: Text('Export without tax / LUT')),
                DropdownMenuItem(
                    value: 'SEZ_WITH_TAX', child: Text('SEZ with tax')),
                DropdownMenuItem(
                    value: 'SEZ_WITHOUT_TAX', child: Text('SEZ without tax')),
              ],
              onChanged: (value) {
                setState(() => _supplyType = value ?? 'DOMESTIC');
                _queuePreview();
              },
""",
)

# ---------------------------------------------------------------------------
# Recurring invoices: same explicit included/excluded semantics as invoices.
# ---------------------------------------------------------------------------
p = "lib/features/recurring/recurring_invoices_screen.dart"
replace(
    p,
    "              'Generate an invoice from ${row['template_name'] ?? 'this template'}? '\n              'Recurring template rates are GST EXCLUSIVE, so GST is added on top.',",
    "              'Generate an invoice from ${row['template_name'] ?? 'this template'}? '\n              'Saved rate mode: ${row['is_gst_inclusive'] == true ? 'GST INCLUDED' : 'GST EXCLUDED'}.',",
)
replace(
    p,
    "        'Invoice ${data is Map ? data['invoice_number'] ?? '' : ''} generated. '\n        'GST was added above the taxable template rates.',",
    "        'Invoice ${data is Map ? data['invoice_number'] ?? '' : ''} generated with the template GST rate mode.',",
)
replace(
    p,
    "        subtitle:\n            'Scheduled billing. Template rates are explicitly GST-exclusive until the backend stores an inclusive-rate mode.',",
    "        subtitle:\n            'Scheduled billing with an explicit GST-included or GST-excluded rate mode.',",
)
replace(
    p,
    """          SectionCard(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withOpacity(.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GST EXCLUSIVE RATES: ₹16,500 @ 18% generates ₹19,470. '
                      'If ₹16,500 is the final GST-inclusive amount, create a normal invoice and choose “GST INCLUDED in entered rate”.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
""",
    "",
)
replace(
    p,
    "                        const Chip(label: Text('GST EXCL. RATES')),",
    "                        Chip(\n                          label: Text(row['is_gst_inclusive'] == true\n                              ? 'GST INCLUDED'\n                              : 'GST EXCLUDED'),\n                        ),",
)
replace(
    p,
    "  DateTime? _endDate;\n  bool _loading = false;",
    "  DateTime? _endDate;\n  bool? _inclusive;\n  bool _loading = false;",
)
replace(
    p,
    "        _pos.text = '${data['pos_state_code'] ?? '27'}';\n        _notes.text = '${data['notes'] ?? ''}';",
    "        _pos.text = '${data['pos_state_code'] ?? '27'}';\n        _inclusive = data['is_gst_inclusive'] == true;\n        _notes.text = '${data['notes'] ?? ''}';",
)
replace(
    p,
    """  Map<String, double> get _estimate {
    var taxable = 0.0;
    var gst = 0.0;
    for (final line in _lines) {
      final qty = double.tryParse(line.quantity.text) ?? 0;
      final rate = double.tryParse(line.rate.text) ?? 0;
      final discount = double.tryParse(line.discount.text) ?? 0;
      final lineBase = (qty * rate - discount).clamp(0.0, double.infinity);
      final ratePct = double.tryParse(line.gst.text) ?? 0;
      taxable += lineBase;
      gst += lineBase * ratePct / 100;
    }
    return {'taxable': taxable, 'gst': gst, 'total': taxable + gst};
  }
""",
    """  Map<String, double> get _estimate {
    var entered = 0.0;
    var taxable = 0.0;
    var gst = 0.0;
    for (final line in _lines) {
      final qty = double.tryParse(line.quantity.text) ?? 0;
      final rate = double.tryParse(line.rate.text) ?? 0;
      final discount = double.tryParse(line.discount.text) ?? 0;
      final lineAmount =
          (qty * rate - discount).clamp(0.0, double.infinity).toDouble();
      final ratePct = double.tryParse(line.gst.text) ?? 0;
      entered += lineAmount;
      if (_inclusive == true && ratePct > 0) {
        final base = lineAmount / (1 + ratePct / 100);
        taxable += base;
        gst += lineAmount - base;
      } else {
        taxable += lineAmount;
        gst += lineAmount * ratePct / 100;
      }
    }
    return {
      'entered': entered,
      'taxable': taxable,
      'gst': gst,
      'total': _inclusive == true ? entered : taxable + gst,
    };
  }
""",
)
replace(
    p,
    """    if (_name.text.trim().isEmpty ||
        _contactId == null ||
        _pos.text.trim().length != 2 ||
        _lines.isEmpty) {
      showMessage(context, 'Template name, customer, POS and items are required.',
          error: true);
      return;
    }
""",
    """    if (_name.text.trim().isEmpty ||
        _contactId == null ||
        _pos.text.trim().length != 2 ||
        _lines.isEmpty) {
      showMessage(context, 'Template name, customer, POS and items are required.',
          error: true);
      return;
    }
    if (_inclusive == null) {
      showMessage(context,
          'Choose whether recurring invoice rates INCLUDE GST or EXCLUDE GST.',
          error: true);
      return;
    }
""",
)
replace(
    p,
    "        'pos_state_code': _pos.text.trim(),\n        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),",
    "        'pos_state_code': _pos.text.trim(),\n        'is_gst_inclusive': _inclusive,\n        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),",
)
replace(
    p,
    """                        SectionCard(
                          title: 'GST rate mode',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'GST EXCLUDED — FIXED BY CURRENT BACKEND. Every rate below is a taxable/base rate; GST is added when the invoice is generated.',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
""",
    """                        SectionCard(
                          title: 'GST rate mode — required',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'What does each recurring line rate already contain?',
                                style: TextStyle(color: AppColors.muted),
                              ),
                              const SizedBox(height: 10),
                              Wrap(spacing: 10, runSpacing: 10, children: [
                                ChoiceChip(
                                  label: const Text('GST INCLUDED in rate'),
                                  selected: _inclusive == true,
                                  onSelected: (_) =>
                                      setState(() => _inclusive = true),
                                ),
                                ChoiceChip(
                                  label: const Text('GST EXCLUDED — add GST'),
                                  selected: _inclusive == false,
                                  onSelected: (_) =>
                                      setState(() => _inclusive = false),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                _inclusive == true
                                    ? '₹16,500 @ 18% remains ₹16,500 total; GST is extracted.'
                                    : _inclusive == false
                                        ? '₹16,500 @ 18% becomes ₹19,470 total; GST is added.'
                                        : 'Choose a rate mode before saving.',
                                style: TextStyle(
                                  color: _inclusive == null
                                      ? AppColors.danger
                                      : AppColors.muted,
                                  fontWeight: _inclusive == null
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
""",
)
replace(
    p,
    """                                        decoration: const InputDecoration(
                                          labelText: 'Taxable rate (GST excluded)',
                                          helperText: 'GST added on top',
                                        ),
""",
    """                                        decoration: InputDecoration(
                                          labelText: _inclusive == true
                                              ? 'Rate (GST included)'
                                              : _inclusive == false
                                                  ? 'Rate (GST excluded)'
                                                  : 'Rate — choose GST mode',
                                          helperText: _inclusive == true
                                              ? 'GST already inside this rate'
                                              : _inclusive == false
                                                  ? 'GST added on top'
                                                  : 'Choose mode above',
                                        ),
""",
)
replace(
    p,
    "        showMessage(context, 'Fix item ${i + 1}: item, qty, taxable rate and HSN/SAC are required.',",
    "        showMessage(context, 'Fix item ${i + 1}: item, qty, rate and HSN/SAC are required.',",
)
replace(
    p,
    """                        SectionCard(
                          title: 'Expected invoice total',
                          child: Wrap(spacing: 28, runSpacing: 12, children: [
                            _metric('Taxable', totals['taxable'] ?? 0),
                            _metric('Estimated GST', totals['gst'] ?? 0),
                            _metric('Expected total', totals['total'] ?? 0),
                          ]),
                        ),
""",
    """                        SectionCard(
                          title: 'Expected invoice total',
                          child: Wrap(spacing: 28, runSpacing: 12, children: [
                            _metric('Entered amount', totals['entered'] ?? 0),
                            _metric('Taxable', totals['taxable'] ?? 0),
                            _metric('Estimated GST', totals['gst'] ?? 0),
                            _metric('Expected total', totals['total'] ?? 0),
                          ]),
                        ),
""",
)

# ---------------------------------------------------------------------------
# Invoice post-save visibility
# ---------------------------------------------------------------------------
p = "lib/features/sales/invoices_screen.dart"
replace(
    p,
    "      _detailRow(\n          'GST inclusive', data['is_gst_inclusive'] == true ? 'Yes' : 'No'),",
    "      _detailRow(\n          'Rate entry mode',\n          data['is_gst_inclusive'] == true\n              ? 'GST INCLUDED in entered rate'\n              : 'GST EXCLUDED; GST added on top'),",
)
replace(
    p,
    """            child: Text(
                '${line['product_name'] ?? line['description'] ?? 'Item'} • Qty ${displayValue(line['quantity'])} • ${money(line['total'])}'),
""",
    """            child: Text(
                '${line['product_name'] ?? line['description'] ?? 'Item'} • '
                'Qty ${displayValue(line['quantity'])} • '
                'Rate ${money(line['rate'])} ${data['is_gst_inclusive'] == true ? '(incl. GST)' : '(excl. GST)'} • '
                'GST ${displayValue(line['gst_rate'])}% • ${money(line['total'])}'),
""",
)

# ---------------------------------------------------------------------------
# Purchase-bill workspace visibility
# ---------------------------------------------------------------------------
p = "lib/data/workspace_catalog.dart"
replace(
    p,
    "      WorkspaceColumn('status', 'Status', status: true),\n      WorkspaceColumn('total', 'Total', money: true),\n      WorkspaceColumn('amount_paid', 'Paid', money: true)",
    "      WorkspaceColumn('status', 'Status', status: true),\n      WorkspaceColumn('is_gst_inclusive', 'Rate mode', taxMode: true),\n      WorkspaceColumn('total', 'Total', money: true),\n      WorkspaceColumn('amount_paid', 'Paid', money: true)",
)
replace(
    p,
    "  const WorkspaceColumn(this.key, this.label,\n      {this.money = false, this.date = false, this.status = false});",
    "  const WorkspaceColumn(this.key, this.label,\n      {this.money = false,\n      this.date = false,\n      this.status = false,\n      this.taxMode = false});",
)
replace(
    p,
    "  final bool status;\n}",
    "  final bool status;\n  final bool taxMode;\n}",
)

p = "lib/features/workspaces/data_workspace_screen.dart"
replace(
    p,
    "    if (key.contains('date') || key.endsWith('_at')) return displayDate(value);",
    "    if (key == 'is_gst_inclusive') {\n      return value == true\n          ? 'GST INCLUDED in rate'\n          : 'GST EXCLUDED; added on top';\n    }\n    if (key.contains('date') || key.endsWith('_at')) return displayDate(value);",
)
replace(
    p,
    """            child: Text(
              '${raw['product_name'] ?? raw['description'] ?? 'Item'}  •  Qty ${displayValue(raw['quantity'])}  •  ${money(raw['total'] ?? ((num.tryParse('${raw['quantity']}') ?? 0) * (num.tryParse('${raw['rate']}') ?? 0)))}',
            ),
""",
    """            child: Text(
              '${raw['product_name'] ?? raw['description'] ?? 'Item'}  •  '
              'Qty ${displayValue(raw['quantity'])}  •  '
              'Rate ${money(raw['rate'])} ${item['is_gst_inclusive'] == true ? '(incl. GST)' : '(excl. GST)'}  •  '
              '${money(raw['total'] ?? ((num.tryParse('${raw['quantity']}') ?? 0) * (num.tryParse('${raw['rate']}') ?? 0)))}',
            ),
""",
)
replace(
    p,
    """    final text = column.money
        ? money(raw)
        : column.date
            ? displayDate(raw)
            : displayValue(raw);
""",
    """    final text = column.taxMode
        ? (raw == true ? 'GST INCLUDED' : 'GST EXCLUDED')
        : column.money
            ? money(raw)
            : column.date
                ? displayDate(raw)
                : displayValue(raw);
""",
)

# ---------------------------------------------------------------------------
# Product prices are document defaults, not inherently inclusive/exclusive.
# ---------------------------------------------------------------------------
p = "lib/features/masters/products_screen.dart"
replace(p, "DataColumn(label: Text('Sale price'))", "DataColumn(label: Text('Default sale rate'))")
replace(p, "labelText: 'Sale price'", "labelText: 'Default sale rate'")
replace(p, "labelText: 'Purchase price'", "labelText: 'Default purchase rate'")

# ---------------------------------------------------------------------------
# Regression contract tests.
# ---------------------------------------------------------------------------
test = Path("test/tax_mode_contract_test.dart")
test.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('16500 inclusive at 18 percent keeps the gross total', () {
    const gross = 16500.0;
    const gstRate = 18.0;
    final taxable = gross / (1 + gstRate / 100);
    final gst = gross - taxable;

    expect(taxable, closeTo(13983.05, 0.01));
    expect(gst, closeTo(2516.95, 0.01));
    expect(taxable + gst, closeTo(16500.0, 0.001));
  });

  test('16500 exclusive at 18 percent becomes 19470', () {
    const taxable = 16500.0;
    const gstRate = 18.0;
    final gst = taxable * gstRate / 100;
    expect(gst, 2970.0);
    expect(taxable + gst, 19470.0);
  });

  test('invoice editor uses exact backend supply-type enum', () {
    final source = File('lib/features/sales/tax_document_editor_screen.dart')
        .readAsStringSync();
    for (final value in [
      'DOMESTIC',
      'EXPORT_WITH_TAX',
      'EXPORT_WITHOUT_TAX',
      'SEZ_WITH_TAX',
      'SEZ_WITHOUT_TAX',
    ]) {
      expect(source, contains("value: '$value'"));
    }
    expect(source, isNot(contains("value: 'EXPORT'")));
    expect(source, isNot(contains("value: 'SEZ'")));
  });

  test('recurring templates send explicit GST rate mode', () {
    final source = File('lib/features/recurring/recurring_invoices_screen.dart')
        .readAsStringSync();
    expect(source, contains("'is_gst_inclusive': _inclusive"));
    expect(source, contains('GST INCLUDED in rate'));
    expect(source, contains('GST EXCLUDED — add GST'));
  });
}
''', encoding="utf-8")

print("Release GST/frontend fixup applied.")
