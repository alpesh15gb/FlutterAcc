import 'package:flutter/material.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/workspace_catalog.dart';
import '../accounting/accounting_screen.dart';
import '../banking/banking_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../eway/eway_bills_screen.dart';
import '../expenses/expenses_screen.dart';
import '../financial_years/financial_years_screen.dart';
import '../gst/gst_center_screen.dart';
import '../imports/import_tools_screen.dart';
import '../inventory/inventory_screen.dart';
import '../masters/contacts_screen.dart';
import '../masters/master_data_screen.dart';
import '../masters/products_screen.dart';
import '../notes/notes_screen.dart';
import '../payments/payments_screen.dart';
import '../purchases/goods_receipts_screen.dart';
import '../recurring/recurring_invoices_screen.dart';
import '../reminders/reminders_screen.dart';
import '../reports/reports_screen.dart';
import '../returns/returns_screen.dart';
import '../sales/invoices_screen.dart';
import '../settings/settings_screen.dart';
import '../tools/compliance_tools_screen.dart';
import '../workspaces/data_workspace_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell(
      {super.key,
      required this.session,
      required this.themeMode,
      required this.onThemeModeChanged});
  final SessionController session;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selected = 'dashboard';

  static const _groups = <_NavGroup>[
    _NavGroup('Overview', [
      _NavItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined),
      _NavItem('reminders', 'Reminders', Icons.notifications_outlined),
      _NavItem('contacts', 'Parties', Icons.people_alt_outlined),
      _NavItem('products', 'Items', Icons.inventory_2_outlined),
      _NavItem('masters', 'Master data', Icons.tune_outlined),
    ]),
    _NavGroup('Sales', [
      _NavItem('invoices', 'Invoices', Icons.receipt_long_outlined),
      _NavItem(
          'proforma', 'Quotations / Proforma', Icons.request_quote_outlined),
      _NavItem('sales-orders', 'Sales Orders', Icons.shopping_bag_outlined),
      _NavItem('challans', 'Delivery Challans', Icons.local_shipping_outlined),
      _NavItem('recurring', 'Recurring Invoices', Icons.autorenew_rounded),
      _NavItem(
          'credit-notes', 'Credit Notes', Icons.assignment_return_outlined),
      _NavItem('debit-notes', 'Debit Notes', Icons.note_add_outlined),
      _NavItem('sales-returns', 'Sales Returns', Icons.keyboard_return_rounded),
    ]),
    _NavGroup('Purchases', [
      _NavItem('bills', 'Purchase Bills', Icons.receipt_outlined),
      _NavItem('purchase-orders', 'Purchase Orders', Icons.assignment_outlined),
      _NavItem(
          'goods-receipts', 'Goods Receipts', Icons.move_to_inbox_outlined),
      _NavItem('bill-payments', 'Vendor Payments', Icons.outbox_outlined),
      _NavItem('purchase-returns', 'Purchase Returns',
          Icons.assignment_return_rounded),
      _NavItem('expenses', 'Expenses', Icons.payments_outlined),
    ]),
    _NavGroup('Inventory', [
      _NavItem('warehouses', 'Warehouses / Godowns', Icons.warehouse_outlined),
      _NavItem('transfers', 'Stock Transfers', Icons.swap_horiz_rounded),
      _NavItem('adjustments', 'Stock Adjustments', Icons.tune_rounded),
      _NavItem('stock-ledger', 'Stock Ledger', Icons.list_alt_rounded),
    ]),
    _NavGroup('Money & Books', [
      _NavItem('payments', 'Customer Receipts',
          Icons.account_balance_wallet_outlined),
      _NavItem('banking', 'Banking & Reconciliation',
          Icons.account_balance_outlined),
      _NavItem('accounting', 'Accounting', Icons.menu_book_outlined),
    ]),
    _NavGroup('Compliance', [
      _NavItem('gst', 'GST Center', Icons.verified_outlined),
      _NavItem('eway-bills', 'E-Way Bills', Icons.local_shipping_rounded),
      _NavItem('compliance-tools', 'GSTIN / HSN tools', Icons.policy_outlined),
      _NavItem('reports', 'Reports', Icons.analytics_outlined),
    ]),
    _NavGroup('Administration', [
      _NavItem(
          'financial-years', 'Financial Years', Icons.calendar_month_outlined),
      _NavItem('audit', 'Audit Log', Icons.manage_search_rounded),
      _NavItem('imports', 'Import & Migration', Icons.upload_file_outlined),
      _NavItem('settings', 'Settings', Icons.settings_outlined),
    ]),
  ];

  void _select(String id) {
    setState(() => _selected = id);
    if (Navigator.canPop(context)) Navigator.maybePop(context);
  }

  Widget _screen() {
    final api = widget.session.api;
    return switch (_selected) {
      'dashboard' => DashboardScreen(
          api: api,
          onNavigate: _select,
          companyName: widget.session.tenantName ?? 'Company'),
      'reminders' => RemindersScreen(api: api),
      'contacts' => ContactsScreen(api: api),
      'products' => ProductsScreen(api: api),
      'masters' => MasterDataScreen(api: api),
      'invoices' => InvoicesScreen(api: api),
      'recurring' => RecurringInvoicesScreen(api: api),
      'credit-notes' => NotesScreen(api: api, credit: true),
      'debit-notes' => NotesScreen(api: api, credit: false),
      'sales-returns' => ReturnsScreen(api: api, purchase: false),
      'purchase-returns' => ReturnsScreen(api: api, purchase: true),
      'goods-receipts' => GoodsReceiptsScreen(api: api),
      'bill-payments' => PaymentsScreen(api: api, vendor: true),
      'payments' => PaymentsScreen(api: api, vendor: false),
      'expenses' => ExpensesScreen(api: api),
      'warehouses' => InventoryScreen(api: api, initialTab: 'warehouses'),
      'transfers' => InventoryScreen(api: api, initialTab: 'transfers'),
      'adjustments' => InventoryScreen(api: api, initialTab: 'adjustments'),
      'stock-ledger' => InventoryScreen(api: api, initialTab: 'stock-ledger'),
      'gst' => GstCenterScreen(api: api),
      'eway-bills' => EWayBillsScreen(api: api),
      'compliance-tools' => ComplianceToolsScreen(api: api),
      'reports' => ReportsScreen(api: api),
      'accounting' => AccountingScreen(api: api),
      'banking' => BankingScreen(api: api),
      'financial-years' => FinancialYearsScreen(api: api),
      'imports' => ImportToolsScreen(api: api),
      'settings' => SettingsScreen(api: api, session: widget.session),
      _ => workspaceCatalog.containsKey(_selected)
          ? DataWorkspaceScreen(api: api, config: workspaceCatalog[_selected]!)
          : _MissingScreen(id: _selected),
    };
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final desktop = c.maxWidth >= 1180;
        final tablet = c.maxWidth >= 760 && !desktop;
        if (desktop) {
          return Scaffold(
              body: Row(children: [
            SizedBox(
                width: 278,
                child: _SideNavigation(
                    selected: _selected,
                    groups: _groups,
                    onSelect: _select,
                    session: widget.session)),
            const VerticalDivider(width: 1),
            Expanded(
                child: Column(children: [
              _TopBar(
                  session: widget.session,
                  themeMode: widget.themeMode,
                  onThemeModeChanged: widget.onThemeModeChanged,
                  onMenu: null),
              Expanded(
                  child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: _screen()))
            ]))
          ]));
        }
        if (tablet) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
                child: SafeArea(
                    child: _SideNavigation(
                        selected: _selected,
                        groups: _groups,
                        onSelect: _select,
                        session: widget.session,
                        compactHeader: true))),
            body: Column(children: [
              _TopBar(
                  session: widget.session,
                  themeMode: widget.themeMode,
                  onThemeModeChanged: widget.onThemeModeChanged,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer()),
              Expanded(child: _screen()),
            ]),
          );
        }
        final bottomIds = ['dashboard', 'invoices', 'bills', 'contacts'];
        final bottomIndex = bottomIds.indexOf(_selected);
        return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
                titleSpacing: 8,
                title: Row(children: [
                  const _BrandMark(compact: true),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(widget.session.tenantName ?? 'ApexBooks',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)))
                ]),
                actions: [
                  _ThemeButton(
                      themeMode: widget.themeMode,
                      onChanged: widget.onThemeModeChanged),
                  PopupMenuButton<String>(
                      icon: CircleAvatar(
                          radius: 16,
                          child: Text(_initials(widget.session.userName ??
                              widget.session.userEmail ??
                              'U'))),
                      onSelected: (v) {
                        if (v == 'switch') widget.session.switchCompany();
                        if (v == 'logout') widget.session.logout();
                      },
                      itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'switch',
                                child: ListTile(
                                    leading: Icon(Icons.swap_horiz_rounded),
                                    title: Text('Switch company'))),
                            PopupMenuItem(
                                value: 'logout',
                                child: ListTile(
                                    leading: Icon(Icons.logout_rounded),
                                    title: Text('Sign out')))
                          ])
                ]),
            drawer: Drawer(
                child: SafeArea(
                    child: _SideNavigation(
                        selected: _selected,
                        groups: _groups,
                        onSelect: _select,
                        session: widget.session,
                        compactHeader: true))),
            body: _screen(),
            bottomNavigationBar: NavigationBar(
                selectedIndex: bottomIndex < 0 ? 4 : bottomIndex,
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined), label: 'Sales'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_outlined), label: 'Bills'),
                  NavigationDestination(
                      icon: Icon(Icons.people_alt_outlined), label: 'Parties'),
                  NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded), label: 'More')
                ],
                onDestinationSelected: (i) {
                  if (i < 4) {
                    _select(bottomIds[i]);
                  } else {
                    _scaffoldKey.currentState?.openDrawer();
                  }
                }));
      });
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation(
      {required this.selected,
      required this.groups,
      required this.onSelect,
      required this.session,
      this.compactHeader = false});
  final String selected;
  final List<_NavGroup> groups;
  final ValueChanged<String> onSelect;
  final SessionController session;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final role = session.memberships
            .where((m) => m.tenantName == session.tenantName)
            .map((m) => m.role)
            .firstOrNull ??
        'member';
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, compactHeader ? 10 : 22, 14, 12),
            child: const Row(children: [
              _BrandMark(),
              SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('ApexBooks',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('GST Accounting',
                        style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.business_outlined,
                    size: 19, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(session.tenantName ?? 'Company',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(role,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 11)),
                    ])),
                if (session.memberships.length > 1)
                  IconButton(
                      tooltip: 'Switch company',
                      onPressed: session.switchCompany,
                      icon: const Icon(Icons.unfold_more_rounded, size: 18)),
              ]),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 20),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 5),
                    child: Text(group.label.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.muted,
                            letterSpacing: .7)),
                  ),
                  ...group.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          dense: true,
                          selected: selected == item.id,
                          selectedTileColor:
                              AppColors.primary.withValues(alpha: .08),
                          selectedColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          leading: Icon(item.icon, size: 20),
                          title: Text(item.label,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected == item.id
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          onTap: () => onSelect(item.id),
                        ),
                      )),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: ListTile(
              leading: CircleAvatar(
                  child: Text(
                      _initials(session.userName ?? session.userEmail ?? 'U'))),
              title: Text(session.userName ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(session.userEmail ?? '',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                  tooltip: 'Sign out',
                  onPressed: session.logout,
                  icon: const Icon(Icons.logout_rounded)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.session,
      required this.themeMode,
      required this.onThemeModeChanged,
      required this.onMenu});
  final SessionController session;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(children: [
            if (onMenu != null)
              IconButton(
                  onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
            Expanded(
                child: Row(children: [
              const Icon(Icons.business_outlined,
                  size: 20, color: AppColors.muted),
              const SizedBox(width: 7),
              Text(session.tenantName ?? 'Company',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (session.memberships.length > 1)
                IconButton(
                    tooltip: 'Switch company',
                    onPressed: session.switchCompany,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 19)),
            ])),
            _ThemeButton(themeMode: themeMode, onChanged: onThemeModeChanged),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'switch') session.switchCompany();
                if (value == 'logout') session.logout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'switch', child: Text('Switch company')),
                PopupMenuItem(value: 'logout', child: Text('Sign out')),
              ],
              child: Chip(
                avatar: CircleAvatar(
                    child: Text(
                        _initials(session.userName ?? session.userEmail ?? 'U'),
                        style: const TextStyle(fontSize: 10))),
                label: Text(session.userName ?? 'Account'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  const _ThemeButton({required this.themeMode, required this.onChanged});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: 'Theme',
      onPressed: () => onChanged(
          themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(themeMode == ThemeMode.dark
          ? Icons.light_mode_outlined
          : Icons.dark_mode_outlined));
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Container(
      width: compact ? 32 : 38,
      height: compact ? 32 : 38,
      decoration: BoxDecoration(
          color: AppColors.primary, borderRadius: BorderRadius.circular(11)),
      alignment: Alignment.center,
      child: Text('A',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: compact ? 18 : 21)));
}

class _MissingScreen extends StatelessWidget {
  const _MissingScreen({required this.id});
  final String id;
  @override
  Widget build(BuildContext context) =>
      Center(child: Text('Screen not configured: $id'));
}

class _NavGroup {
  const _NavGroup(this.label, this.items);
  final String label;
  final List<_NavItem> items;
}

class _NavItem {
  const _NavItem(this.id, this.label, this.icon);
  final String id, label;
  final IconData icon;
}

String _initials(String value) {
  final p =
      value.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return 'U';
  return p.take(2).map((x) => x[0].toUpperCase()).join();
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final i = iterator;
    return i.moveNext() ? i.current : null;
  }
}
