# PR10.14 — Org Setup Readiness Matrix

Required artifact documenting canonical org master-data sources, current CRUD/readiness status, and PR10.15 dependencies.

**No ERP writes in PULS.** Cost center display and mapping readiness are read-only; ERP/finance master data remains external.

## Readiness matrix

| Domain | Canonical table/source | Route | Adapter | RLS/tenant | CRUD | Used by | Gap | PR owner |
|--------|------------------------|-------|---------|------------|------|---------|-----|----------|
| Departments | `puls_core.departments` | `/departmanlar` | `fetchDepartmentsOverview` | tenant RLS SELECT; admin INSERT/UPDATE | **read-only** | employees, `organization_overview` | code/parent not in UI yet | PR10.14 read / PR10.15 write |
| Positions | `puls_core.positions` | `/pozisyonlar` | `fetchPositionsOverview` | tenant RLS SELECT; admin INSERT/UPDATE | **read-only** | employees, headcount | template/evaluation not wired on real path | PR10.14 read / PR10.15 write |
| Cost centers | `puls_core.cost_centers` | `/masraf-kategorileri` (CC section) | `fetchCostCenterReadinessOverview` | tenant RLS SELECT | **read-only** | resolver V3, expense routing | — | PR10.14 (PR10.3) |
| Cost center external mappings | `puls_integration.entity_identity_map` + `source_namespaces` | same | cost-center-readiness | import metadata RLS | **read-only** | export readiness | unmapped CCs → `needs_mapping` | PR10.14 |
| Employee department assignment | `puls_core.employees.department_id` | `/calisanlar` (read) | employees adapter | tenant RLS | **not PR10.14** | org context | no setup editor | PR10.15 |
| Employee position assignment | `puls_core.employees.position_id` | `/calisanlar` (read) | employees adapter | tenant RLS | **not PR10.14** | headcount | no setup editor | PR10.15 |
| Employee cost center assignment | `puls_core.employee_cost_center_assignments` | — | resolver internal | tenant RLS | **not PR10.14** | `_resolver_requester_cost_center_id` | no setup UI | PR10.15 |
| Manager/reporting line | `puls_core.employee_reporting_lines` | — | import apply / authority graph | tenant RLS | **not PR10.14** | manager approver | no setup UI | PR10.15+ |

## Production-readable after PR10.14

- Tenant-scoped department list with code, active flag, source signal
- Tenant-scoped position list with code, active flag, source signal
- Cost center readiness summary (mapped/unmapped) via existing PR10.3 adapter
- Unified `fetchOrgSetupReadiness` summary on `/sirket-kurulum`
- Empty states and status/source pills on setup routes

## Read-only until PR10.15+

- Department CRUD
- Position CRUD
- Employee department/position/cost center assignment editing
- Manager/reporting line editing

## Required before reliable request creation and approval routing

- At least one active department and position row per tenant (employee assignment in PR10.15)
- Cost center rows for expense routing; export-ready mapping when ERP export is required
- Employee cost center assignment (PR10.15) for `cost_center_owner` / `requester_cost_center` resolver strategies

## Resolver dependencies (document only — no changes in PR10.14)

- `puls_workflow._resolver_requester_cost_center_id` reads `employee_cost_center_assignments`
- Policy steps with `cost_center_owner` approver type require active cost center + authority graph
- Manager approver uses `employee_reporting_lines` (not department manager field directly)

## PR10.15 must rely on

- Canonical `puls_core.departments` and `puls_core.positions` rows with tenant isolation
- `fetchDepartmentsOverview` / `fetchPositionsOverview` as read foundation
- `fetchOrgSetupReadiness` summary for setup dashboard signals
- Cost center readiness from PR10.3 unchanged
- Employee assignment readiness: see [`docs/data/10_employee_assignment_readiness_matrix.md`](10_employee_assignment_readiness_matrix.md) (PR10.15)
