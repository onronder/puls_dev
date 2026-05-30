# PR13.1 — Embedded Demo Dependency Map

First manual inventory of embedded TypeScript business fixtures and `fetchDemo*` dependencies by feature, with retirement priority and replacement path.

Embedded TypeScript demo data may remain temporarily as a dev fallback, but it cannot be used as V1 packaging proof.

**Documentation-only.** This doc is the **first manual embedded-demo dependency inventory**. PR13.2 will turn it into an actionable retirement plan and, if useful, add grep automation.

## Executive summary

[`src/lib/demo/puls-demo-data.ts`](../../src/lib/demo/puls-demo-data.ts) centralizes rich domain demo payloads consumed via `resolveAdapterData*` across ~20 product adapters. Until PR13.5 DB bootstrap replaces these paths, **`VITE_PULS_DEMO_MODE` + embedded TS** masks empty tenant DB — not acceptable as V1 packaging proof per [`13_v1_product_packaging_strategy.md`](./13_v1_product_packaging_strategy.md).

## Definition: embedded demo business fixture

| Pattern | Example | Product risk |
|---------|---------|--------------|
| Central demo module | `puls-demo-data.ts` export objects | High — presents as complete product |
| `fetchDemo*` in adapters | `resolveAdapterData({ fetchDemo })` | High when real DB empty |
| Inline demo wrappers | `fetchDemoEmployeeList` in employees adapter | Medium — partial domain composite |
| Static placeholder (no business narrative) | `STATIC_AI_COACH_OVERVIEW` | Low — labeled teaser |
| Test mocks | `result.test.ts`, `employees.test.ts` | None — `test_only_ok` |
| i18n / empty states | Route copy | None — not fixtures |

## Retirement priority taxonomy

| Priority | Meaning |
|----------|---------|
| `P0_retire_for_packaging` | Must remove from packaging proof path before V1 signoff |
| `P1_replace_with_db_seed` | Replace with DB-backed demo tenant seed (PR13.3–13.5) |
| `P2_keep_dev_fallback_temporarily` | Dev fallback OK until bootstrap; not packaging proof |
| `test_only_ok` | Unit/integration tests only |
| `static_placeholder_ok` | Static/teaser UI; not product-ready AI |

## Inventory: `puls-demo-data.ts` exports

