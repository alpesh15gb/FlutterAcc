import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class EWayBillsScreen extends StatefulWidget {
  const EWayBillsScreen({super.key, required this.api});
  final ApiClient api;
  @override
  State<EWayBillsScreen> createState() => _EWayBillsScreenState();
}

class _EWayBillsScreenState extends State<EWayBillsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _rows(dynamic raw) {
    if (raw is List)
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    if (raw is Map && raw['items'] is List) {
      return (raw['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await widget.api.get('/eway-bills');
      _items = _rows(d);
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    try {
      final invRaw = await widget.api.get('/invoices', query: {'limit': 100});
      final billRaw = await widget.api.get('/bills', query: {'limit': 100});
      final invoices = _rows(invRaw)
          .where(
              (i) => ['POSTED', 'PARTIALLY_PAID', 'SENT'].contains(i['status']))
          .toList();
      final bills = _rows(billRaw)
          .where(
              (i) => ['POSTED', 'PARTIALLY_PAID', 'PAID'].contains(i['status']))
          .toList();
      if (!mounted) return;
      if (invoices.isEmpty && bills.isEmpty) {
        showMessage(context,
            'No finalized invoices or bills are available for e-Way Bill generation.',
            error: true);
        return;
      }
      var source = invoices.isNotEmpty ? 'invoice' : 'bill';
      String? invoiceId = invoices.isEmpty ? null : '${invoices.first['id']}';
      String? billId = bills.isEmpty ? null : '${bills.first['id']}';
      var supply = source == 'bill' ? 'INWARD' : 'OUTWARD';
      var sub = 'SUPPLY';
      var mode = 'ROAD';
      var vehicleType = 'REGULAR';
      final transporter = TextEditingController();
      final transporterName = TextEditingController();
      final docNo = TextEditingController();
      final distance = TextEditingController();
      final vehicle = TextEditingController();
      DateTime? docDate;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Generate e-Way Bill'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<String>(
                      value: source,
                      decoration:
                          const InputDecoration(labelText: 'Source document'),
                      items: [
                        if (invoices.isNotEmpty)
                          const DropdownMenuItem(
                              value: 'invoice', child: Text('Sales invoice')),
                        if (bills.isNotEmpty)
                          const DropdownMenuItem(
                              value: 'bill', child: Text('Purchase bill')),
                      ],
                      onChanged: (v) => setLocal(() {
                        source = v!;
                        supply = source == 'bill' ? 'INWARD' : 'OUTWARD';
                      }),
                    ),
                  ),
                  if (source == 'invoice')
                    SizedBox(
                      width: 640,
                      child: DropdownButtonFormField<String>(
                        value: invoiceId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Finalized invoice'),
                        items: invoices
                            .map((i) => DropdownMenuItem(
                                value: '${i['id']}',
                                child: Text(
                                    '${i['invoice_number']} • ${i['contact_name']} • ${money(i['total'])}')))
                            .toList(),
                        onChanged: (v) => setLocal(() => invoiceId = v),
                      ),
                    )
                  else
                    SizedBox(
                      width: 640,
                      child: DropdownButtonFormField<String>(
                        value: billId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Finalized purchase bill'),
                        items: bills
                            .map((i) => DropdownMenuItem(
                                value: '${i['id']}',
                                child: Text(
                                    '${i['bill_number']} • ${i['contact_name']} • ${money(i['total'])}')))
                            .toList(),
                        onChanged: (v) => setLocal(() => billId = v),
                      ),
                    ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: supply,
                      decoration:
                          const InputDecoration(labelText: 'Supply type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'OUTWARD', child: Text('Outward')),
                        DropdownMenuItem(
                            value: 'INWARD', child: Text('Inward')),
                      ],
                      onChanged: (v) => setLocal(() => supply = v!),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      value: sub,
                      decoration:
                          const InputDecoration(labelText: 'Sub-supply'),
                      items: const [
                        'SUPPLY',
                        'IMPORT',
                        'EXPORT',
                        'JOB_WORK',
                        'SEZ',
                        'LINE_SALES',
                        'OTHER'
                      ]
                          .map((v) => DropdownMenuItem(
                              value: v, child: Text(titleCase(v))))
                          .toList(),
                      onChanged: (v) => setLocal(() => sub = v!),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: mode,
                      decoration:
                          const InputDecoration(labelText: 'Transport mode'),
                      items: const ['ROAD', 'RAIL', 'AIR', 'SHIP']
                          .map((v) => DropdownMenuItem(
                              value: v, child: Text(titleCase(v))))
                          .toList(),
                      onChanged: (v) => setLocal(() => mode = v!),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: vehicleType,
                      decoration:
                          const InputDecoration(labelText: 'Vehicle type'),
                      items: const [
                        DropdownMenuItem(
                            value: 'REGULAR', child: Text('Regular')),
                        DropdownMenuItem(
                            value: 'ODC', child: Text('Over dimensional')),
                      ],
                      onChanged: (v) => setLocal(() => vehicleType = v!),
                    ),
                  ),
                  SizedBox(
                      width: 250,
                      child: TextField(
                          controller: vehicle,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                              labelText: 'Vehicle number *',
                              hintText: 'MH12AB1234'))),
                  SizedBox(
                      width: 180,
                      child: TextField(
                          controller: distance,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Distance (km) *'))),
                  SizedBox(
                      width: 300,
                      child: TextField(
                          controller: transporterName,
                          decoration: const InputDecoration(
                              labelText: 'Transporter name'))),
                  SizedBox(
                      width: 300,
                      child: TextField(
                          controller: transporter,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                              labelText: 'Transporter GSTIN'))),
                  SizedBox(
                      width: 250,
                      child: TextField(
                          controller: docNo,
                          decoration: const InputDecoration(
                              labelText: 'Transport document no.'))),
                  SizedBox(
                    width: 220,
                    child: InkWell(
                      onTap: () async {
                        final d =
                            await pickDate(context, docDate ?? DateTime.now());
                        if (d != null) setLocal(() => docDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Transport document date'),
                        child: Text(docDate == null
                            ? 'Not specified'
                            : displayDate(docDate!.toIso8601String())),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final km = int.tryParse(distance.text);
                  if (km == null || km < 1 || vehicle.text.trim().isEmpty) {
                    showMessage(context,
                        'Vehicle number and transport distance are required.',
                        error: true);
                    return;
                  }
                  try {
                    await widget.api.post('/eway-bills', body: {
                      'invoice_id': source == 'invoice' ? invoiceId : null,
                      'bill_id': source == 'bill' ? billId : null,
                      'supply_type': supply,
                      'sub_supply_type': sub,
                      'transporter_id': transporter.text.trim().isEmpty
                          ? null
                          : transporter.text.trim().toUpperCase(),
                      'transporter_name': transporterName.text.trim().isEmpty
                          ? null
                          : transporterName.text.trim(),
                      'trans_doc_number':
                          docNo.text.trim().isEmpty ? null : docNo.text.trim(),
                      'trans_doc_date':
                          docDate == null ? null : apiDate(docDate!),
                      'trans_distance': km,
                      'trans_mode': mode,
                      'vehicle_number':
                          vehicle.text.trim().replaceAll(' ', '').toUpperCase(),
                      'vehicle_type': vehicleType,
                    });
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (e) {
                    if (context.mounted)
                      showMessage(context, e.toString(), error: true);
                  }
                },
                child: const Text('Generate'),
              ),
            ],
          ),
        ),
      );
      for (final c in [
        transporter,
        transporterName,
        docNo,
        distance,
        vehicle
      ]) {
        c.dispose();
      }
      if (ok == true) {
        showMessage(context, 'e-Way Bill generated.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    var reason = '2';
    final remarks = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Cancel e-Way Bill'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: const [
                DropdownMenuItem(value: '1', child: Text('Duplicate')),
                DropdownMenuItem(value: '2', child: Text('Order cancelled')),
                DropdownMenuItem(value: '3', child: Text('Active EWB exists')),
                DropdownMenuItem(value: '4', child: Text('Other')),
              ],
              onChanged: (v) => setLocal(() => reason = v!),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: remarks,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Remarks')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back')),
            FilledButton(
              onPressed: () async {
                try {
                  await widget.api
                      .post('/eway-bills/${row['id']}/cancel', body: {
                    'cancel_reason': reason,
                    'cancel_remarks': remarks.text.trim().isEmpty
                        ? null
                        : remarks.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted)
                    showMessage(context, e.toString(), error: true);
                }
              },
              child: const Text('Cancel e-Way Bill'),
            ),
          ],
        ),
      ),
    );
    remarks.dispose();
    if (ok == true) _load();
  }

  Future<void> _updateVehicle(Map<String, dynamic> row) async {
    final vehicle =
        TextEditingController(text: row['vehicle_number']?.toString() ?? '');
    final fromPlace = TextEditingController();
    final fromState = TextEditingController();
    final remarks = TextEditingController();
    var vehicleType = row['vehicle_type']?.toString() ?? 'REGULAR';
    var reason = '1';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Update vehicle'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: vehicle,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle number *')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: vehicleType,
                decoration: const InputDecoration(labelText: 'Vehicle type'),
                items: const [
                  DropdownMenuItem(value: 'REGULAR', child: Text('Regular')),
                  DropdownMenuItem(
                      value: 'ODC', child: Text('Over dimensional')),
                ],
                onChanged: (v) => setLocal(() => vehicleType = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: fromPlace,
                  decoration: const InputDecoration(labelText: 'From place *')),
              const SizedBox(height: 10),
              TextField(
                  controller: fromState,
                  maxLength: 2,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'From state code *', counterText: '')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(
                      value: '1', child: Text('Transporter change')),
                  DropdownMenuItem(value: '2', child: Text('Breakdown')),
                  DropdownMenuItem(value: '3', child: Text('Transhipment')),
                  DropdownMenuItem(value: '4', child: Text('Other')),
                ],
                onChanged: (v) => setLocal(() => reason = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: remarks,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Remarks')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Back')),
            FilledButton(
              onPressed: () async {
                if (vehicle.text.trim().isEmpty ||
                    fromPlace.text.trim().isEmpty ||
                    fromState.text.trim().length != 2) {
                  showMessage(context,
                      'Vehicle, from place and 2-digit state code are required.',
                      error: true);
                  return;
                }
                try {
                  await widget.api
                      .post('/eway-bills/${row['id']}/vehicle', body: {
                    'vehicle_number':
                        vehicle.text.trim().replaceAll(' ', '').toUpperCase(),
                    'vehicle_type': vehicleType,
                    'from_place': fromPlace.text.trim(),
                    'from_state_code': fromState.text.trim(),
                    'reason_code': reason,
                    'reason_remarks': remarks.text.trim().isEmpty
                        ? null
                        : remarks.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted)
                    showMessage(context, e.toString(), error: true);
                }
              },
              child: const Text('Update vehicle'),
            ),
          ],
        ),
      ),
    );
    for (final c in [vehicle, fromPlace, fromState, remarks]) {
      c.dispose();
    }
    if (ok == true) {
      showMessage(context, 'Vehicle updated.');
      _load();
    }
  }

  Future<void> _consolidate() async {
    final active = _items
        .where((e) =>
            e['status'] == 'ACTIVE' &&
            (e['eway_bill_number']?.toString().isNotEmpty ?? false))
        .toList();
    if (active.length < 2) {
      showMessage(context,
          'Need at least two active numbered e-Way Bills to consolidate.',
          error: true);
      return;
    }
    final selected = <String>{};
    final vehicle = TextEditingController();
    final fromPlace = TextEditingController();
    final fromState = TextEditingController();
    var vehicleType = 'REGULAR';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Consolidated e-Way Bill'),
          content: SizedBox(
            width: 560,
            height: 480,
            child: Column(children: [
              TextField(
                  controller: vehicle,
                  textCapitalization: TextCapitalization.characters,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle number *')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: vehicleType,
                decoration: const InputDecoration(labelText: 'Vehicle type'),
                items: const [
                  DropdownMenuItem(value: 'REGULAR', child: Text('Regular')),
                  DropdownMenuItem(
                      value: 'ODC', child: Text('Over dimensional')),
                ],
                onChanged: (v) => setLocal(() => vehicleType = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: fromPlace,
                  decoration: const InputDecoration(labelText: 'From place *')),
              const SizedBox(height: 8),
              TextField(
                  controller: fromState,
                  maxLength: 2,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'From state code *', counterText: '')),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: active
                      .map((e) => CheckboxListTile(
                            value:
                                selected.contains('${e['eway_bill_number']}'),
                            title: Text('${e['eway_bill_number']}'),
                            subtitle: Text(
                                '${e['vehicle_number'] ?? ''} • ${titleCase('${e['supply_type'] ?? ''}')}'),
                            onChanged: (v) => setLocal(() {
                              final number = '${e['eway_bill_number']}';
                              if (v == true) {
                                selected.add(number);
                              } else {
                                selected.remove(number);
                              }
                            }),
                          ))
                      .toList(),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (selected.isEmpty ||
                    vehicle.text.trim().isEmpty ||
                    fromPlace.text.trim().isEmpty ||
                    fromState.text.trim().length != 2) {
                  showMessage(context,
                      'Select e-Way Bills and complete vehicle/place details.',
                      error: true);
                  return;
                }
                try {
                  await widget.api.post('/eway-bills/consolidated', body: {
                    'vehicle_number':
                        vehicle.text.trim().replaceAll(' ', '').toUpperCase(),
                    'vehicle_type': vehicleType,
                    'from_place': fromPlace.text.trim(),
                    'from_state_code': fromState.text.trim(),
                    'eway_bill_numbers': selected.toList(),
                  });
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted)
                    showMessage(context, e.toString(), error: true);
                }
              },
              child: const Text('Generate'),
            ),
          ],
        ),
      ),
    );
    for (final c in [vehicle, fromPlace, fromState]) {
      c.dispose();
    }
    if (ok == true) {
      showMessage(context, 'Consolidated e-Way Bill generated.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
        title: 'E-Way Bills',
        subtitle:
            'Transport compliance for qualifying movement of goods, with vehicle history, invoice/bill source and consolidation.',
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          OutlinedButton.icon(
              onPressed: _consolidate,
              icon: const Icon(Icons.merge_type_rounded),
              label: const Text('Consolidate')),
          FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Generate')),
        ],
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(60),
                child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? ErrorPanel(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.local_shipping_rounded,
                        title: 'No e-Way Bills',
                        message:
                            'Generate an e-Way Bill for eligible finalized goods invoices or bills.')
                    : Column(
                        children: _items
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: Card(
                                    child: ListTile(
                                      leading: const CircleAvatar(
                                          child: Icon(
                                              Icons.local_shipping_outlined)),
                                      title: Row(children: [
                                        Expanded(
                                            child: Text(
                                                '${e['eway_bill_number'] ?? 'Pending number'}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w800))),
                                        Chip(
                                            label:
                                                Text('${e['status'] ?? ''}')),
                                      ]),
                                      subtitle: Text(
                                        '${titleCase('${e['supply_type'] ?? ''}')} • ${e['invoice_id'] != null ? 'Invoice' : e['bill_id'] != null ? 'Bill' : 'Document'} • ${e['vehicle_number'] ?? ''} • ${e['trans_distance'] ?? 0} km\nValid until ${displayDate(e['valid_until'])}',
                                      ),
                                      isThreeLine: true,
                                      trailing: e['status'] == 'ACTIVE'
                                          ? PopupMenuButton<String>(
                                              onSelected: (v) {
                                                if (v == 'cancel') _cancel(e);
                                                if (v == 'vehicle')
                                                  _updateVehicle(e);
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                    value: 'vehicle',
                                                    child:
                                                        Text('Update vehicle')),
                                                PopupMenuItem(
                                                    value: 'cancel',
                                                    child: Text(
                                                        'Cancel e-Way Bill')),
                                              ],
                                            )
                                          : null,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
      );
}
