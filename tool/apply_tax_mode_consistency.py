from pathlib import Path


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    actual = text.count(old)
    if actual < count:
        raise SystemExit(f"{path}: expected at least {count} occurrence(s), found {actual}: {old[:80]!r}")
    text = text.replace(old, new, count)
    p.write_text(text, encoding="utf-8")


# ---------------------------------------------------------------------------
# Invoice / purchase-bill editor: tax mode must be explicit and visible.
# ---------------------------------------------------------------------------
p = "lib/features/sales/tax_document_editor_screen.dart"
replace(p, "  bool _inclusive = false;", "  bool? _inclusive;")
replace(p, "        'is_gst_inclusive': _inclusive,", "        'is_gst_inclusive': _inclusive ?? false,")
replace(
    p,
    "    if (!def.hasPreview ||\n        _contactId == null ||\n        _lines.any((l) => l.productId == null)) return;",
    "    if (!def.hasPreview ||\n        _contactId == null ||\n        _lines.any((l) => l.productId == null)) return;\n    if (def.extendedTaxFields && _inclusive == null) return;",
)
replace(
    p,
    "    if (_dueDate.isBefore(_date))\n      return 'Due date cannot be before the document date.';",
    "    if (_dueDate.isBefore(_date))\n      return 'Due date cannot be before the document date.';\n    if (def.extendedTaxFields && _inclusive == null)\n      return 'Choose whether entered rates INCLUDE GST or EXCLUDE GST.';",
)
replace(
    p,
    "                            _headerCard(),\n                            const SizedBox(height: 14),\n                            _lineItemsCard(),",
    "                            _headerCard(),\n                            const SizedBox(height: 14),\n                            _taxModeCard(),\n                            const SizedBox(height: 14),\n                            _lineItemsCard(),",
)
replace(
    p,
    "  Widget _lineItemsCard() {",
    """  Widget _taxModeCard() {
    if (!def.extendedTaxFields) {
      return SectionCard(
        title: 'GST rate mode',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(.28)),
          ),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'GST EXCLUSIVE: this document type treats the entered rate as the taxable rate and adds GST on top. The rate field is labelled accordingly.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
      );
    }

    final mode = _inclusive;
    return SectionCard(
      title: 'GST rate mode — required',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
          'Tell ApexBooks what the entered rate means. This choice changes the taxable value and final payable amount.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          ChoiceChip(
            avatar: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: const Text('GST INCLUDED in entered rate'),
            selected: mode == true,
            onSelected: (_) {
              setState(() => _inclusive = true);
              _queuePreview();
            },
          ),
          ChoiceChip(
            avatar: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('GST EXCLUDED — add GST on top'),
            selected: mode == false,
            onSelected: (_) {
              setState(() => _inclusive = false);
              _queuePreview();
            },
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          mode == true
              ? 'Inclusive example: entering ₹16,500 at 18% keeps the payable near ₹16,500; GST is extracted from that amount.'
              : mode == false
                  ? 'Exclusive example: entering ₹16,500 at 18% makes the payable near ₹19,470 because GST is added on top.'
                  : 'No tax mode selected yet. Saving is blocked until you choose one.',
          style: TextStyle(
            color: mode == null ? AppColors.danger : AppColors.muted,
            fontWeight: mode == null ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ]),
    );
  }

  String get _rateLabel {
    if (!def.extendedTaxFields) return 'Rate (GST excluded)';
    if (_inclusive == true) return 'Rate (GST included)';
    if (_inclusive == false) return 'Rate (GST excluded)';
    return 'Rate — choose GST mode';
  }

  Widget _lineItemsCard() {""",
)
replace(
    p,
    "                    decoration: const InputDecoration(labelText: 'Rate'))),",
    "                    decoration: InputDecoration(\n                        labelText: _rateLabel,\n                        helperText: _inclusive == true\n                            ? 'GST is already inside this rate'\n                            : _inclusive == false || !def.extendedTaxFields\n                                ? 'GST is added above this rate'\n                                : 'Choose GST mode above first'))),",
)
replace(
    p,
    "          FilterChip(\n              label: const Text('GST inclusive prices'),\n              selected: _inclusive,\n              onSelected: (v) {\n                setState(() => _inclusive = v);\n                _queuePreview();\n              }),\n",
    "",
)

