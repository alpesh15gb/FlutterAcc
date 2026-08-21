import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen(
      {super.key, required this.api, required this.initialTab});
  final ApiClient api;
  final String initialTab;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _tabIds = const [
    'warehouses',
    'transfers',
    'adjustments',
    'stock-ledger'
  ];

  @override
  void initState() {
    super.initState();
    final index = _tabIds.indexOf(widget.initialTab);
    _tabs = TabController(
        length: 4, vsync: this, initialIndex: index < 0 ? 0 : index);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'Inventory & Godowns',
      subtitle:
          'Warehouse stock, transfers, physical adjustments and an auditable movement ledger.',
      child: Column(children: [
        SectionCard(
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Warehouses'),
              Tab(text: 'Transfers'),
              Tab(text: 'Adjustments'),
              Tab(text: 'Stock Ledger'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: TabBarView(
            controller: _tabs,
            children: [
              _WarehousesTab(api: widget.api),
              _TransfersTab(api: widget.api),
              _AdjustmentsTab(api: widget.api),
              _StockLedgerTab(api: widget.api),
            ],
          ),
        ),
      ]),
    );
  }
}

List<Map<String, dynamic>> _rows(dynamic data) {
  if (data is List) {
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  if (data is Map) {
    for (final key in ['items', 'results', 'entries']) {
      final value = data[key];
      if (value is List) {
        return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
  }
  return [];
}

class _WarehousesTab extends StatefulWidget {
  const _WarehousesTab({required this.api});
  final ApiClient api;
  @override
  State<_WarehousesTab> createState() => _WarehousesTabState();
}

class _WarehousesTabState extends State<_WarehousesTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

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
      _items =
          _rows(await widget.api.get('/warehouses', query: {'limit': 100}));
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newWarehouse() async {
    final name = TextEditingController();
    final gstin = TextEditingController();
    final street = TextEditingController();
    final city = TextEditingController();
    final state = TextEditingController();
    final stateCode = TextEditingController();
    final pincode = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('New warehouse / godown'),
              content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(
                            labelText: 'Warehouse name *')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: gstin,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                            labelText: 'GSTIN (optional)')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: street,
                        decoration:
                            const InputDecoration(labelText: 'Address')),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: city,
                              decoration:
                                  const InputDecoration(labelText: 'City'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: state,
                              decoration:
                                  const InputDecoration(labelText: 'State'))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: stateCode,
                              maxLength: 2,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'GST state code',
                                  counterText: ''))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              controller: pincode,
                              maxLength: 6,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Pincode', counterText: ''))),
                    ]),
                  ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) {
                        showMessage(context, 'Warehouse name is required.',
                            error: true);
                        return;
                      }
                      try {
                        await widget.api.post('/warehouses', body: {
                          'name': name.text.trim(),
                          'gstin': gstin.text.trim().isEmpty
                              ? null
                              : gstin.text.trim().toUpperCase(),
                          'address': {
                            if (street.text.trim().isNotEmpty)
                              'street': street.text.trim(),
                            if (city.text.trim().isNotEmpty)
                              'city': city.text.trim(),
                            if (state.text.trim().isNotEmpty)
                              'state': state.text.trim(),
                            if (stateCode.text.trim().isNotEmpty)
                              'state_code': stateCode.text.trim(),
                            if (pincode.text.trim().isNotEmpty)
                              'pincode': pincode.text.trim(),
                            'country': 'India',
                          },
                          'is_active': true,
                        });
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        if (context.mounted) {
                          showMessage(context, e.toString(), error: true);
                        }
                      }
                    },
                    child: const Text('Create')),
              ],
            ));
    for (final c in [name, gstin, street, city, state, stateCode, pincode]) {
      c.dispose();
    }
    if (ok == true) {
      showMessage(context, 'Warehouse created.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          const Expanded(
              child: Text('Active stock locations',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          FilledButton.icon(
              onPressed: _newWarehouse,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New warehouse')),
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorPanel(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const EmptyState(
                            icon: Icons.warehouse_outlined,
                            title: 'No warehouses',
                            message:
                                'Create your first godown to track location-wise stock.')
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final w = _items[i];
                              final address = w['address'] is Map
                                  ? Map<String, dynamic>.from(
                                      w['address'] as Map)
                                  : <String, dynamic>{};
                              return Card(
                                  child: ListTile(
                                leading: CircleAvatar(
                                    child: Text('${w['name'] ?? 'W'}'
                                        .substring(0, 1)
                                        .toUpperCase())),
                                title: Text('${w['name'] ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text([
                                  w['gstin'],
                                  address['city'],
                                  address['state']
                                ]
                                    .where((e) => e != null && '$e'.isNotEmpty)
                                    .join(' • ')),
                                trailing: Wrap(
                                    spacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Chip(
                                          label: Text(w['is_active'] == false
                                              ? 'Inactive'
                                              : 'Active')),
                                      PopupMenuButton<String>(
                                        onSelected: (v) async {
                                          try {
                                            if (v == 'toggle') {
                                              await widget.api.put(
                                                  '/warehouses/${w['id']}',
                                                  body: {
                                                    'is_active':
                                                        w['is_active'] == false
                                                  });
                                            } else if (v == 'delete') {
                                              await widget.api.delete(
                                                  '/warehouses/${w['id']}');
                                            }
                                            _load();
                                          } catch (e) {
                                            if (mounted) {
                                              showMessage(context, e.toString(),
                                                  error: true);
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          PopupMenuItem(
                                              value: 'toggle',
                                              child: Text(
                                                  w['is_active'] == false
                                                      ? 'Activate'
                                                      : 'Deactivate')),
                                          const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete')),
                                        ],
                                      ),
                                    ]),
                              ));
                            })),
      ]);
}

