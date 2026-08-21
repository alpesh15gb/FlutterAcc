import 'dart:io';

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
