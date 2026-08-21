import 'package:flutter/material.dart';

enum WorkspaceEditor { none, generic, taxDocument }

enum WorkspaceFieldType { text, number, date, toggle, select }

class WorkspaceField {
  const WorkspaceField(
    this.key,
    this.label, {
    this.type = WorkspaceFieldType.text,
    this.required = false,
    this.options = const [],
    this.defaultValue,
  });

  final String key;
  final String label;
  final WorkspaceFieldType type;
  final bool required;
  final List<String> options;
  final Object? defaultValue;
}

class WorkspaceColumn {
  const WorkspaceColumn(this.key, this.label,
      {this.money = false, this.date = false, this.status = false});
  final String key;
  final String label;
  final bool money;
  final bool date;
  final bool status;
}

class WorkspaceConfig {
  const WorkspaceConfig({
    required this.id,
    required this.title,
    required this.endpoint,
    required this.icon,
    required this.columns,
    this.subtitle,
    this.editor = WorkspaceEditor.none,
    this.fields = const [],
    this.documentKind,
    this.searchHint = 'Search',
  });

  final String id;
  final String title;
  final String endpoint;
  final IconData icon;
  final List<WorkspaceColumn> columns;
  final String? subtitle;
  final WorkspaceEditor editor;
  final List<WorkspaceField> fields;
  final String? documentKind;
  final String searchHint;
}