class _TransfersTab extends StatefulWidget {
  const _TransfersTab({required this.api});
  final ApiClient api;
  @override
  State<_TransfersTab> createState() => _TransfersTabState();
}

class _TransfersTabState extends State<_TransfersTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
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
      _items = _rows(await widget.api.get('/transfers', query: {'limit': 100}));
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newTransfer() async {
    try {
      final warehouses =
          _rows(await widget.api.get('/warehouses', query: {'limit': 100}))
              .where((w) => w['is_active'] != false)
              .toList();
      final products = _rows(await widget.api.get('/masters/products',
          query: {'product_type': 'GOODS', 'limit': 100}));
      if (!mounted) return;
      if (warehouses.length < 2) {
        showMessage(context, 'Create at least two active warehouses first.',
            error: true);
        return;
      }
      if (products.isEmpty) {
        showMessage(context, 'Create at least one goods item first.',
            error: true);
        return;
      }
      String? from = '${warehouses.first['id']}';
      String? to = '${warehouses[1]['id']}';
      String? product = '${products.first['id']}';
      final number = TextEditingController();
      final qty = TextEditingController(text: '1');
      final notes = TextEditingController();
      var date = DateTime.now();
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
              builder: (context, setLocal) => AlertDialog(
                    title: const Text('New stock transfer'),
                    content: SizedBox(
                        width: 620,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: number,
                                  decoration: const InputDecoration(
                                      labelText: 'Transfer number',
                                      helperText:
                                          'Leave blank for automatic numbering')),
                              const SizedBox(height: 10),
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Transfer date'),
                                  subtitle: Text(isoDate(date)),
                                  trailing:
                                      const Icon(Icons.calendar_month_outlined),
                                  onTap: () async {
                                    final d = await pickDate(context, date);
                                    if (d != null) setLocal(() => date = d);
                                  }),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                  initialValue: from,
                                  decoration: const InputDecoration(
                                      labelText: 'From warehouse'),
                                  items: warehouses
                                      .map((w) => DropdownMenuItem(
                                          value: '${w['id']}',
                                          child: Text('${w['name']}')))
                                      .toList(),
                                  onChanged: (v) => setLocal(() => from = v)),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                  initialValue: to,
                                  decoration: const InputDecoration(
                                      labelText: 'To warehouse'),
                                  items: warehouses
                                      .map((w) => DropdownMenuItem(
                                          value: '${w['id']}',
                                          child: Text('${w['name']}')))
                                      .toList(),
                                  onChanged: (v) => setLocal(() => to = v)),
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                        initialValue: product,
                                        decoration: const InputDecoration(
                                            labelText: 'Item'),
                                        items: products
                                            .map((p) => DropdownMenuItem(
                                                value: '${p['id']}',
                                                child: Text('${p['name']}')))
                                            .toList(),
                                        onChanged: (v) =>
                                            setLocal(() => product = v))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextField(
                                        controller: qty,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                            labelText: 'Quantity')))
                              ]),
                              const SizedBox(height: 10),
                              TextField(
                                  controller: notes,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                      labelText: 'Notes')),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () async {
                            if (from == to) {
                              showMessage(context,
                                  'Source and destination must be different.',
                                  error: true);
                              return;
                            }
                            final q = double.tryParse(qty.text);
                            if (q == null || q <= 0) {
                              showMessage(context,
                                  'Enter a quantity greater than zero.',
                                  error: true);
                              return;
                            }
                            try {
                              await widget.api.post('/transfers', body: {
                                'transfer_number': number.text.trim().isEmpty
                                    ? null
                                    : number.text.trim(),
                                'transfer_date': isoDate(date),
                                'from_warehouse_id': from,
                                'to_warehouse_id': to,
                                'lines': [
                                  {'product_id': product, 'quantity': q}
                                ],
                                'notes': notes.text.trim().isEmpty
                                    ? null
                                    : notes.text.trim()
                              });
                              if (context.mounted) Navigator.pop(context, true);
                            } catch (e) {
                              if (context.mounted) {
                                showMessage(context, e.toString(), error: true);
                              }
                            }
                          },
                          child: const Text('Create draft'))
                    ],
                  )));
      number.dispose();
      qty.dispose();
      notes.dispose();
      if (ok == true) {
        showMessage(context, 'Transfer draft created.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _action(Map<String, dynamic> row, String action) async {
    try {
      await widget.api.post('/transfers/${row['id']}/$action');
      if (mounted) {
        showMessage(
            context,
            action == 'complete'
                ? 'Transfer completed and stock moved.'
                : 'Transfer cancelled.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          const Expanded(
              child: Text('Inter-godown transfers',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          FilledButton.icon(
              onPressed: _newTransfer,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New transfer'))
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorPanel(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const EmptyState(
                            icon: Icons.swap_horiz_rounded,
                            title: 'No transfers',
                            message:
                                'Transfers between godowns will appear here.')
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final t = _items[i];
                              final status = '${t['status'] ?? 'DRAFT'}';
                              return Card(
                                  child: ListTile(
                                      title: Text(
                                          '${t['transfer_number'] ?? ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                          '${t['transfer_date'] ?? ''} • ${t['from_warehouse_name'] ?? ''} → ${t['to_warehouse_name'] ?? ''}'),
                                      trailing: Wrap(
                                          spacing: 6,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Chip(label: Text(status)),
                                            if (status == 'DRAFT')
                                              PopupMenuButton<String>(
                                                  onSelected: (v) =>
                                                      _action(t, v),
                                                  itemBuilder: (_) => const [
                                                        PopupMenuItem(
                                                            value: 'complete',
                                                            child: Text(
                                                                'Complete transfer')),
                                                        PopupMenuItem(
                                                            value: 'cancel',
                                                            child: Text(
                                                                'Cancel transfer'))
                                                      ])
                                          ])));
                            }))
      ]);
}

class _AdjustmentsTab extends StatefulWidget {
  const _AdjustmentsTab({required this.api});
  final ApiClient api;
  @override
  State<_AdjustmentsTab> createState() => _AdjustmentsTabState();
}

class _AdjustmentsTabState extends State<_AdjustmentsTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
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
      _items = _rows(await widget.api
          .get('/inventory-adjustments', query: {'limit': 100}));
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _new() async {
    try {
      final products = _rows(await widget.api.get('/masters/products',
          query: {'product_type': 'GOODS', 'limit': 100}));
      if (!mounted) return;
      if (products.isEmpty) {
        showMessage(context, 'Create a goods item first.', error: true);
        return;
      }
      String? product = '${products.first['id']}';
      final number = TextEditingController(
          text:
              'ADJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
      final qty = TextEditingController();
      final cost = TextEditingController();
      final reason = TextEditingController();
      var date = DateTime.now();
      final ok = await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
              builder: (context, setLocal) => AlertDialog(
                      title: const Text('New stock adjustment'),
                      content: SizedBox(
                          width: 600,
                          child: SingleChildScrollView(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                TextField(
                                    controller: number,
                                    decoration: const InputDecoration(
                                        labelText: 'Adjustment number *')),
                                const SizedBox(height: 10),
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Date'),
                                    subtitle: Text(isoDate(date)),
                                    trailing: const Icon(
                                        Icons.calendar_month_outlined),
                                    onTap: () async {
                                      final d = await pickDate(context, date);
                                      if (d != null) setLocal(() => date = d);
                                    }),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                    initialValue: product,
                                    decoration: const InputDecoration(
                                        labelText: 'Item'),
                                    items: products
                                        .map((p) => DropdownMenuItem(
                                            value: '${p['id']}',
                                            child: Text('${p['name']}')))
                                        .toList(),
                                    onChanged: (v) =>
                                        setLocal(() => product = v)),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Expanded(
                                      child: TextField(
                                          controller: qty,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                              decimal: true, signed: true),
                                          decoration: const InputDecoration(
                                              labelText: 'Quantity change',
                                              helperText:
                                                  '+ increase, − decrease'))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: TextField(
                                          controller: cost,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                              labelText: 'Unit cost',
                                              helperText:
                                                  'Blank uses purchase price')))
                                ]),
                                const SizedBox(height: 10),
                                TextField(
                                    controller: reason,
                                    maxLines: 2,
                                    decoration: const InputDecoration(
                                        labelText: 'Reason *'))
                              ]))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () async {
                              final q = double.tryParse(qty.text);
                              if (q == null ||
                                  q == 0 ||
                                  reason.text.trim().isEmpty ||
                                  number.text.trim().isEmpty) {
                                showMessage(context,
                                    'Number, non-zero quantity and reason are required.',
                                    error: true);
                                return;
                              }
                              try {
                                await widget.api
                                    .post('/inventory-adjustments', body: {
                                  'adjustment_number': number.text.trim(),
                                  'adjustment_date': isoDate(date),
                                  'reason': reason.text.trim(),
                                  'line_items': [
                                    {
                                      'product_id': product,
                                      'quantity_change': q,
                                      'unit_cost': cost.text.trim().isEmpty
                                          ? null
                                          : double.tryParse(cost.text)
                                    }
                                  ]
                                });
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showMessage(context, e.toString(),
                                      error: true);
                                }
                              }
                            },
                            child: const Text('Create draft'))
                      ])));
      number.dispose();
      qty.dispose();
      cost.dispose();
      reason.dispose();
      if (ok == true) {
        showMessage(context, 'Adjustment draft created.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _confirm(Map<String, dynamic> a) async {
    try {
      await widget.api.post('/inventory-adjustments/${a['id']}/confirm');
      if (mounted) {
        showMessage(context, 'Stock adjustment confirmed and posted.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  Future<void> _cancelAdj(Map<String, dynamic> a) async {
    try {
      await widget.api.post('/inventory-adjustments/${a['id']}/cancel');
      if (mounted) {
        showMessage(context, 'Stock adjustment cancelled.');
        _load();
      }
    } catch (e) {
      if (mounted) showMessage(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          const Expanded(
              child: Text('Physical stock corrections',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 6),
          FilledButton.icon(
              onPressed: _new,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New adjustment'))
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorPanel(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const EmptyState(
                            icon: Icons.tune_rounded,
                            title: 'No adjustments',
                            message:
                                'Damage, shrinkage and physical count corrections appear here.')
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final a = _items[i];
                              final status = '${a['status'] ?? ''}';
                              return Card(
                                  child: ListTile(
                                      title: Text(
                                          '${a['adjustment_number'] ?? ''}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      subtitle: Text(
                                          '${a['adjustment_date'] ?? ''}${a['reason'] != null ? ' • ${a['reason']}' : ''}'),
                                      trailing: Wrap(
                                          spacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Chip(label: Text(status)),
                                            if (status == 'DRAFT')
                                              FilledButton.tonal(
                                                  onPressed: () => _confirm(a),
                                                  child: const Text('Confirm')),
                                            if (status == 'DRAFT')
                                              TextButton(
                                                  onPressed: () =>
                                                      _cancelAdj(a),
                                                  child: const Text('Cancel'))
                                          ])));
                            }))
      ]);
}

class _StockLedgerTab extends StatefulWidget {
  const _StockLedgerTab({required this.api});
  final ApiClient api;
  @override
  State<_StockLedgerTab> createState() => _StockLedgerTabState();
}

class _StockLedgerTabState extends State<_StockLedgerTab> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
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
      _items =
          _rows(await widget.api.get('/stock-ledger', query: {'limit': 100}));
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          const Expanded(
              child: Text('Latest stock movements',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorPanel(message: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? const EmptyState(
                            icon: Icons.list_alt_rounded,
                            title: 'No stock movements',
                            message:
                                'Posted invoices, bills, transfers and adjustments will populate the stock ledger.')
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = _items[i];
                              final q =
                                  double.tryParse('${r['quantity'] ?? 0}') ?? 0;
                              return ListTile(
                                  leading: Icon(
                                      q < 0
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: q < 0
                                          ? AppColors.danger
                                          : AppColors.success),
                                  title: Text('${r['product_name'] ?? ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                      '${r['warehouse_name'] ?? 'Default warehouse'} • ${r['reference_type'] ?? ''} • ${r['created_at'] ?? ''}'),
                                  trailing: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            '${q > 0 ? '+' : ''}${formatNumber(q)}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800)),
                                        Text(
                                            'Bal ${formatNumber(r['balance_quantity'])}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.muted))
                                      ]));
                            }))
      ]);
}
