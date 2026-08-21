import 'package:intl/intl.dart';

final _currency =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _dateDisplay = DateFormat('dd MMM yyyy');
final _dateApi = DateFormat('yyyy-MM-dd');

String money(Object? value) {
  if (value == null) return _currency.format(0);
  if (value is num) return _currency.format(value);
  return _currency.format(num.tryParse(value.toString()) ?? 0);
}

String shortMoney(Object? value) {
  final n =
      value is num ? value.toDouble() : double.tryParse('${value ?? 0}') ?? 0;
  if (n.abs() >= 10000000) return '₹${(n / 10000000).toStringAsFixed(2)} Cr';
  if (n.abs() >= 100000) return '₹${(n / 100000).toStringAsFixed(2)} L';
  if (n.abs() >= 1000) return '₹${(n / 1000).toStringAsFixed(1)}K';
  return money(n);
}

String displayDate(Object? value) {
  if (value == null || value.toString().isEmpty) return '—';
  final dt = DateTime.tryParse(value.toString());
  return dt == null ? value.toString() : _dateDisplay.format(dt.toLocal());
}

String apiDate(DateTime value) => _dateApi.format(value);

String displayValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is Map || value is List) return value.toString();
  return value.toString();
}

String titleCase(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) =>
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

final _number = NumberFormat.decimalPattern('en_IN');
String formatNumber(Object? value) {
  final number = value is num ? value : num.tryParse('${value ?? 0}');
  return _number.format(number ?? 0);
}

String isoDate(DateTime value) => apiDate(value);
