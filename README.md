# ApexBooks Flutter

Responsive Flutter client for the **ApexBooks / Bookkeeping FastAPI backend**. The UI is designed for Indian SMEs and accounting teams: billing-first daily work on phones, with complete books, GST, inventory, reconciliation, reports and administration available on larger screens.

## What is included

- Secure login, refresh-token rotation, TOTP 2FA challenge and multi-company selection.
- Responsive shell: mobile bottom navigation + drawer, tablet rail, desktop accounting sidebar.
- Dashboard with KPIs, sales/expense trends, GST snapshot, overdue alerts and quick actions.
- Parties: customer/vendor GSTIN, PAN, state, billing/shipping data and opening balances.
- Items: goods/services, HSN/SAC, SKU/barcode, GST rate, prices, UOM, opening stock and reorder levels.
- Sales invoices with server `/invoices/preview`, CGST/SGST/IGST preview, GST-inclusive pricing, RCM, export/SEZ supply, discounts, freight, draft/post workflow and invoice details.
- Sales workspaces: quotations/proforma, sales orders, delivery challans, recurring invoices, credit/debit notes and returns.
- Purchase workspaces: bills, purchase orders, GRNs, vendor payments, purchase returns and expenses.
- Inventory workspaces: godowns/warehouses, stock transfers, adjustments and stock ledger.
- Banking: bank profiles, SBI/HDFC/ICICI/generic statement import, reconciliation stats and backend auto-match.
- Accounting: chart of accounts, balanced manual journals, financial statements and financial-year workspace.
- GST Center: GSTR-1/2/3B views, e-invoice/e-way entry points and GSTR-2B/2A ITC reconciliation.
- Reports: P&L, balance sheet, trial balance, cash flow, sales/purchase analytics, receivables/payables aging and GST reports.
- Settings: company identity/tax mode, logo, branches, GST/e-invoice/e-way credentials, UPI, numbering series, terms templates, team roles, password/2FA, JSON backup/restore and optional purge.
- Dedicated workspaces for recurring invoices, credit/debit notes, sales/purchase returns, GRNs, receipts/payments, expenses, inventory, e-way bills and financial-year/period locks.
- Migration tools: native Vyapar `.vyb`, Tally XML, atomic dry-run CSV migration and GST portal JSON reconciliation.
- Audit and financial-year administration workspaces.

## Backend

By default the client expects:

```text
http://localhost:8000/api/v1
```

Override it at build/run time:

```bash
flutter run --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

All authenticated tenant requests attach both:

```text
Authorization: Bearer <access-token>
X-Tenant-ID: <selected-company-id>
```

Access tokens are automatically refreshed using the rotating refresh token. Session tokens and the selected tenant are stored through `flutter_secure_storage`.

## First-time platform bootstrap

The execution environment can generate platform runners from the installed Flutter SDK:

```bash
flutter create --project-name apexbooks --org in.apexbooks \
  --platforms=android,ios,web,windows,macos,linux .
flutter pub get
```

Then run a target:

```bash
flutter run -d android
flutter run -d chrome
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

## Recommended verification before release

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define=API_BASE_URL=https://your-api/api/v1
flutter build web --release --dart-define=API_BASE_URL=https://your-api/api/v1
# and your required desktop target(s)
```

Test the app against a staging backend containing regular GST, composition/non-GST, inter-state/intra-state, inclusive tax, returns, stock transfers, bank reconciliation and multi-user permission scenarios before publishing.

## Structure

```text
lib/
  core/
    api/                 API client, exceptions, secure token store
    session/             login/session/company state
    theme/               Material 3 design system + breakpoints
  data/                  India constants + generic workspace catalog
  features/
    auth/
    dashboard/
    masters/
    sales/
    banking/
    accounting/
    gst/
    reports/
    imports/
    settings/
    shell/
    workspaces/
docs/
  PRODUCT_UX_SPEC.md
  API_MAPPING.md
```

## Product principle

The interface follows the strongest pattern across Indian SMB accounting products: **billing and collections first; accounting underneath; compliance always accessible**. Mobile prioritizes invoice/receipt/party/stock work. Desktop exposes dense tables, report inspection, reconciliation, journals and administration without turning the mobile experience into a miniature ERP.

## Important implementation notes

- GST totals shown before posting come from the backend preview engine; the client does not maintain a competing statutory tax engine.
- Posted accounting documents should be corrected through backend-supported reversal/correction workflows instead of destructive editing.
- CSV migration validates in dry-run mode before the UI offers a commit.
The generic workspace is used for quotations, sales/purchase orders, delivery challans, purchase bills and the audit log. Higher-frequency modules (invoices, notes, returns, recurring, GRNs, payments, expenses, inventory, e-way, financial years, settings) have dedicated screens.
- Permissions are server-authoritative. The UI can be extended to hide actions from `/auth/me` scopes, but it never treats hidden controls as an authorization boundary.