const workspaceCatalog = <String, WorkspaceConfig>{
  'proforma': WorkspaceConfig(
    id: 'proforma',
    title: 'Quotations / Proforma',
    endpoint: '/proforma-invoices',
    icon: Icons.request_quote_outlined,
    subtitle:
        'Issue estimates and convert accepted documents into orders or invoices.',
    editor: WorkspaceEditor.taxDocument,
    documentKind: 'proforma',
    columns: [
      WorkspaceColumn('proforma_number', 'Number'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('issue_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'sales-orders': WorkspaceConfig(
    id: 'sales-orders',
    title: 'Sales Orders',
    endpoint: '/sales-orders',
    icon: Icons.shopping_bag_outlined,
    subtitle: 'Track customer commitments before fulfilment and invoicing.',
    editor: WorkspaceEditor.taxDocument,
    documentKind: 'salesOrder',
    columns: [
      WorkspaceColumn('so_number', 'Order'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('order_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'challans': WorkspaceConfig(
    id: 'challans',
    title: 'Delivery Challans',
    endpoint: '/delivery-challans',
    icon: Icons.local_shipping_outlined,
    subtitle:
        'Move goods against customer delivery documents and later convert to invoices.',
    editor: WorkspaceEditor.taxDocument,
    documentKind: 'challan',
    columns: [
      WorkspaceColumn('challan_number', 'Challan'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('challan_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Value', money: true)
    ],
  ),
  'recurring': WorkspaceConfig(
    id: 'recurring',
    title: 'Recurring Invoices',
    endpoint: '/recurring-invoices',
    icon: Icons.autorenew_rounded,
    subtitle: 'Templates and schedules for repeat billing.',
    columns: [
      WorkspaceColumn('name', 'Template'),
      WorkspaceColumn('frequency', 'Frequency'),
      WorkspaceColumn('next_run_date', 'Next run', date: true),
      WorkspaceColumn('is_active', 'Active')
    ],
  ),
  'credit-notes': WorkspaceConfig(
    id: 'credit-notes',
    title: 'Credit Notes',
    endpoint: '/invoices/credit-notes',
    icon: Icons.assignment_return_outlined,
    subtitle:
        'Sales value reductions and stock returns linked to posted invoices.',
    columns: [
      WorkspaceColumn('credit_note_number', 'Number'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('issue_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'debit-notes': WorkspaceConfig(
    id: 'debit-notes',
    title: 'Debit Notes',
    endpoint: '/invoices/debit-notes',
    icon: Icons.note_add_outlined,
    subtitle: 'Additional debit adjustments against customer transactions.',
    columns: [
      WorkspaceColumn('debit_note_number', 'Number'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('issue_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'sales-returns': WorkspaceConfig(
    id: 'sales-returns',
    title: 'Sales Returns',
    endpoint: '/returns/sales',
    icon: Icons.keyboard_return_rounded,
    subtitle: 'Customer returns with document and stock traceability.',
    columns: [
      WorkspaceColumn('return_number', 'Return'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('return_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'bills': WorkspaceConfig(
    id: 'bills',
    title: 'Purchase Bills',
    endpoint: '/bills',
    icon: Icons.receipt_outlined,
    subtitle: 'Vendor bills, input GST, ITC eligibility and payables.',
    editor: WorkspaceEditor.taxDocument,
    documentKind: 'bill',
    columns: [
      WorkspaceColumn('bill_number', 'Bill'),
      WorkspaceColumn('contact_name', 'Vendor'),
      WorkspaceColumn('issue_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true),
      WorkspaceColumn('amount_paid', 'Paid', money: true)
    ],
  ),
  'purchase-orders': WorkspaceConfig(
    id: 'purchase-orders',
    title: 'Purchase Orders',
    endpoint: '/purchase-orders',
    icon: Icons.assignment_outlined,
    subtitle: 'Plan vendor purchases before goods receipt and billing.',
    editor: WorkspaceEditor.taxDocument,
    documentKind: 'purchaseOrder',
    columns: [
      WorkspaceColumn('po_number', 'PO'),
      WorkspaceColumn('contact_name', 'Vendor'),
      WorkspaceColumn('order_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'goods-receipts': WorkspaceConfig(
    id: 'goods-receipts',
    title: 'Goods Receipts',
    endpoint: '/goods-receipts',
    icon: Icons.move_to_inbox_outlined,
    subtitle: 'Record warehouse receipt against purchase orders.',
    columns: [
      WorkspaceColumn('receipt_number', 'GRN'),
      WorkspaceColumn('vendor_name', 'Vendor'),
      WorkspaceColumn('receipt_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'bill-payments': WorkspaceConfig(
    id: 'bill-payments',
    title: 'Vendor Payments',
    endpoint: '/payments/disbursements',
    icon: Icons.outbox_outlined,
    subtitle: 'Vendor disbursements and bill allocations.',
    columns: [
      WorkspaceColumn('payment_number', 'Payment'),
      WorkspaceColumn('contact_name', 'Vendor'),
      WorkspaceColumn('payment_date', 'Date', date: true),
      WorkspaceColumn('payment_mode', 'Mode'),
      WorkspaceColumn('amount', 'Amount', money: true),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'purchase-returns': WorkspaceConfig(
    id: 'purchase-returns',
    title: 'Purchase Returns',
    endpoint: '/returns/purchase',
    icon: Icons.assignment_return_rounded,
    subtitle:
        'Return purchased goods to suppliers and reverse input GST/stock.',
    columns: [
      WorkspaceColumn('return_number', 'Return'),
      WorkspaceColumn('contact_name', 'Vendor'),
      WorkspaceColumn('return_date', 'Date', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('total', 'Total', money: true)
    ],
  ),
  'expenses': WorkspaceConfig(
    id: 'expenses',
    title: 'Expenses',
    endpoint: '/expenses',
    icon: Icons.payments_outlined,
    subtitle: 'Operating expenses with GST and ledger posting.',
    columns: [
      WorkspaceColumn('expense_number', 'Expense'),
      WorkspaceColumn('expense_date', 'Date', date: true),
      WorkspaceColumn('vendor_name', 'Vendor'),
      WorkspaceColumn('description', 'Description'),
      WorkspaceColumn('total', 'Total', money: true),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'warehouses': WorkspaceConfig(
    id: 'warehouses',
    title: 'Warehouses / Godowns',
    endpoint: '/warehouses',
    icon: Icons.warehouse_outlined,
    subtitle: 'Stock locations, branch identity and GST-aware operations.',
    columns: [
      WorkspaceColumn('name', 'Warehouse'),
      WorkspaceColumn('code', 'Code'),
      WorkspaceColumn('gstin', 'GSTIN'),
      WorkspaceColumn('is_active', 'Active')
    ],
  ),
  'transfers': WorkspaceConfig(
    id: 'transfers',
    title: 'Stock Transfers',
    endpoint: '/transfers',
    icon: Icons.swap_horiz_rounded,
    subtitle:
        'Move inventory between active godowns with a traceable stock ledger.',
    columns: [
      WorkspaceColumn('transfer_number', 'Transfer'),
      WorkspaceColumn('transfer_date', 'Date', date: true),
      WorkspaceColumn('from_warehouse_name', 'From'),
      WorkspaceColumn('to_warehouse_name', 'To'),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'adjustments': WorkspaceConfig(
    id: 'adjustments',
    title: 'Stock Adjustments',
    endpoint: '/inventory-adjustments',
    icon: Icons.tune_rounded,
    subtitle:
        'Physical stock corrections, damage, shrinkage and opening corrections.',
    columns: [
      WorkspaceColumn('adjustment_number', 'Adjustment'),
      WorkspaceColumn('adjustment_date', 'Date', date: true),
      WorkspaceColumn('reason', 'Reason'),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'stock-ledger': WorkspaceConfig(
    id: 'stock-ledger',
    title: 'Stock Ledger',
    endpoint: '/stock-ledger',
    icon: Icons.list_alt_rounded,
    subtitle: 'Auditable movement history by item and warehouse.',
    columns: [
      WorkspaceColumn('created_at', 'Date', date: true),
      WorkspaceColumn('product_name', 'Item'),
      WorkspaceColumn('warehouse_name', 'Warehouse'),
      WorkspaceColumn('reference_type', 'Reference'),
      WorkspaceColumn('quantity', 'Qty'),
      WorkspaceColumn('balance_quantity', 'Balance')
    ],
  ),
  'payments': WorkspaceConfig(
    id: 'payments',
    title: 'Customer Receipts',
    endpoint: '/payments/receipts',
    icon: Icons.account_balance_wallet_outlined,
    subtitle:
        'Collections received from customers and allocations against invoices.',
    columns: [
      WorkspaceColumn('payment_number', 'Receipt'),
      WorkspaceColumn('contact_name', 'Customer'),
      WorkspaceColumn('payment_date', 'Date', date: true),
      WorkspaceColumn('payment_mode', 'Mode'),
      WorkspaceColumn('amount', 'Amount', money: true),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'eway-bills': WorkspaceConfig(
    id: 'eway-bills',
    title: 'E-Way Bills',
    endpoint: '/eway-bills',
    icon: Icons.local_shipping_rounded,
    subtitle: 'Transport compliance, validity and document references.',
    columns: [
      WorkspaceColumn('eway_bill_number', 'E-Way Bill'),
      WorkspaceColumn('document_number', 'Document'),
      WorkspaceColumn('generated_date', 'Generated', date: true),
      WorkspaceColumn('status', 'Status', status: true)
    ],
  ),
  'financial-years': WorkspaceConfig(
    id: 'financial-years',
    title: 'Financial Years',
    endpoint: '/financial-years',
    icon: Icons.calendar_month_outlined,
    subtitle: 'Current year, period control and year-end status.',
    columns: [
      WorkspaceColumn('name', 'Financial year'),
      WorkspaceColumn('start_date', 'Starts', date: true),
      WorkspaceColumn('end_date', 'Ends', date: true),
      WorkspaceColumn('status', 'Status', status: true),
      WorkspaceColumn('is_current', 'Current')
    ],
  ),
  'audit': WorkspaceConfig(
    id: 'audit',
    title: 'Audit Log',
    endpoint: '/audit',
    icon: Icons.manage_search_rounded,
    subtitle: 'Immutable operational and accounting activity trail.',
    columns: [
      WorkspaceColumn('created_at', 'When', date: true),
      WorkspaceColumn('action', 'Action'),
      WorkspaceColumn('entity_type', 'Entity'),
      WorkspaceColumn('actor_email', 'User')
    ],
  ),
};
