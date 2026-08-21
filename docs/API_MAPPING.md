# Flutter screen → FastAPI mapping

Authenticated tenant requests send `Authorization: Bearer …` and `X-Tenant-ID`. Mutation requests also send `Idempotency-Key`. Binary downloads retry once after refresh-token rotation on HTTP 401.

| Flutter area | Backend contract used |
|---|---|
| Session | `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/me`, `/auth/memberships`, `/auth/2fa/challenge` |
| Registration / recovery | `/auth/register`, `/auth/forgot-password` |
| Dashboard | `/dashboard/kpis`, `/dashboard/metrics`, `/dashboard/revenue-trend`, `/dashboard/expense-trend`, `/dashboard/overdue-alerts` |
| Reminders | `/reminders` |
| Parties | `/masters/contacts` |
| Items | `/masters/products` |
| Master data | `/masters/expense-categories`, `/masters/tax-templates`, `/masters/payment-terms` |
| Accounts | `/masters/accounts` |
| Banks | `/masters/banking-profiles` |
| Invoice list/create/detail | `/invoices`, `/invoices/stats`, `/invoices/{id}` |
| Invoice tax preview | `/invoices/preview` |
| Invoice lifecycle | `/invoices/{id}/finalize`, `/cancel`, `/clone`, `/print`, `/e-invoice` |
| Credit / debit notes | `/invoices/credit-notes`, `/invoices/debit-notes` plus `/finalize` and `/cancel` |
| Quotations | `/proforma-invoices` |
| Sales orders | `/sales-orders` |
| Delivery challans | `/delivery-challans` |
| Recurring sales | `/recurring-invoices`, `/recurring-invoices/{id}/generate` |
| Sales / purchase returns | `/returns/sales`, `/returns/purchase` |
| Bills | `/bills`, `/bills/preview` |
| Purchase orders | `/purchase-orders` |
| Goods receipts | `/goods-receipts` |
| Receipts / vendor payments | `/payments/receipts`, `/payments/disbursements` |
| Expenses | `/expenses`, `/expenses/preview` |
| Warehouses | `/warehouses` |
| Transfers | `/transfers` |
| Adjustments | `/inventory-adjustments` |
| Stock ledger | `/stock-ledger` |
| Bank reconciliation | `/bank-reconciliation/*` |
| Journals | `/accounting/journals` |
| Reports | `/reports/*` and `/accounting/profit-loss` |
| GST center | `/reports/gst/gstr1|gstr2|gstr3b`, `/gst/gstr2a/upload`, `/gst/returns` |
| E-way | `/eway-bills`, `/eway-bills/{id}/cancel`, `/eway-bills/{id}/vehicle`, `/eway-bills/consolidated` |
| Company | `/companies/{tenant_id}` |
| Branches | `/companies/{tenant_id}/branches` |
| Settings | `/settings`, `/settings/logo` |
| Numbering | `/settings/series` |
| Terms templates | `/terms-templates` |
| Team | `/companies/{tenant_id}/invite`, `/companies/{tenant_id}/members` |
| Backup / restore | `/companies/{tenant_id}/export`, `/companies/{tenant_id}/import` |
| Purge | `/purge/request`, `/purge/verify` |
| Vyapar / CSV / Tally | `/import/vyapar`, `/import/csv`, `/tally/import` |
| Financial years | `/financial-years`, `/financial-years/{id}/close`, `/reopen`, `/dashboard` |
| Period locks | `/accounting/periods`, `/accounting/periods/lock`, `/accounting/periods/unlock` |
| Audit | `/audit` |

## Deliberate server ownership

The Flutter app delegates these authoritative behaviors to FastAPI:

- GST rate resolution and CGST/SGST/IGST/cess splits (preview endpoints).
- Number-series generation and fiscal uniqueness.
- Posting to journals and stock ledger.
- Role permission enforcement and tenant isolation.
- Period locks / financial-year integrity, including reopen.
- E-invoice / e-way credentials and IRP actions.
- Bank auto-match.
- GSTR compilation and GSTR-2A/2B reconciliation.
