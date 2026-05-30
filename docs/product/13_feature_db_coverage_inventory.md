# PR13.1 — Feature DB Coverage Inventory

Evidence-backed inventory deepening [`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md) with route → adapter → DB object coverage, completeness classes, demo needs, embedded demo dependencies, and AI context relevance.

**Documentation-only.** This PR inventories; PR13.2+ acts on the inventory.

## Executive summary

PR13.1 verifies each PR13.0 matrix row against implemented adapters and migrations. **No readiness labels are upgraded silently** — inventory documents current capability and packaging gaps.

Key findings:

- **20 PR12 read-model routes** represented; matrix preserves `/performans` overview + cycles split and `/menu` shell row (21 capability rows total).
- Product-facing data spans `puls_core`, `puls_workflow`, `puls_performance`, `puls_integration`, `puls_calc`.
- **Currently observed** 9 product-facing calc views in `puls_calc` (see [`13_db_table_completeness_classes.md`](./13_db_table_completeness_classes.md)).
- Rich UI on many surfaces still depends on `fetchDemo*` / `puls-demo-data.ts` when DB is empty (see [`13_embedded_demo_dependency_map.md`](./13_embedded_demo_dependency_map.md)).

## Inventory methodology

1. Start from PR13.0 matrix row (feature + route).
2. Trace route → primary/secondary adapters under `src/lib/data/**`.
3. Grep adapter for `.from()`, `.rpc()`, schema client (`pulsCore`, `pulsWorkflow`, `pulsCalc`, etc.).
4. Cross-check object names in `supabase/migrations/**`.
5. Assign completeness class and embedded demo dependency from adapter `resolveAdapterData*` wiring.
6. Note AI context relevance per [`13_ai_context_data_requirements.md`](./13_ai_context_data_requirements.md).

Status taxonomy inherited from PR13.0: `production_ready` · `production_partial` · `db_backed_demo_required` · `embedded_demo_only` · `future_candidate` · `not_v1`.

## Completeness class taxonomy

| Class | Meaning |
|-------|---------|
| `required seeded` | Demo tenant must have baseline rows for V1 packaging proof |
| `required scenario-generated` | Created by workflow smoke / scenario scripts |
| `readable empty-ok` | UI valid with zero rows; honest empty state |
| `future/not V1` | Out of V1 packaging scope |
| `sensitive/system` | Auth, audit, vault — not demo narrative |

## Feature DB coverage matrix

| Feature | Route/surface | Primary adapter(s) | Secondary adapter(s) | Backend objects | DB schema group | Current data source posture | Completeness class | Demo data requirement | Embedded demo dependency | AI context relevance | Follow-up PR |
|---------|---------------|-------------------|------------------------|-----------------|-----------------|------------------------------|-------------------|----------------------|--------------------------|---------------------|--------------|
| Dashboard | `/dashboard` | `dashboard/overview.ts` | — | `puls_calc.dashboard_overview`, `leave_overview`, `expense_overview`, `puls_integration.erp_connections`, `erp_field_mappings` | `puls_calc`, `puls_integration` | Real calc reads when seeded; composite `fetchDemoDashboardPageData` when empty | `required seeded` (calc + ERP metadata) | KPIs, queues, tenant counts | `fetchDemoDashboardOverview`, `fetchDemoLeaveOverview`, `fetchDemoExpenseOverview` — **P0_retire_for_packaging** | Dashboard insight summary | PR13.3, PR13.5 |
| Company setup readiness | `/sirket-kurulum` | `setup/setup-readiness-dashboard.ts`, `setup/company.ts` | `setup/org-setup-readiness.ts`, `setup/employee-assignment-readiness.ts` | `puls_calc.setup_readiness_summary`, `puls_core.tenants`, `employees`, `puls_performance.performance_cycles`, `erp_field_mappings` | `puls_calc`, `puls_core`, `puls_integration`, `puls_performance` | Real readiness when tenant has rows; `fetchDemoCompanySetup` fallback | `required seeded` | Tenant, org, assignments, readiness aggregates | `fetchDemoCompanySetup`, `fetchDemoEmployeeAssignmentReadiness` — **P1_replace_with_db_seed** | Setup coach | PR13.3, PR13.5 |
| Employee directory | `/calisanlar` | `core/employees.ts` | `setup/employee-assignment-readiness.ts` | `puls_core.employees`, `puls_calc.employee_list_overview`, `leave_overview` | `puls_core`, `puls_calc` | Real list when rows exist; list/stats demo wrappers when empty | `required seeded` | 20-40 employees, assignment completeness | `fetchDemoEmployeesOverview`, inline demo list/stats — **P0_retire_for_packaging** | Employee data quality coach | PR13.3 |
| Departments | `/departmanlar` | `core/organization.ts` | — | `puls_calc.organization_overview`, `puls_core.departments` | `puls_calc`, `puls_core` | Source-aware mixed CRUD: PULS-owned create/update; imported read-only | `required seeded` | PULS-owned + imported/source-owned dept rows | `fetchDemoDepartmentsOverview` — **P1_replace_with_db_seed** | Setup coach | PR13.3 |
| Positions | `/pozisyonlar` | `core/organization.ts` | — | `puls_calc.organization_overview`, `puls_core.positions` | `puls_calc`, `puls_core` | Source-aware mixed CRUD | `required seeded` | PULS-owned + imported/source-owned position rows | `fetchDemoPositionsOverview` — **P1_replace_with_db_seed** | Setup coach | PR13.3 |
| Leave setup | `/izin-tanimlari` | `setup/leave-types.ts` | `workflow/policies.ts` | `puls_workflow.leave_types`, `approval_policies`, `approval_policy_steps`, `leave_type_lifecycle_events` | `puls_workflow` | Real CRUD + lifecycle RPCs; demo overview fallback | `required seeded` | Leave types, policies, steps | `fetchDemoLeaveTypesOverview`, `fetchDemoApprovalPoliciesOverview` — **P1_replace_with_db_seed** | Setup coach | PR13.3 |
| Leave request | `/izin` | `leave/overview.ts`, `leave/requests.ts` | `setup/request-creation-readiness.ts`, `workflow/approvals.ts` | `puls_calc.leave_overview`, `leave_balances`, `leave_requests`, `leave_types`, `puls_workflow.approval_requests`; RPC `create_leave_request`, `decide_approval_request` | `puls_calc`, `puls_workflow` | Create RPC real; overview demo fallback | `required seeded` + `required scenario-generated` (requests) | Balances/types seeded; sample requests via scenario | `fetchDemoLeaveOverview`, readiness demo composite — **P0_retire_for_packaging** | Leave request helper | PR13.5 |
| Expense categories | `/masraf-kategorileri` | `setup/expense-categories.ts` | `setup/cost-center-readiness.ts`, `workflow/policies.ts` | `puls_workflow.expense_categories`, `expense_category_lifecycle_events`, `puls_core.cost_centers`; RPC deactivate/restore | `puls_workflow`, `puls_core` | Real CRUD; overview demo fallback | `required seeded` | Categories, cost centers, policy bindings | `fetchDemoExpenseCategoriesOverview`, `fetchDemoCostCenterReadinessOverview` — **P1_replace_with_db_seed** | Setup coach | PR13.3 |
| Expense claim | `/masraf` | `expense/overview.ts`, `expense/claims.ts` | `setup/request-creation-readiness.ts`, `workflow/approvals.ts` | `puls_calc.expense_overview`, `expense_claims`, `expense_categories`, `puls_workflow.approval_requests`; RPC `create_expense_claim` | `puls_calc`, `puls_workflow` | Create RPC real; overview demo fallback | `required seeded` + `required scenario-generated` | Categories seeded; sample claims via scenario | `fetchDemoExpenseOverview`, readiness demo — **P0_retire_for_packaging** | Expense claim helper | PR13.5 |
| Performance overview | `/performans` | `performance/overview.ts` | — | `puls_calc.dashboard_overview`, `puls_performance.competency_templates`, `competency_evaluations`, `employees` | `puls_calc`, `puls_performance`, `puls_core` | Real reads partial; rich UI demo-heavy | `required seeded` | Scores, templates, cycle context | `fetchDemoPerformanceOverview` — **P0_retire_for_packaging** | Performance manager coach | PR13.3, PR13.5 |
| Performance cycles | `/performans` | `performance/cycles.ts` | — | `puls_performance.performance_cycles`, `competency_templates` | `puls_performance` | Real insert/update; no demo fetch in cycles adapter | `required seeded` | Active/draft cycles | None in cycles adapter — **no embedded demo** | Performance manager coach | PR13.3, PR13.5 |
| Career | `/kariyer` | `career/overview.ts` | — | `puls_core.employees`, `puls_performance.career_profiles`, `training_needs` | `puls_core`, `puls_performance` | WithMeta; weak DB coverage; demo fills UI | `future/not V1` depth | Optional career map rows | `fetchDemoCareerOverview` — **P0_retire_for_packaging** | Career guidance (future) | PR13.3 |
| Training | `/egitim` | `training/overview.ts` | — | `puls_performance.training_needs` | `puls_performance` | WithMeta; weak DB coverage | `readable empty-ok` | Optional catalog rows | `fetchDemoTrainingOverview` — **P1_replace_with_db_seed** | Training recommender (future) | PR13.3 |
| Job evaluation | `/is-degerleme` | `job-evaluation/overview.ts` | — | None on real path | — | Static/placeholder real path | `future/not V1` | — | `fetchDemoJobEvaluationOverview` — **P2_keep_dev_fallback_temporarily** | — | PR13.1 |
| Contracts metadata | `/sozlesmeler` | `contracts/overview.ts` | — | `puls_calc.dashboard_overview`, `puls_workflow.contracts` | `puls_calc`, `puls_workflow` | Real metadata read when rows exist; demo for empty rich UX | `required seeded` | Contract summary rows | `fetchDemoContractsOverview` — **P1_replace_with_db_seed** | Contract risk explainer | PR13.3 |
| Profile/account | `/profil` | `profile/overview.ts` | — | `puls_core.employees`, `puls_calc.leave_overview`, `expense_overview`, `performance_overview`, `expense_claims` count | `puls_core`, `puls_calc`, `puls_workflow` | Auth→employee path; no silent demo on `tenant_without_employee` | `required seeded` | Persona-linked employee | `fetchDemoProfileOverview` — **P1_replace_with_db_seed** | Profile/persona assistant | PR13.3 |
| Settings | `/ayarlar` | `settings/overview.ts` | — | Static section list (hub links) | — | Hub only; no domain DB reads on real path | `readable empty-ok` | — | `fetchDemoSettingsOverview` — **P2_keep_dev_fallback_temporarily** | — | PR13.1 |
| ERP setup/readiness | `/erp` | `setup/erp.ts` | — | `puls_integration.erp_connections`, `erp_field_mappings`, `erp_sync_batches`, `setup_readiness_summary` | `puls_integration`, `puls_calc` | Read-only metadata; Canias label; demo fallback | `required seeded` | Inactive Canias connection + sample mappings | `fetchDemoErpOverview` — **P1_replace_with_db_seed** | Setup coach | PR13.7 |
| Menu / shell navigation | `/menu` | `menu/overview.ts` | — | `puls_calc.menu_overview` | `puls_calc` | Shell exception; no WithMeta/demo pill; tenant fallback when empty | `required seeded` | Tenant employee/dept/position counts | `fetchDemoMenuTenantFallback` — **P2_keep_dev_fallback_temporarily** | — | PR13.3 |
| AI Coach | `/ai-koc` | `ai-coach/overview.ts` | — | None (static constants); `puls_vault` passive | `puls_vault` | Static/teaser; not product-ready | `sensitive/system` (future context) | PR13.6 context inventory | `fetchDemoAiCoachOverview`, `STATIC_AI_COACH_OVERVIEW` — **static_placeholder_ok** | All touchpoints (target) | PR13.6 |
| Performance parameters | `/performans-parametreleri` | `setup/performance-parameters.ts` | — | `competency_templates`, `kpi_category_weights`, `score_bands`, `performance_cycles` | `puls_performance` | Tenant reads when seeded; demo fallback | `required seeded` | Templates, bands, weights | `fetchDemoPerformanceParametersOverview` — **P1_replace_with_db_seed** | Setup coach | PR13.3 |

## Coverage gaps (summary)

| Gap | Affected features | Follow-up |
|-----|-------------------|-----------|
| Embedded demo masks empty DB | Dashboard, leave/expense overviews, performance, career, training | PR13.2 retirement plan; PR13.5 bootstrap |
| Calc views need base-table seed | All `puls_calc.*` consumers | PR13.3 demo spec |
| Org dual-class demo rows | Departments, positions | PR13.3 import/seed |
| AI has no DB context reads | AI Coach + all touchpoints | PR13.6 |
| Canias runtime | ERP setup | PR13.7 discovery only |

## PR13.2 handoff

PR13.2 will convert embedded demo inventory into an actionable retirement plan (see [`13_embedded_demo_dependency_map.md`](./13_embedded_demo_dependency_map.md)).

## References

- [`13_v1_feature_traceability_matrix.md`](./13_v1_feature_traceability_matrix.md)
- [`13_db_table_completeness_classes.md`](./13_db_table_completeness_classes.md)
- [`13_embedded_demo_dependency_map.md`](./13_embedded_demo_dependency_map.md)
- [`13_ai_context_data_requirements.md`](./13_ai_context_data_requirements.md)
- [`../data/11_sidebar_data_api_inventory.md`](../data/11_sidebar_data_api_inventory.md)
- [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md)
