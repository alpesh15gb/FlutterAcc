# Backend coverage status

Reviewed against the current `Bookkeeping` FastAPI `master` branch on **21 Aug 2026**.

## Coverage definition

“Covered” means a tenant-facing capability is reachable from Flutter through a dedicated screen (or the tax-document / data workspace that implements that workflow), with request shapes and lifecycle actions based on the backend contract.

## Tenant-facing router coverage

| Backend router / capability | Flutter surface | Status |
|---|---|---|
| Auth / memberships / 2FA | AuthGate + login/register/recovery/company selector/2FA | Covered |
| Dashboard | DashboardScreen | Covered |
| Reminders | RemindersScreen | Covered (live overdue + daily summary; acknowledge is a no-op on the backend) |
| Contacts | ContactsScreen | Covered: create/edit/activate/deactivate/delete |
| Products | ProductsScreen | Covered: create/edit/activate/deactivate/delete; barcode searchable |
| Masters: accounts | AccountingScreen | Covered: create/edit/deactivate/delete/seed/dedupe |
| Masters: banking profiles | BankingScreen | Covered: create/edit/deactivate/delete |
| Masters: expense categories | MasterDataScreen + ExpensesScreen | Covered |
| Masters: tax templates | MasterDataScreen | Covered |
| Masters: payment terms | MasterDataScreen | Covered (backend is read-only) |
| Invoices | InvoicesScreen + TaxDocumentEditorScreen | Covered: draft/edit/finalize/cancel/clone/PDF/e-invoice |
| Credit / debit notes | NotesScreen | Covered: create draft, finalize, cancel, delete draft |
| Proforma invoices | DataWorkspaceScreen + TaxDocumentEditorScreen | Covered |
| Sales orders | DataWorkspaceScreen + TaxDocumentEditorScreen | Covered |
| Delivery challans | DataWorkspaceScreen + TaxDocumentEditorScreen | Covered |
| Recurring invoices | RecurringInvoicesScreen | Covered: create/pause/activate/delete/generate |
| Bills | DataWorkspaceScreen + TaxDocumentEditorScreen | Covered |
| Bill OCR | BillScanScreen (from purchase bills workspace) | Covered |
| Purchase orders | DataWorkspaceScreen + TaxDocumentEditorScreen | Covered |
| Goods receipts | GoodsReceiptsScreen | Covered: create/confirm/cancel |
| Sales / purchase returns | ReturnsScreen | Covered |
| Receipts / disbursements | PaymentsScreen | Covered: outstanding allocation/detail/cancel |
| Expenses | ExpensesScreen | Covered: preview/create/detail/draft edit/post/cancel/clone |
| Warehouses | InventoryScreen | Covered: create/activate/deactivate/delete |
| Transfers | InventoryScreen | Covered: create draft/complete/cancel |
| Inventory adjustments | InventoryScreen | Covered: create draft/confirm/cancel |
| Stock ledger | InventoryScreen | Covered |
| Bank reconciliation | BankingScreen | Covered: import/stats/transactions/suggestions/manual match/auto-match/undo |
| Journals / contra | AccountingScreen | Covered: manual posting/contra/detail/reversal |
| Financial years | FinancialYearsScreen | Covered: create/switch/readiness/close/reopen |
| Accounting periods | FinancialYearsScreen | Covered: list/lock/unlock |
| GST reports / filing status | GstCenterScreen | Covered |
| GSTR-2A/2B reconciliation | GstCenterScreen | Covered via `/gst/gstr2a/upload` |
| GSTIN / HSN utilities | ComplianceToolsScreen (from GST/tools entry points) | Present as a dedicated screen |
| E-way bills | EWayBillsScreen | Covered: invoice or bill source, cancel, vehicle update, consolidated |
| Reports | ReportsScreen | Covered: financial, analytics, aging, outstanding, GST and exports |
| Companies / branches / settings | SettingsScreen | Covered |
| Numbering series | SettingsScreen | Covered |
| Terms templates | SettingsScreen | Covered |
| Logo | SettingsScreen | Covered via `/settings/logo` |
| Team management | SettingsScreen | Covered: invite/change role/remove |
| Backup / restore / purge | SettingsScreen | Covered with confirmation |
| Vyapar / Tally / CSV imports | ImportToolsScreen | Covered |
| Audit | DataWorkspaceScreen | Covered read-only |

## Intentionally separate from this tenant app

- `admin/*`: platform super-admin console
- `backfill`: operational data repair
- `apexbooks_sync` and Cartunez integration/webhook surfaces
- health/readiness/static infrastructure routes

## Verification status

`flutter pub get`, `dart format`, `flutter analyze` (no errors or warnings; remaining items are lints/deprecations), and `flutter test` (10 tests) were run on Flutter 3.47.1 / Dart 3.13.1.

`flutter build web --release` succeeded. `flutter build apk --release` could not be run here: this machine has no Android SDK or JDK (`ANDROID_HOME` unset, `java` not on PATH). iOS/macOS builds were not attempted on Windows.

The app has not been integration-tested against a live FastAPI tenant. Exercise staging with GST, composition/non-GST, returns, stock transfers, bank reconciliation and multi-user permissions before store/release publication.

- Recurring invoice *edit of existing templates* is pause/activate/delete/generate, not a full line-item editor after create.
- Warehouse *edit of name/address after create* is not in the list UI; deactivate/delete are.
- Compliance tools (GSTIN/HSN lookup) are implemented but not a top-level sidebar item; they remain a dedicated screen for GST utilities.
- No live FastAPI instance was exercised in this environment; coverage is source + analyzer/test/build validation.
