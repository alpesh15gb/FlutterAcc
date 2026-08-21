import 'package:flutter_test/flutter_test.dart';
import 'package:apexbooks/core/utils/formatters.dart';

void main() {
  group('Indian accounting formatters', () {
    test('money handles numeric and string inputs', () {
      expect(money(0), contains('0.00'));
      expect(money('1234.5'), contains('1,234.50'));
      expect(money(null), contains('0.00'));
    });

    test('shortMoney uses Indian lakh and crore units', () {
      expect(shortMoney(150000), '₹1.50 L');
      expect(shortMoney(25000000), '₹2.50 Cr');
      expect(shortMoney(1200), '₹1.2K');
    });

    test('api and display dates are stable', () {
      final date = DateTime(2026, 8, 21);
      expect(apiDate(date), '2026-08-21');
      expect(isoDate(date), '2026-08-21');
      expect(displayDate('2026-08-21'), '21 Aug 2026');
      expect(displayDate(null), '—');
    });

    test('titleCase converts backend enum keys', () {
      expect(titleCase('PARTIALLY_PAID'), 'Partially Paid');
      expect(titleCase('e_invoice_status'), 'E Invoice Status');
    });
  });
}
