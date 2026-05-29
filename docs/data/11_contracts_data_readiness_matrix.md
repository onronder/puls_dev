# PR11.6 — Contracts Data Readiness Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

PR11.6 hardens `/sozlesmeler` as a **read-only contract metadata** surface. It does not open contract management, file upload, reminders, or CRUD. It adds WithMeta source honesty, pure mapping helpers/tests, tenant/RLS smoke, and verify guards.

**Quality bar:** metadata truth, demo transparency, no app mutations.

**No migration in PR11.6.**

## Surface table

| Surface | Behavior | PR11.6 |
|---------|----------|--------|
| Metrics row | Active, expiring, pending signature, KVKK counts | preserve; source from `dashboard_overview` + mapped list |
| Contract list | Read-only table/cards | empty state when real empty |
| Detail sheet | Read-only metadata preview | preserve |
| Reminder sheet | `common.soon`, disabled save | preserve |
| Upload action | Disabled with tooltip | preserve |

## Data source matrix

| Source | Schema | Adapter usage | PR11.6 |
|--------|--------|---------------|--------|
| `contracts` | `puls_workflow` | list join with employees | preserve read; map via `mapContractRow` |
| `contract_files` | `puls_workflow` | none in app today | smoke readability only |
| `dashboard_overview` | `puls_calc` | tenant aggregate contract counts | **preserve adapter summary source** |
| `contracts_overview` | `puls_calc` | not used by adapter | smoke surface check only |
| `employees` | `puls_core` | join for display name | preserve |

## Metadata-only boundary

- `contracts.metadata_only CHECK (metadata_only = TRUE)` — no file bytes in workflow tables
- `contract_files.metadata_only CHECK (metadata_only = TRUE)` — `file_ref` is metadata reference only
- App does not call storage APIs or render file content
- Detail sheet copy: metadata-level preview only

## RLS / security notes

- `contracts` SELECT: tenant match + (admin OR `employee_id = current_employee_id()`)
- DB allows admin INSERT/UPDATE; **app exposes no writes**
- Adapters use `resolveTenantContext` + `.eq('tenant_id', …)`
- Smoke optional JWT path: `request.jwt.claim.sub` → `current_employee_id()` self read

## Demo fallback and WithMeta honesty

| Adapter | Real empty | Demo | PR11.6 |
|---------|------------|------|--------|
| `fetchContractsOverview` | empty contracts array | rich demo fixture | `fetchContractsOverviewWithMeta` + demo pill |

## Mutation inventory

| Operation | App-exposed | PR11.6 |
|-----------|-------------|--------|
| Contract create/update/delete | no | verify forbids adapter mutations |
| File upload/storage | no | verify forbids storage APIs |
| Reminder create | no | UI stays disabled + `common.soon` |

## Follow-ups

- Contract CRUD, file upload, e-signature, reminder mutations
- Lifecycle/audit, API/OpenAPI exposure
- Broader demo guard (PR11.9)
- Optional adapter use of `contracts_overview` per-employee aggregates

## Surface matrix (minimum)

| Surface | Source | Adapter | Demo | PR11.6 |
|---------|--------|---------|------|--------|
| Overview | calc + workflow reads | `fetchContractsOverviewWithMeta` | fallback | WithMeta + pill |
| List items | `contracts` + employee join | `mapContractRow` | demo fixture | pure helpers + tests |
| Metrics | `dashboard_overview` | real fetch | demo counts | preserve source |
| Upload/reminder | UI only | — | — | stay disabled |
