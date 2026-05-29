# PR11.7 — Dashboard Readiness Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

PR11.7 hardens `/dashboard` as a **production-partial** read-only overview. Real tenant metrics, work queue, ERP readiness, and employee-scoped leave/expense summaries are wired from calc/integration views. **Recent activity is demo-only today** — the real path returns an empty feed by design until a follow-up activity source exists.

**Quality bar:** source honesty (WithMeta + demo pill), neutral route naming, no app mutations.

**No migration in PR11.7.**

## Surface table

| Surface | Behavior | PR11.7 |
|---------|----------|--------|
| Metric cards | Employee, department, position, competency, ERP, data readiness | preserve calc/integration sources |
| Work queue | Derived from cycle, ERP mapping, pending leave/expense | export/test `buildDashboardQueue` |
| ERP card | Read-only mapping/readiness; links `/erp` | preserve; smoke reads ERP tables |
| Recent activity | Demo fixture only on real empty + demo fallback | document gap; real path stays `[]` |
| Quick actions | Links to `/izin`, `/masraf`, `/performans` | preserve |
| Empty tenant | Honest copy when real tenant has no data | `dashboard.emptyTenant.*`; demo pill when demo |

## Metric source matrix

| Metric / surface | Schema | Adapter usage | PR11.7 |
|------------------|--------|---------------|--------|
| Employees, departments, positions, competencies, readiness, active cycle, pending counts | `puls_calc.dashboard_overview` | tenant aggregate | preserve |
| ERP connected / provider | `puls_integration.erp_connections` | active connection row | preserve; provider on `stats` only |
| ERP mapped / total fields | `puls_integration.erp_field_mappings` | count queries | preserve |
| Leave quick action | `puls_calc.leave_overview` | when `ctx.employeeId` | preserve |
| Expense quick action | `puls_calc.expense_overview` | when `ctx.employeeId` | preserve |
| Recent activity | — | real: `[]`; demo: static fixture | document demo-only gap |

## Work queue derivation

| ID | Condition | Route |
|----|-----------|-------|
| q1 | `active_cycle_name == null` | `/performans` |
| q2 | `totalFields > 0 && mappedFields < totalFields` | `/erp` |
| q3 | `pending_leave_count > 0` | `/izin` |
| q4 | `pending_expense_count > 0` | `/masraf` |

## Demo fallback and WithMeta honesty

| Adapter | Real empty | Demo | PR11.7 |
|---------|------------|------|--------|
| `fetchDashboardOverview` | zero stats + empty queue/activity | rich demo page data | `fetchDashboardOverviewWithMeta` + demo pill |

`isDashboardEmpty` considers employee/department/position/competency counts, ERP connected, mapped fields, and data readiness percent.

## Tenant / RLS / security notes

- Adapters use `resolveTenantContext` + `.eq('tenant_id', …)` on calc/integration reads
- Dashboard route exposes **no writes**
- Smoke validates tenant-scoped reads; optional JWT block asserts `current_employee_id()` mapping

## Mutation inventory

| Operation | App-exposed | PR11.7 |
|-----------|-------------|--------|
| Dashboard CRUD | no | verify forbids adapter/route mutations |
| ERP sync / push | no | verify forbids sync/write phrases |
| Activity feed writes | no | out of scope |

## Follow-ups

- Real recent activity feed (audit/workflow events)
- Richer manager dashboard aggregates
- Dynamic work-queue meta (amounts, names)
- Broader demo guard (PR11.9)
- PR11.8 sidebar/runtime follow-ups per series inventory

## Surface matrix (minimum)

| Surface | Source | Adapter | Demo | PR11.7 |
|---------|--------|---------|------|--------|
| Overview | calc + integration | `fetchDashboardOverviewWithMeta` | fallback | WithMeta + pill |
| Queue | derived in adapter | `buildDashboardQueue` | demo fixture | pure helper + tests |
| ERP card | integration + calc | `buildDashboardErpStatus` | demo fixture | no provider in ERP status input |
| Activity | none (real) | `recentActivities: []` | demo fixture | documented gap |
