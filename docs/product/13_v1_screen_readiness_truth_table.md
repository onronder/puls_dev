# PR13.10 — V1 Screen Readiness Truth Table

This truth table is the final PR13 route-level packaging proof surface. It records what each V1 route shows with **`VITE_PULS_DEMO_MODE=false`** against the remote Puls Teknik A.S. proof tenant.

## Proof Context

| Field | Value |
|-------|-------|
| Environment | Remote Supabase development |
| Tenant | Puls Teknik A.S. |
| Tenant UUID | `a0000001-0001-4001-8001-000000000001` |
| Proof data | PR13.4 baseline + PR13.5 scenarios + PR13.6/13.7 validations |
| Auth proof | PR13.9 `05` + `06` passed with remote personas |
| App mode | `VITE_PULS_DEMO_MODE=false` |
| Route smoke date | 2026-06-01 |
| Browser personas | `calisan@puls.demo` for employee self-service; `admin@puls.demo` in Yönetici Modu for setup/admin deep links |

## Status Legend

| Status | Meaning |
|--------|---------|
| `demo_ready_core` | Core V1 demo path is DB-backed and usable with accepted limitations. |
| `partial_v1` | DB-backed context exists, but production depth or runtime action scope is intentionally limited. |
| `placeholder_future` | Intentional future module placeholder; not a V1 completeness claim. |
| `blocked` | Route failed smoke or depends on missing proof data. |

## Route Truth Table

| Route | Persona | Business purpose | Canonical DB / adapter | Seed/scenario coverage | Source posture | Demo pill | Readiness | Accepted gap |
|-------|---------|------------------|------------------------|------------------------|----------------|-----------|-----------|--------------|
| `/dashboard` | employee | Executive KPI and work queue overview | `puls_calc.dashboard_overview`, leave/expense/performance calc | 120 employees, workflow scenarios, calc rows | `source: real` | Not visible | `demo_ready_core` | Production analytics depth is post-demo. |
| `/sirket-kurulum` | hr_admin | Tenant setup readiness | `puls_calc.setup_readiness_summary`, `puls_core`, setup adapters | Tenant, legal entity, org, assignment rows | `source: real` | Not visible | `demo_ready_core` | No live onboarding wizard completion flow. |
| `/calisanlar` | hr_admin | Employee directory and assignment quality | `puls_core.employees`, `puls_calc.employee_list_overview` | 120 employees + assignments | `source: real` | Not visible | `demo_ready_core` | Real customer HRIS import remains PR14+. |
| `/departmanlar` | hr_admin | Department management and source labels | `puls_core.departments`, `puls_calc.organization_overview` | 12 departments, 4 Canias-imported | `source: real` | Not visible | `demo_ready_core` | Imported rows are read-only by design. |
| `/pozisyonlar` | hr_admin | Position management and source labels | `puls_core.positions`, `puls_calc.organization_overview` | 36 positions, 5 Canias-imported | `source: real` | Not visible | `demo_ready_core` | Imported rows are read-only by design. |
| `/izin-tanimlari` | hr_admin | Leave type setup and policy binding | `puls_workflow.leave_types`, policies, lifecycle events | 8 leave types, inactive historical type | `source: real` | Not visible | `demo_ready_core` | Lifecycle RPC proof is in `06`; UI toggle depth is limited. |
| `/izin` | employee | Leave balances, requests, approval state | `puls_calc.leave_overview`, `puls_workflow.leave_requests` | 120 balances, 30 scenario requests | `source: real` | Not visible | `demo_ready_core` | Mutation UX beyond smoke remains limited. |
| `/masraf-kategorileri` | hr_admin | Expense category and cost-center readiness | `puls_workflow.expense_categories`, `puls_core.cost_centers`, integration maps | 10 categories, 15 cost centers, Canias map | `source: real` | Not visible | `demo_ready_core` | Lifecycle RPC proof is in `06`; no ERP account runtime. |
| `/masraf` | employee | Expense claim overview and approval state | `puls_calc.expense_overview`, `puls_workflow.expense_claims` | 30 scenario claims with policy statuses | `source: real` | Not visible | `demo_ready_core` | Mutation UX beyond smoke remains limited. |
| `/performans` | manager | Performance cycle, score, and evaluation overview | `puls_calc.performance_overview`, `puls_performance.*` | Active cycle, 45 scores, 45 evaluations | `source: real` | Not visible | `demo_ready_core` | Production calibration/deep analytics are later. |
| `/performans-parametreleri` | hr_admin | Performance parameter setup | `competency_templates`, `kpi_category_weights`, `score_bands` | Templates, weights, bands, scenario KPIs | `source: real` | Not visible | `demo_ready_core` | No complex template builder claim. |
| `/kariyer` | hr_admin | Career readiness and growth profile overview | `puls_performance.career_profiles`, training needs | 25 career profiles | `source: real` | Not visible | `partial_v1` | Representative surface only; full career engine PR14+. |
| `/egitim` | hr_admin | Training needs overview | `puls_performance.training_needs` | 30 training needs | `source: real` | Not visible | `partial_v1` | No LMS/catalog runtime. |
| `/is-degerleme` | any | Job evaluation placeholder | Static route posture | No PR13 DB proof target | `source: real` shell | N/A | `placeholder_future` | Future module, not a V1 readiness claim. |
| `/sozlesmeler` | hr_admin | Contract metadata and risk overview | `puls_calc.contracts_overview`, `puls_workflow.contracts` | 20 contracts | `source: real` | Not visible | `demo_ready_core` | Metadata only; no e-signature runtime. |
| `/profil` | employee | Linked user profile | `puls_core.employees.user_id`, profile adapter | Remote `05` linked employee persona | `source: real` | Not visible | `demo_ready_core` | Incomplete-setup edge is optional. |
| `/ayarlar` | admin | Settings hub and tenant/account posture | settings adapter, tenant context | Tenant metadata + auth context | `source: real` | Not visible | `partial_v1` | Hub/read-only depth; production settings breadth later. |
| `/erp` | hr_admin | Canias metadata readiness | `erp_connections`, `erp_field_mappings`, `source_namespaces` | Inactive Canias connection, 12 mappings | `source: real` | Not visible | `partial_v1` | No Canias runtime, sync, or writes. |
| `/ai-koc` | employee | AI Coach context readiness and guardrails | AI coach adapter + calc/core/workflow/integration context | 8 DB context domains | `source: real` | Not visible | `partial_v1` | No live chat, no autonomous actions. |
| `/menu` | any | Navigation shell and menu overview | `puls_calc.menu_overview` | Menu overview rows | `source: real` | N/A | `demo_ready_core` | Shell exception; no demo pill expected. |

## Smoke Notes

- Remote DB ingest and auth proof were already green in PR13.9.
- Route smoke uses the browser with demo mode explicitly off.
- PR13.10 route smoke found and fixed two app blockers before signoff: auth persona resolution now checks `puls_core.employees.user_id` first, and setup route guarding waits for persona resolution before redirecting deep links.
- The absence of a visible demo pill is the UI signal that no route fell back to embedded TypeScript demo data.
- Stale user-facing demo copy on setup/settings surfaces was removed from the smoke path; it was copy drift, not a demo-source fallback.
- Some routes intentionally remain `partial_v1` because production business depth is out of PR13 scope.

## Final Route Claim

PULS V1 has a DB-backed customer-demo packaging proof for the core product route set using the remote Puls Teknik A.S. proof tenant, scenario scripts, and demo mode off. ERP runtime and live AI are explicitly future work. Some screens are partial or future by design and are tracked above.
