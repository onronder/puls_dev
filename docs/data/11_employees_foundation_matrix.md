# PR11.1 — Employees Foundation Matrix

Reference inventory: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Locked boundaries

- **Empty real ≠ demo:** A real tenant with zero employees is valid production state. List/stat adapters return `[]` and zero stats on the real path. Demo data activates only when `VITE_PULS_DEMO_MODE` is enabled via `resolveAdapterData*`, with explicit source metadata.
- **Manager display only:** `employees.manager_employee_id` is a display/cache field in foundation list stats. Canonical manager readiness remains in PR10.15 (`employee_reporting_lines` via [employee-assignment-readiness.ts](../../src/lib/data/setup/employee-assignment-readiness.ts)).
- **No migrations:** PR11.1 adds no schema changes. Blocking schema/RLS issues require a separate migration PR.
- **Profile scope:** Pure auth→employee mapping helpers only. Account/password/preferences readiness is PR11.8.

## Canonical sources

| Domain | Canonical table/view | Tenant scope | Notes |
|--------|---------------------|--------------|-------|
| Employee master | `puls_core.employees` | `tenant_id = resolveTenantContext().tenantId` | Foundation list reads |
| Departments | `puls_core.departments` | tenant-scoped batch lookup | Display names only |
| Positions | `puls_core.positions` | tenant-scoped batch lookup | Display names only |
| Manager display | `puls_core.employees.manager_employee_id` | FK on employee row | Display only; not readiness SoT |
| Manager readiness | `puls_core.employee_reporting_lines` | PR10.15 | Canonical assignment readiness |
| Leave detail | `puls_calc.leave_overview` | tenant + employee | Detail sheet overlay |
| Auth→employee | `puls_core.employees.user_id` | `auth.uid()` / JWT sub | `resolveTenantContext`, `current_employee_id()` |

## Route usage

| Route | Primary adapter | Secondary adapter | UI posture |
|-------|-----------------|-------------------|------------|
| `/calisanlar` | `fetchEmployeeAssignmentReadiness` | `fetchEmployeesOverview` (detail leave) | Manager-only, read-only, PR10.15 readiness |
| `/profil` | `fetchProfileOverview` | — | Self profile; demo when unmapped + demo mode |

Foundation adapters (`fetchEmployeeList`, `fetchEmployeeListStats`) are canonical API for future surfaces; `/calisanlar` intentionally stays on PR10.15 to avoid duplicating assignment logic.

## Adapter inventory

| Adapter | File | Demo fallback | WithMeta |
|---------|------|---------------|----------|
| `fetchEmployeeList` | `core/employees.ts` | `fetchDemoEmployeeAssignmentReadiness` mapped to list items | Yes |
| `fetchEmployeeListStats` | `core/employees.ts` | `buildEmployeeListStats(demo list)` | Yes |
| `fetchEmployeesOverview` | `core/employees.ts` | `fetchDemoEmployeesOverview` | Yes |
| `fetchEmployeeAssignmentReadiness` | `setup/employee-assignment-readiness.ts` | `fetchDemoEmployeeAssignmentReadiness` | Yes (PR10.15) |
| `fetchProfileOverview` | `profile/overview.ts` | `fetchDemoProfileOverview` | No (PR11.8) |

## Demo fallback behavior

| Adapter | Real empty behavior | Demo when |
|---------|--------------------|-----------|
| `fetchEmployeeList` | `[]`, source `real`, status `empty` | Demo mode on + real empty |
| `fetchEmployeeListStats` | all-zero stats | Demo mode on + real empty |
| `fetchEmployeeAssignmentReadiness` | empty employees + zero summary | Demo mode on + real empty |
| `fetchProfileOverview` | empty profile shape | Demo mode on + real empty |

Demo output must never be presented as production completeness. UI shows a demo source pill when assignment readiness `source === 'demo'`.

## Auth/profile mapping

| Step | Mechanism | Result |
|------|-----------|--------|
| Auth user ID | Supabase session `user.id` | Input to adapters |
| Tenant + employee | `resolveTenantContext(userId)` | Primary: `employees` row where `user_id = userId` |
| Fallback tenant | `user_tenants` + `user_roles` | `employeeId` may be null |
| Profile overview | `ctx.employeeId` → employee row | Real data when mapped |
| RLS self read | `puls_core.current_employee_id()` | JWT `auth.uid()` → employee id |

PR11.8 owns broader account readiness (password, preferences, unmapped-user UX).

## RLS/tenant assumptions

- All employee reads use `.eq('tenant_id', ctx.tenantId)` after `resolveTenantContext`.
- `puls_core.employees` SELECT: admin OR self OR direct reports (`manager_employee_id = current_employee_id()`).
- Departments/positions: tenant-scoped SELECT for authenticated users.
- No RLS policy changes in PR11.1.

## Surface matrix

| Surface | Canonical source | Adapter | Real status | Demo fallback | Mutation | Gap | Follow-up |
|---------|------------------|---------|-------------|---------------|----------|-----|-----------|
| `/calisanlar` employee list | `puls_core.employees` + assignments | `fetchEmployeeAssignmentReadiness` | Tenant-scoped | Centralized demo fixture | read_only | — | PR11.1 UI source pill |
| `/calisanlar` employee stats | computed from employees | assignment readiness `summary` | Real computed | demo fixture summary | read_only | — | — |
| `/calisanlar` read-only detail sheet | employees + leave | `fetchEmployeesOverview` | Tenant-scoped | demo overview | read_only | Leave demo source not surfaced | Optional |
| employee assignment readiness section | PR10.15 | `employee-assignment-readiness.ts` | Reuse | Centralized demo | read_only | — | — |
| `/profil` profile overview | `puls_core.employees` via `ctx.employeeId` | `fetchProfileOverview` | Real when mapped | demo when empty + demo mode | read_only | Account readiness | PR11.8 |
| auth user → employee mapping | `employees.user_id` | `resolveTenantContext` | Primary path | — | — | Tenant without employee row | PR11.8 |
| manager-visible employee reads | RLS on `puls_core.employees` | client queries | Policy-enforced | — | read_only | — | — |
| employee self reads | `current_employee_id()` | RLS | Policy-enforced | — | read_only | — | — |

## Remaining gaps / follow-ups

| Gap | Owner |
|-----|-------|
| Employee CRUD/editor | Future employee editor PR |
| Assignment editor | Out of scope |
| Profile account/password/preferences readiness | PR11.8 |
| Legacy duplicate `src/lib/queries/employees.ts` | Cleanup follow-up (zero imports) |
| Swagger/OpenAPI for employee endpoints | PR11.9+ |

Employee CRUD/editor, assignment editor, department/position/cost center CRUD, manager hierarchy editor, resolver/decide/import changes, ERP writes, and migrations remain **out of scope** for PR11.1.
