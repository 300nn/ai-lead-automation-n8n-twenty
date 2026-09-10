# Twenty CRM Schema

## Person custom fields

| Field | Purpose |
|---|---|
| Lead Score | Qualification score (0–100) |
| Lead Category | HOT / WARM / COLD |
| Budget | Submitted budget |
| Company Size | Submitted company size |
| Service | Requested automation/service |
| Source | Lead source |
| AI Summary | Qualification summary |
| Request ID | Idempotency/correlation identifier |

## Opportunity custom fields

| Field | Purpose |
|---|---|
| Lead Score | Copies qualification score into the deal |
| Lead Category | HOT classification |
| Service | Requested service |
| Source | Lead source |
| AI Summary | Qualification context for sales |
| Request ID | Correlates the Opportunity with n8n state/audit |

Standard Twenty fields are reused instead of duplicated: **Amount**, **Stage**, and **Point of Contact**.

## Portfolio views

### AI Leads

Recommended visible columns: Name, Emails, Lead Category, Lead Score, Budget, Service, Company Size, Source, Creation date. Filter by `Request ID is not empty`. A single `Lead Score DESC` sort is used in the validated view.

### AI Sales Pipeline

Kanban grouped by the standard Opportunity `Stage` field. Recommended card fields: Point of Contact, Lead Category, Lead Score, Amount, Service, Source. Filter by `Request ID is not empty`.

### Dashboard

Validated dashboard widgets include Automated Leads, HOT Leads, Leads by Category, Opportunities by Stage and Latest AI Leads. Pipeline Value can be added as `SUM Amount` on automated Opportunities.
