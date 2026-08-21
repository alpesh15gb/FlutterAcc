import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'app_widgets.dart';

class JsonReportView extends StatelessWidget {
  const JsonReportView(
      {super.key,
      required this.data,
      this.emptyMessage = 'No report data returned for this period.'});
  final dynamic data;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (data == null)
      return EmptyState(
          icon: Icons.analytics_outlined,
          title: 'No data',
          message: emptyMessage);
    if (data is List) return _list(context, data as List);
    if (data is Map)
      return _map(context, Map<String, dynamic>.from(data as Map));
    return SelectableText(data.toString());
  }

  Widget _map(BuildContext context, Map<String, dynamic> map) {
    final scalars = <MapEntry<String, dynamic>>[];
    final complex = <MapEntry<String, dynamic>>[];
    for (final entry in map.entries) {
      if (entry.value is Map || entry.value is List) {
        complex.add(entry);
      } else {
        scalars.add(entry);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (scalars.isNotEmpty)
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 1000
              ? 4
              : c.maxWidth >= 650
                  ? 3
                  : c.maxWidth >= 420
                      ? 2
                      : 1;
          final gap = 10.0;
          final width = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: scalars
                .map((e) => SizedBox(
                      width: width,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(titleCase(e.key),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted)),
                                const SizedBox(height: 6),
                                SelectableText(_formatted(e.key, e.value),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ]),
                        ),
                      ),
                    ))
                .toList(),
          );
        }),
      if (scalars.isNotEmpty && complex.isNotEmpty) const SizedBox(height: 14),
      for (var i = 0; i < complex.length; i++) ...[
        SectionCard(
          title: titleCase(complex[i].key),
          child: complex[i].value is List
              ? _list(context, complex[i].value as List)
              : _map(
                  context, Map<String, dynamic>.from(complex[i].value as Map)),
        ),
        if (i != complex.length - 1) const SizedBox(height: 14),
      ],
    ]);
  }

  Widget _list(BuildContext context, List list) {
    if (list.isEmpty)
      return const Text('No rows', style: TextStyle(color: AppColors.muted));
    if (list.first is! Map) {
      return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((e) => Chip(label: Text(e.toString()))).toList());
    }
    final rows =
        list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final keys = <String>[];
    for (final row in rows.take(20)) {
      for (final key in row.keys) {
        if (!keys.contains(key) && row[key] is! Map && row[key] is! List)
          keys.add(key);
      }
    }
    if (keys.isEmpty) {
      return Column(
          children: rows
              .map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: JsonReportView(data: row)))
              .toList());
    }
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 720) {
        return Column(
            children: rows
                .map((row) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            children: keys
                                .map((key) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                                width: 120,
                                                child: Text(titleCase(key),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.muted))),
                                            Expanded(
                                                child: Text(
                                                    _formatted(key, row[key]),
                                                    textAlign:
                                                        TextAlign.right)),
                                          ]),
                                    ))
                                .toList()),
                      ),
                    ))
                .toList());
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: keys
              .map((key) => DataColumn(
                  label: Text(titleCase(key),
                      style: const TextStyle(fontWeight: FontWeight.w800))))
              .toList(),
          rows: rows
              .map((row) => DataRow(
                  cells: keys
                      .map((key) =>
                          DataCell(SelectableText(_formatted(key, row[key]))))
                      .toList()))
              .toList(),
        ),
      );
    });
  }

  String _formatted(String key, Object? value) {
    final k = key.toLowerCase();
    if (value == null) return '—';
    if (k.contains('date') || k.endsWith('_at')) return displayDate(value);
    if (value is num &&
        (k.contains('amount') ||
            k.contains('total') ||
            k.contains('balance') ||
            k.contains('revenue') ||
            k.contains('expense') ||
            k.contains('profit') ||
            k.contains('taxable') ||
            k.contains('sales') ||
            k.contains('purchase'))) {
      return money(value);
    }
    return displayValue(value);
  }
}
