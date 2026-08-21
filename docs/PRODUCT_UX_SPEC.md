# ApexBooks Flutter — Product & UX Specification

## 1. Product position

ApexBooks is an Indian GST accounting product for small and mid-sized businesses that must feel fast enough for an owner/operator and complete enough for an accountant. The core UX rule is:

> **Billing first, books underneath, compliance always one step away.**

The product should not expose accounting complexity during routine billing, but every operational action must feed auditable books, inventory and statutory reports.

## 2. Competitor patterns incorporated

### Vyapar

Useful patterns: fast business dashboard, sales/purchase shortcuts, stock value/low-stock, cash/bank visibility, reminders, GST reports, invoice customization, UPI/QR and practical desktop/mobile workflows.

### Zoho Books

Useful patterns: structured receivables/payables, sales lifecycle, GST/e-invoice/e-way workflows, bank reconciliation, approvals, strong reporting and clear separation between operational documents and accounting reports.

### myBillBook

Useful patterns: extremely quick invoice flow, WhatsApp/PDF mental model, godown/inventory emphasis, payment reminders, live party ledger, barcode/serial workflows, e-invoice/e-way and migration/Tally familiarity.

### Swipe

Useful patterns: low-friction GST billing, item/party profitability reports, stock and payments, multi-business/multi-user context and connected-banking direction.

### Synthesis

ApexBooks uses a restrained professional shell rather than copying any competitor visually. Repeated market signals become product priorities:

1. New invoice and record payment must always be easy to reach.
2. Outstanding receivables/payables and stock exceptions belong on the dashboard.
3. Party/item creation must be possible without leaving the transaction mental model.
4. GST state/POS/HSN/SAC data is visible when relevant but not allowed to dominate every screen.
5. Reports are deep on desktop but readable on mobile.
6. Migration from incumbent tools is a first-class onboarding feature.
7. Bank reconciliation and GSTR-2B reconciliation are core accounting workflows, not “advanced extras.”

## 3. Responsive information architecture

### Mobile (< 760 px)

Bottom navigation contains:

- Home
- Sales invoices
- Purchase bills
- Parties
- More

“More” opens the full grouped drawer. Forms use full-width fields, transaction lines stack vertically, details use bottom sheets/dialogs and dense tables become readable cards.

### Tablet (760–1179 px)

A `NavigationRail` exposes the complete module set while preserving content width. Transaction forms can use two-column wraps when space allows.

### Desktop (>= 1180 px)

Persistent sidebar grouped into Overview, Sales, Purchases, Inventory, Money & Books, Compliance and Administration. Top bar owns company switching, profile and theme controls. Tables and reports take advantage of width while keeping a mobile-compatible component hierarchy.

## 4. Screen inventory

### Authentication / onboarding

- Login
- Register business
- Forgot password
- TOTP challenge
- Company selector
- Company switch

### Dashboard

- Revenue / receivable / payable / cash-stock KPIs
- Sales trend
- Expense trend
- GST snapshot
- Overdue alerts
- Quick actions

### Parties

- Customers / vendors / both
- GSTIN, PAN, state code
- Billing and shipping addresses
- Opening balance
- Active/inactive status

### Items

- Goods / service
- HSN / SAC
- SKU / barcode
- UOM
- GST rate
- Sale / purchase price
- Opening/current stock
- Reorder level

### Sales

- Tax invoices
- Quotation / proforma
- Sales order
- Delivery challan
- Recurring invoice
- Credit note
- Debit note
- Sales return

Invoice editor includes party, POS, supply type, issue/due dates, lines, HSN/SAC, quantity, rate, discount, GST, inclusive tax, RCM, shipping, reference, notes, terms, draft/post and server preview.

### Purchases

- Purchase bills
- Purchase orders
- Goods receipts
- Vendor payments
- Purchase returns
- Expenses

### Inventory

- Products/services
- Warehouses/godowns
- Transfers
- Adjustments
- Stock ledger

### Money & accounting

- Customer receipts
- Bank profiles
- Bank-statement import
- Reconciliation and auto-match
- Chart of accounts
- Manual journal
- Financial statements
- Financial years / year end

### GST

- GSTR-1
- GSTR-2 / purchase tax view
- GSTR-3B
- GSTR-2B/2A reconciliation
- E-invoice entry points
- E-way bill listing

### Reports

- Profit & Loss
- Balance Sheet
- Trial Balance
- Cash Flow
- Sales analytics
- Purchase analytics
- AR aging
- AP aging
- Outstanding receivables
- Outstanding payables
- GST reports

### Settings & administration

- Company legal profile
- GST tax mode
- Origin state
- E-invoice / E-way credentials
- UPI
- Numbering series
- Team roles
- Password / 2FA
- Backup verification
- Import tools
- Audit log

## 5. GST design rules

1. Invoice number UI limits GST invoice numbers to 16 characters even if a looser backend storage field exists.
2. Place of supply is a first-class invoice field; origin state comes from tenant settings.
3. Intra-state vs inter-state splits are displayed from `/invoices/preview`.
4. HSN/SAC and GST rate remain editable per line because statutory treatment can differ from a product master default.
5. Reverse charge, export and SEZ supply are explicit controls.
6. GSTR displays are reports compiled by the backend, not independently recomputed by the app.
7. GSTR-2B upload displays matched / partial / unmatched supplier invoices so accountants can work exceptions first.
8. E-invoice/E-way credentials remain backend-encrypted; the UI never reads stored passwords back.

## 6. Accounting integrity rules

- Manual journals require >=2 lines and balanced debit/credit totals before submission.
- Posted financial documents are treated as accounting records, not ordinary editable CRUD rows.
- Financial reports source posted books.
- Period locks and financial-year rules are expected to be enforced server-side and surfaced as actionable API errors.
- Import flows should be auditable and atomic where the backend provides that contract.

## 7. Interaction standards

- Primary action in each workflow appears once and uses a filled button.
- Destructive operations require a dedicated confirmation/verification flow.
- Loading state must not shift primary controls unpredictably.
- API errors show user-readable `detail`; support IDs can be included for support/debugging.
- Currency uses `en_IN` grouping and ₹.
- Dates display as `dd MMM yyyy`, while API payloads use ISO `yyyy-MM-dd`.
- Empty states explain the next useful action rather than only saying “no data.”

## 8. Release hardening still required outside this source pass

- Run Flutter analyzer/tests/builds on installed Android/iOS/Web/Desktop SDKs.
- Exercise all role permission combinations against staging.
- Add device-level barcode camera flow if required.
- Add native “Save/Share PDF” integrations to download endpoints.
- Add WhatsApp/share-sheet integration around generated invoice PDFs.
- Add push/local reminders if backend notification scheduling is exposed.
- Add golden/widget tests after platform generation locks the project to a concrete Flutter stable version.