# Replace the summary implementation with one that never hides rate semantics.
start = "  Widget _summaryCard() {"
end = "\n  Widget _summaryRow(String label, String value)"
text = Path(p).read_text(encoding="utf-8")
si = text.index(start)
ei = text.index(end, si)
summary = r'''  Widget _summaryCard() {
    final p = _preview;
    var entered = 0.0;
    var estimatedTaxable = 0.0;
    var estimatedTax = 0.0;
    for (final l in _lines) {
      final qty = double.tryParse(l.quantity.text) ?? 0;
      final rate = double.tryParse(l.rate.text) ?? 0;
      final disc = double.tryParse(l.discount.text) ?? 0;
      final gst = double.tryParse(l.gst.text) ?? 0;
      final lineEntered = qty * rate - disc;
      entered += lineEntered;
      if (_inclusive == true && gst > 0) {
        final taxable = lineEntered / (1 + gst / 100);
        estimatedTaxable += taxable;
        estimatedTax += lineEntered - taxable;
      } else {
        estimatedTaxable += lineEntered;
        estimatedTax += lineEntered * gst / 100;
      }
    }
    final serverTaxable = p?['subtotal'];
    final cgst = p?['cgst_amount'] ?? 0;
    final sgst = p?['sgst_amount'] ?? 0;
    final igst = p?['igst_amount'] ?? 0;
    final cess = p?['cess_amount'] ?? 0;
    final estimatedTotal = _inclusive == true
        ? entered
        : estimatedTaxable + estimatedTax;
    final total = p?['total'] ?? estimatedTotal;
    final modeText = !def.extendedTaxFields
        ? 'GST EXCLUDED — tax added on top'
        : _inclusive == true
            ? 'GST INCLUDED in entered rates'
            : _inclusive == false
                ? 'GST EXCLUDED — tax added on top'
                : 'SELECT GST RATE MODE';

    return SectionCard(
      title: 'Summary',
      trailing: _previewing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (_inclusive == null && def.extendedTaxFields
                    ? AppColors.danger
                    : AppColors.primary)
                .withOpacity(.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            modeText,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: _inclusive == null && def.extendedTaxFields
                  ? AppColors.danger
                  : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _summaryRow('Entered line amount', money(entered)),
        _summaryRow(
          _inclusive == true ? 'Taxable value (GST extracted)' : 'Taxable value',
          money(serverTaxable ?? estimatedTaxable),
        ),
        if (def.hasPreview && p != null) ...[
          _summaryRow('CGST', money(cgst)),
          _summaryRow(
            'SGST / UTGST',
            money((num.tryParse('$sgst') ?? 0) +
                (num.tryParse('${p['utgst_amount'] ?? 0}') ?? 0)),
          ),
          _summaryRow('IGST', money(igst)),
          if ((num.tryParse('$cess') ?? 0) != 0)
            _summaryRow('Cess', money(cess)),
          _summaryRow('Round off', money(p['round_off'] ?? 0)),
        ] else if (!def.hasPreview || !_previewing) ...[
          _summaryRow('Estimated GST', money(estimatedTax)),
        ],
        const Divider(height: 22),
        Row(children: [
          const Expanded(
              child: Text('Grand total',
                  style: TextStyle(fontWeight: FontWeight.w900))),
          Text(money(total),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20))
        ]),
        if (def.hasPreview) ...[
          const SizedBox(height: 10),
          Text(
            p == null
                ? 'The figure above is an estimate until the FastAPI tax preview returns. Saving remains server-authoritative.'
                : 'Tax split and grand total above came from the FastAPI GST preview and are authoritative.',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving…' : 'Save ${def.title}'))),
      ]),
    );
  }
'''
text = text[:si] + summary + text[ei:]
Path(p).write_text(text, encoding="utf-8")

# Proforma already has a backend preview route. Turn it on so its total is not a
# local subtotal masquerading as a grand total.
replace(
    p,
    "            extendedTaxFields: false,\n            hasPreview: false),\n        'salesOrder'",
    "            extendedTaxFields: false,\n            hasPreview: true),\n        'salesOrder'",
)
replace(
    p,
    "      final path = def.kind == 'bill' ? '/bills/preview' : '/invoices/preview';",
    "      final path = switch (def.kind) {\n        'bill' => '/bills/preview',\n        'proforma' => '/proforma-invoices/preview',\n        _ => '/invoices/preview',\n      };",
)

# ---------------------------------------------------------------------------
# Invoice list/detail: display saved rate mode everywhere, including each line.
# ---------------------------------------------------------------------------
p = "lib/features/sales/invoices_screen.dart"
replace(
    p,
    "_detailField('GST inclusive', detail['is_gst_inclusive'] == true ? 'Yes' : 'No'),",
    "_detailField(\n                      'Rate entry mode',\n                      detail['is_gst_inclusive'] == true\n                          ? 'GST INCLUDED in rate'\n                          : 'GST EXCLUDED; added on top'),",
)
# Add mode to desktop/mobile list subtitles wherever the invoice number/date string occurs.
replace(
    p,
    "${r['contact_name'] ?? ''} • ${displayDate(r['issue_date'])} • ${r['status'] ?? ''}",
    "${r['contact_name'] ?? ''} • ${displayDate(r['issue_date'])} • ${r['status'] ?? ''} • ${r['is_gst_inclusive'] == true ? 'Incl. GST rate' : 'Excl. GST rate'}",
    count=1,
)
# Enhance detail line text.
replace(
    p,
    "'${l['product_name'] ?? l['description'] ?? 'Item'} • Qty ${formatNumber(l['quantity'])} • ${money(l['total'])}'",
    "'${l['product_name'] ?? l['description'] ?? 'Item'} • Qty ${formatNumber(l['quantity'])} • Rate ${money(l['rate'])} ${detail['is_gst_inclusive'] == true ? '(incl. GST)' : '(excl. GST)'} • GST ${l['gst_rate'] ?? 0}% • ${money(l['total'])}'",
)