| Domain | File/function | Consumed by route/adapters | Data type | Product risk | Retirement priority | Replacement path | Follow-up PR |
|--------|---------------|----------------------------|-----------|--------------|---------------------|------------------|--------------|
| Dashboard | `fetchDemoDashboardOverview` | `dashboard/overview.ts` (composite) | Rich KPI/activity | High | P0_retire_for_packaging | `puls_calc.dashboard_overview` + seed | PR13.5 |
| Dashboard composite | `fetchDemoDashboardPageData` | `dashboard/overview.ts` | Multi-domain composite | High | P0_retire_for_packaging | Calc views + workflow seed | PR13.5 |
| Leave overview | `fetchDemoLeaveOverview` | `leave/overview.ts`, dashboard, request-readiness | Balances, requests, types | High | P0_retire_for_packaging | `puls_calc.leave_overview` + seed | PR13.5 |
| Expense overview | `fetchDemoExpenseOverview` | `expense/overview.ts`, dashboard, request-readiness | Claims, categories | High | P0_retire_for_packaging | `puls_calc.expense_overview` + seed | PR13.5 |
| Company setup | `fetchDemoCompanySetup` | `setup/company.ts` | Readiness checklist | Medium | P1_replace_with_db_seed | `setup_readiness_summary` + org seed | PR13.3 |
| Employee assignment | `fetchDemoEmployeeAssignmentReadiness` | `employee-assignment-readiness.ts`, `employees.ts`, request-readiness | Assignment gaps | High | P0_retire_for_packaging | Real assignment tables | PR13.3 |
| Employees list | `fetchDemoEmployeesOverview` | `core/employees.ts` | Employee directory | High | P0_retire_for_packaging | `puls_core.employees` seed | PR13.3 |
| Departments | `fetchDemoDepartmentsOverview` | `core/organization.ts` | Dept tree | High | P1_replace_with_db_seed | DB seed PULS + imported | PR13.3 |
| Positions | `fetchDemoPositionsOverview` | `core/organization.ts` | Position list | High | P1_replace_with_db_seed | DB seed PULS + imported | PR13.3 |
| Leave types setup | `fetchDemoLeaveTypesOverview` | `setup/leave-types.ts` | Admin CRUD overview | Medium | P1_replace_with_db_seed | Real leave_types rows | PR13.3 |
| Approval policies | `fetchDemoApprovalPoliciesOverview` | `workflow/policies.ts`, leave-types | Policy list | Medium | P1_replace_with_db_seed | `approval_policies` seed | PR13.3 |
| Expense categories | `fetchDemoExpenseCategoriesOverview` | `setup/expense-categories.ts`, request-readiness | Category admin | Medium | P1_replace_with_db_seed | `expense_categories` seed | PR13.3 |
| Cost center readiness | `fetchDemoCostCenterReadinessOverview` | `setup/cost-center-readiness.ts` | CC binding overview | Medium | P1_replace_with_db_seed | `cost_centers` seed | PR13.3 |
| Performance overview | `fetchDemoPerformanceOverview` | `performance/overview.ts` | Scores, cycles UI | High | P0_retire_for_packaging | Performance tables + calc | PR13.5 |
| Performance parameters | `fetchDemoPerformanceParametersOverview` | `setup/performance-parameters.ts` | Templates/bands | Medium | P1_replace_with_db_seed | `puls_performance` params seed | PR13.3 |
| Career | `fetchDemoCareerOverview` | `career/overview.ts` | Career map | High | P0_retire_for_packaging | Optional DB or empty-ok | PR13.3 |
| Training | `fetchDemoTrainingOverview` | `training/overview.ts` | Training catalog | Medium | P1_replace_with_db_seed | `training_needs` or empty | PR13.3 |
| Job evaluation | `fetchDemoJobEvaluationOverview` | `job-evaluation/overview.ts` | Placeholder grades | Low | P2_keep_dev_fallback_temporarily | Future/not V1 | PR13.2 |
| Contracts | `fetchDemoContractsOverview` | `contracts/overview.ts` | Contract metadata | Medium | P1_replace_with_db_seed | `puls_workflow.contracts` seed | PR13.3 |
| Profile | `fetchDemoProfileOverview` | `profile/overview.ts` | Persona composite | Medium | P1_replace_with_db_seed | Employee + calc reads | PR13.3 |
| Settings | `fetchDemoSettingsOverview` | `settings/overview.ts` | Hub sections | Low | P2_keep_dev_fallback_temporarily | Static hub OK | PR13.2 |
| ERP | `fetchDemoErpOverview` | `setup/erp.ts` | Canias metadata | Medium | P1_replace_with_db_seed | `erp_connections` + mappings | PR13.3 |
| AI Coach | `fetchDemoAiCoachOverview` | `ai-coach/overview.ts` | Teaser capabilities | Low | static_placeholder_ok | PR13.6 DB context | PR13.6 |
| Menu shell | `fetchDemoMenuTenantFallback` | `menu/overview.ts` | Tenant counts | Low | P2_keep_dev_fallback_temporarily | `menu_overview` seed | PR13.3 |

## Adapters without direct `puls-demo-data` import

| Adapter | Note |
|---------|------|
| `performance/cycles.ts` | Real DB only — no `fetchDemo` |
| `leave/requests.ts`, `expense/claims.ts` | Real RPC mutations |
| `workflow/approvals.ts` | Real `decide_approval_request` RPC |

## Request-creation-readiness composite

[`setup/request-creation-readiness.ts`](../../src/lib/data/setup/request-creation-readiness.ts) composes multiple `fetchDemo*` calls for leave/expense create flows — **P0_retire_for_packaging** as a dependency hub.

## PR13.2 handoff

PR13.2 will:

1. Prioritize P0/P1 rows into sprintable retirement tasks
2. Add grep/check script for new `fetchDemo` introductions (optional)
3. Define done criteria per route when `source: real` without demo flag

## References

- [`13_feature_db_coverage_inventory.md`](./13_feature_db_coverage_inventory.md)
- [`13_demo_data_packaging_principles.md`](./13_demo_data_packaging_principles.md)
- [`../data/11_demo_fallback_guard_matrix.md`](../data/11_demo_fallback_guard_matrix.md)
