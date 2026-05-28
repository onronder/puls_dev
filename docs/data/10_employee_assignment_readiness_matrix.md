# PR10.15 — Employee Assignment Readiness Matrix

Required artifact mapping employee assignment fields to canonical sources, readiness rules, and downstream PR dependencies.

**No ERP writes in PULS.** Assignment visibility is read-only; ERP/HRIS/import remains the write path for imported org data.

**No resolver/decide/import changes in PR10.15.**

## Readiness matrix

| Assignment domain | Canonical source | Route field | RLS/tenant | Used by | Readiness rule | Editable PR10.15? | Gap / follow-up |
|-------------------|------------------|-------------|------------|---------|----------------|-------------------|-----------------|
| Employee → department | `puls_core.employees.department_id` + `departments` | dept pill | tenant + `can_read_employee` | org context, dept manager fallback | FK present + dept `is_active` | **read-only** | assignment editor PR10.15+ |
| Employee → position | `puls_core.employees.position_id` + `positions` | position pill | tenant + `can_read_employee` | headcount | FK present + position `is_active` | **read-only** | assignment editor PR10.15+ |
| Employee → cost center | `puls_core.employee_cost_center_assignments` | CC pill | tenant + `can_read_employee` | resolver V3, expense pools | active assignment + CC `is_active`; tie-break `starts_on DESC, updated_at DESC, id ASC` | **read-only** | assignment editor PR10.15+ |
| Employee → manager / reporting line | `puls_core.employee_reporting_lines` (`primary_manager`) | manager pill | tenant + admin read | manager approver | active primary line + manager `employment_status=active`; tie-break `starts_on DESC, created_at DESC` | **read-only** | hierarchy editor PR10.15+ |
| Employment status | `puls_core.employees.employment_status` | row status `partial` | tenant RLS | metrics scope | inactive → `partial`; excluded from ready/gap summary counts | **read-only** | — |
| CC owner routing | assignment + `authority_relationships` | doc only | tenant RLS | `cost_center_owner` approver | missing/inactive CC blocks expense routing | N/A | resolver internal |
| Manager approver routing | reporting line (+ dept manager fallback in resolver) | doc only | tenant RLS | `manager` approver step | missing manager blocks manager approver | N/A | resolver internal |

## Single row status semantics

- **One highest-severity status** per employee row on `/calisanlar`.
- **`readiness.flags`** exposes every gap independently (e.g. inactive department **and** missing manager → row status `inactive_reference`, flags show both).
- **`partial`** is used **only** for inactive employees (`employment_status !== 'active'`).

## Status precedence (active employees)

1. Any linked ref exists but inactive → `inactive_reference`
2. Missing department → `missing_department`
3. Missing position → `missing_position`
4. Missing cost center assignment → `missing_cost_center`
5. Missing primary manager → `missing_manager`
6. All required refs present and active → `ready`

## Production-readable after PR10.15

- Tenant-scoped employee list with department, position, cost center, manager assignment visibility
- Readiness status pill per employee
- Summary metrics: active, ready, missing dept/pos/CC/manager
- Segmented readiness filters on `/calisanlar`
- Empty states for no employees / no filter matches

## Routing impact of missing assignments

| Gap | Approval impact |
|-----|-----------------|
| Missing manager / reporting line | `manager` approver step cannot resolve |
| Missing cost center assignment | `requester_cost_center` scope, finance/hr/legal pools fail-closed |
| Missing CC + inactive CC | `cost_center_owner` approver cannot resolve authority graph scope |
| Missing department (resolver fallback) | Dept manager fallback unavailable when reporting line absent |

## Import / ERP ownership

- Department and position FKs on `employees` are typically set by import apply
- Cost center assignments and reporting lines are written by import apply (deactivate-and-insert)
- PULS does not write ERP master data; PR10.15 displays readiness only

## Deferred editing (follow-up PR)

- Employee assignment editor (dept/pos/CC/manager)
- Broad employee CRUD
- Manager hierarchy editor

## PR10.16 / PR10.17 preparation

- **PR10.16 (request creation hardening):** readiness flags identify requesters with incomplete assignments before leave/expense submission
- **PR10.17 (setup dashboard):** `fetchEmployeeAssignmentReadiness` summary composable into setup checklist

See also: [`docs/data/10_org_setup_readiness_matrix.md`](10_org_setup_readiness_matrix.md) for org master-data readiness (PR10.14).