# ---------------------------------------------------------------------------
# Product master: prices are defaults; document tax mode decides interpretation.
# ---------------------------------------------------------------------------
p = "lib/features/masters/products_screen.dart"
replace(p, "DataColumn(label: Text('Sale price'))", "DataColumn(label: Text('Default sale rate'))")
replace(p, "labelText: 'Sale price'", "labelText: 'Default sale rate'")
replace(p, "labelText: 'Purchase price'", "labelText: 'Default purchase rate'")
replace(
    p,
    "                        if (_type == 'GOODS')\n                          SizedBox(",
    "                        const SizedBox(\n                            width: 700,\n                            child: Text(\n                              'These are default rates copied into documents. The invoice/bill GST rate mode decides whether the copied rate already includes GST or GST is added on top.',\n                              style: TextStyle(color: AppColors.muted, fontSize: 12),\n                            )),\n                        if (_type == 'GOODS')\n                          SizedBox(",
)

# ---------------------------------------------------------------------------
# Credit/debit notes inherit source invoice mode; make that visible and label rate.
# ---------------------------------------------------------------------------
p = "lib/features/notes/notes_screen.dart"
replace(
    p,
    "                    else\n                      SectionCard(\n                          title: 'Adjustment line',",
    "                    else\n                      Column(children: [\n                        SectionCard(\n                          title: 'GST rate mode',\n                          child: Align(\n                            alignment: Alignment.centerLeft,\n                            child: Text(\n                              _invoice?['is_gst_inclusive'] == true\n                                  ? 'INHERITED: source invoice rates INCLUDE GST. The backend extracts GST before calculating this note.'\n                                  : 'INHERITED: source invoice rates EXCLUDE GST. GST is added on top of the entered adjustment rate.',\n                              style: const TextStyle(fontWeight: FontWeight.w800),\n                            ),\n                          ),\n                        ),\n                        const SizedBox(height: 14),\n                        SectionCard(\n                          title: 'Adjustment line',",
)
# Close the new Column after the existing section card.
replace(
    p,
    "                          ]))\n                  ])))));",
    "                          ])),\n                      ])\n                  ])))));",
)
replace(
    p,
    "                                    decoration: const InputDecoration(\n                                        labelText: 'Rate'))),",
    "                                    decoration: InputDecoration(\n                                        labelText: _invoice?['is_gst_inclusive'] == true\n                                            ? 'Rate (GST included)'\n                                            : 'Rate (GST excluded)',\n                                        helperText: _invoice?['is_gst_inclusive'] == true\n                                            ? 'Inherited from source invoice'\n                                            : 'GST will be added on top'))),",
)
replace(
    p,
    "                                    'The backend recalculates the GST split from this adjustment and posts a balanced reversing/additional journal entry.',",
    "                                    'Tax mode is inherited from the source invoice. The backend recalculates the GST split consistently and posts a balanced reversing/additional journal entry.',",
)

# ---------------------------------------------------------------------------
# Returns already prorate source tax amounts; state that explicitly and show mode.
# ---------------------------------------------------------------------------
p = "lib/features/returns/returns_screen.dart"
replace(
    p,
    "                              'Enter only the quantities being returned. Tax amounts are derived from the original posted line.',",
    "                              _detail?['is_gst_inclusive'] == true\n                                  ? 'Source rates INCLUDE GST. Enter only return quantities; taxable value and GST are prorated from the original posted line, so GST is not added again.'\n                                  : 'Source rates EXCLUDE GST. Enter only return quantities; taxable value and GST are prorated from the original posted line.',",
)
replace(
    p,
    "'HSN ${l.line['hsn_sac'] ?? ''} • GST ${l.line['gst_rate'] ?? 0}% • source qty ${formatNumber(l.line['quantity'])}'",
    "'HSN ${l.line['hsn_sac'] ?? ''} • GST ${l.line['gst_rate'] ?? 0}% • source rate ${money(l.line['rate'])} ${_detail?['is_gst_inclusive'] == true ? '(incl. GST)' : '(excl. GST)'} • source qty ${formatNumber(l.line['quantity'])}'",
)

# ---------------------------------------------------------------------------
# Expenses are always entered as taxable/base amount; make the contract explicit.
# ---------------------------------------------------------------------------
p = "lib/features/expenses/expenses_screen.dart"
replace(
    p,
    "                                  decoration: const InputDecoration(\n                                      labelText: 'Taxable amount'),",
    "                                  decoration: const InputDecoration(\n                                      labelText: 'Taxable amount (GST excluded)',\n                                      helperText: 'Enter base value; GST is added on top'),",
)
replace(
    p,
    "                          SectionCard(\n                            title: 'Tax preview',",
    "                          SectionCard(\n                            title: 'Tax preview',\n                            subtitle: 'Expense entry uses GST-exclusive taxable value. The preview shows GST added above the base amount.',",
)

print('Flutter tax-mode consistency codemod applied successfully.')
