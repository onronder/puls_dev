# PR11.2 — Org Setup CRUD Readiness Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

PR11.2 adds tenant-safe, source-aware create/edit for PULS-owned `puls_core.departments` and `puls_core.positions` on `/departmanlar` and `/pozisyonlar`. Imported/ERP-owned rows remain read-only at DB and UI. Route status moves from `read_only` to **source-aware mixed CRUD** for PULS-owned rows only.

**Quality bar:** PULS-owned master data CRUD yes; imported/ERP-owned master data edit no.

## Canonical sources

| Entity | Table | Tenant scope | Source field |
|--------|-------|--------------|--------------|
| Department | `puls_core.departments` | `tenant_id = resolveTenantContext().tenantId` | `external_source` null → PULS-owned |
| Position | `puls_core.positions` | same | import sets `external_source` via integration apply |

## Writable vs read-only fields

| Entity | PULS-owned writable (PR11.2) | Read-only / not edited |
|--------|------------------------------|-------------------------|
| Department | `name`, `code` | `external_source`, `external_department_id`, `is_active`, `manager_employee_id`, `cost_center_id` |
| Position | `name`, `code`, `department_id`, `norm_headcount` | `external_source`, `external_position_id`, `is_active` |

`manager_employee_id` and `cost_center_id` are validated in DB only when set by other admin/import paths. PR11.2 UI and adapters do not edit those fields.

## Source ownership model

| `external_source` | UI source pill | Editable |
|-------------------|----------------|----------|
| null / empty | `puls` | yes |
| ERP vendor string | `erp` | no |
| `demo` | `demo` | no |
| other | `unknown` | no |

DB source-read-only: `UPDATE` blocked when `NULLIF(BTRIM(OLD.external_source), '') IS NOT NULL` **unless** `puls.import_apply.active = true` (set by `apply_import_batch` for re-import/post-pass writes). INSERT with non-empty `external_source` is allowed for import/apply; PR11.2 adapters never set external metadata.

## Route behavior

| Route | List adapter | Create/edit | Imported row click |
|-------|--------------|-------------|-------------------|
| `/departmanlar` | `fetchDepartmentsOverview` | PULS-owned sheet | Read-only sheet + boundary note |
| `/pozisyonlar` | `fetchPositionsOverview` | PULS-owned sheet | Read-only sheet + boundary note |

Mutations invalidate `departments-overview` / `positions-overview` and `setup-readiness-dashboard`.

## DB guardrail matrix

| Trigger | Errors |
|---------|--------|
| `validate_department_setup_guardrails` | `PULS_ORG_DEPARTMENT_*` |
| `validate_position_setup_guardrails` | `PULS_ORG_POSITION_*` |

Migration: [20260529110000_puls_core_org_setup_guardrails.sql](../supabase/migrations/20260529110000_puls_core_org_setup_guardrails.sql)

## Code uniqueness

No `(tenant_id, code)` unique index exists on departments or positions in current schema. PR11.2 does **not** add one. Duplicate code smoke emits `NOTICE`; adapter maps `23505` if a constraint fires.

## RLS/security notes

- SELECT: tenant-scoped via `current_tenant_id()`
- INSERT/UPDATE: admin-only (`puls_core.is_admin()`)
- No DELETE policy; no hard delete in PR11.2
- Adapters always `.eq('tenant_id', ctx.tenantId)`

## Demo fallback

Overview reads preserve `resolveAdapterData*` / `WithMeta`. Demo rows are not editable (`source === 'demo'`). Empty real tenant remains valid production state.

## Surface matrix

| Surface | Canonical source | Adapter | Writable in PR11.2 | Read-only boundary | Mutation | Follow-up |
|---------|------------------|---------|-------------------|-------------------|----------|-----------|
| `/departmanlar` list | `puls_core.departments` | `fetchDepartmentsOverview` | PULS-owned rows | imported rows | create/update | lifecycle/audit later |
| department create | departments | `createDepartment` | name, code | no ERP/import writes | insert | manager/cost center refs later |
| department edit | departments | `updateDepartment` | name, code | source-read-only | update | lifecycle later |
| `/pozisyonlar` list | `puls_core.positions` | `fetchPositionsOverview` | PULS-owned rows | imported rows | create/update | lifecycle/audit later |
| position create | positions | `createPosition` | name, code, departmentId, normHeadcount | no assignment writes | insert | employee assignment editor later |
| position edit | positions | `updatePosition` | same | source-read-only | update | lifecycle later |
| employee dept/position assignment | `employees.department_id`, `employees.position_id` | PR10.15 readiness | no | out of scope | none | employee editor PR |
| resolver/import | backend integration | none | no | out of scope | none | future backend PR |

## Out of scope and follow-ups

- Employee CRUD/assignment editing, manager hierarchy editor, cost center assignment editing
- Lifecycle deactivate/restore/audit for departments/positions
- Hard delete
- Resolver/decide runtime changes, ERP writes/sync
- Import: no behavior changes except a scoped transaction-local context flag in `apply_import_batch` so org guardrails do not block legitimate re-import/post-pass writes
- `(tenant_id, code)` unique index (document gap; add only after duplicate preflight)
- Swagger/OpenAPI

Employee assignment editing is not part of org master CRUD. PULS-owned setup rows are local master data; imported/ERP-owned rows are not edited by PULS UI.
