# PR11.0 — Sidebar Data/API Inventory

Canonical source-of-truth for sidebar and setup-linked routes: data adapters, Supabase tables/RPCs, CRUD/read-only posture, tenant/RLS dependencies, demo fallback boundaries, and Swagger/OpenAPI candidates.

**Documentation-only artifact.** No app source, migration, CRUD, resolver, or ERP write changes in PR11.0.

## Executive summary

PR10 established setup/readiness for expense, leave, org, assignments, request creation, and the unified setup dashboard (`/sirket-kurulum`). PR11.0 freezes the **whole-app route inventory** so PR11.1–PR11.9 proceed without guesswork.

| Coverage | Count | Notes |
|----------|-------|-------|
| Sidebar-visible routes | **12** | From `sidebarGroups` in `src/lib/navigation.ts` |
| Setup-linked routes (via `/ayarlar` hub) | **7** | From `adminSetupNavItems` |
| Mobile shell (non-domain) | **1** | `/menu` reuses sidebar groups |
| Route alias | `/` → `/dashboard` | Redirect in `src/routes/index.tsx` |

### Top 5 risks discovered

1. **P1_runtime:** Broad `resolveAdapterData` demo fallback (`VITE_PULS_DEMO_MODE`) can render rich UI when real tenant data is empty or fetch fails.
2. **P2_data_quality:** Adapter-level **inline demo stubs** (not centralized in `puls-demo-data.ts`) on employee list/stats and performance cycles can mask empty tenants.
3. **P2_data_quality:** HR modules (`/kariyer`, `/egitim`, `/sozlesmeler`) serve demo/overview data while UI marks some actions `common.soon`.
4. **P1_runtime:** Org dept/pos routes are **read-only** while category/type setup routes expose full CRUD — inconsistent admin expectations.
5. **P0_security:** RPC smoke with `service_role` alone does not represent user JWT auth; authenticated context (`request.jwt.claim.sub`) required per PR10.16.1.

---

## Status taxonomy

### Screen data status

| Value | Meaning |
|-------|---------|
| `production_real` | Primary UX path reads/writes real tenant Supabase data when present |
| `production_readonly` | Real reads; no create/update/delete UI on route |
| `production_partial` | Mix of real adapters and gaps (aggregators, static real paths, or incomplete wiring) |
| `demo_fallback` | `resolveAdapterData*` may serve demo when real empty/error and demo flag on |
| `placeholder` | Real adapter path is static/empty; meaningful content is demo-only or UI-only |
| `unknown` | Not inventoried or adapter failure surface unclear |

### Mutation status

| Value | Meaning |
|-------|---------|
| `none` | No writes from route |
| `read_only` | SELECT-only |
| `create` | Insert/RPC create only |
| `update` | Update only |
| `delete_or_lifecycle` | Deactivate/restore RPCs |
| `rpc_action` | Domain actions via Supabase RPC (create claim/request) |
| `mixed` | Multiple mutation types |
| `unknown` | Not verified |

### Risk tier

| Value | Meaning |
|-------|---------|
| `P0_security` | Auth/RLS/JWT context |
| `P1_runtime` | Wrong data shown, demo masking, inconsistent admin UX |
| `P2_data_quality` | Partial real data, soon UI vs demo data tension |
| `P3_polish` | Copy, empty states, non-blocking gaps |

### Swagger candidate type

| Value | Meaning |
|-------|---------|
| `supabase_table` | Direct table REST exposure candidate |
| `supabase_rpc` | Postgres RPC |
| `edge_function` | Supabase Edge Function |
| `internal_adapter` | App-only composed model |
| `external_api` | ERP/third-party |
| `none` | Not an API surface |

---

## Route coverage matrix

Sidebar-visible routes (`src/lib/navigation.ts` → `sidebarGroups`).

| Sidebar group | Route | Screen | Data status | Adapter(s) | Tables / views | RPCs | Mutations | Demo fallback | Tenant/RLS posture | Risk | Follow-up |
|---------------|-------|--------|-------------|------------|----------------|------|-----------|---------------|-------------------|------|-----------|
| Ana | `/dashboard` | Ana Sayfa | `production_partial` | `fetchDashboardOverview` | `puls_calc.dashboard_overview`, `leave_overview`, `expense_overview`; `puls_integration.erp_*` | — | `none` | Yes (`fetchDemoDashboardOverview`) | `resolveTenantContext`; calc views tenant-scoped | P1_runtime | PR11.7 |
| İK Yönetimi | `/performans` | Performans | `demo_fallback` | `fetchPerformanceOverview`, `fetchPerformanceCycles`, `fetchCompetencyTemplates`, cycle CRUD | `puls_calc.dashboard_overview`, `puls_performance.performance_cycles`, `competency_templates`, `competency_evaluations` | — | `mixed` | Yes (overview demo; cycles inline stub → `[]`) | Tenant-scoped reads; cycle insert/update direct | P2_data_quality | PR11.5 |
| İK Yönetimi | `/calisanlar` | Çalışanlar | `production_partial` | `fetchEmployeesOverview`, `fetchEmployeeAssignmentReadiness` | `puls_core.employees`, `departments`, `positions`, assignments, reporting lines | — | `read_only` | Yes (overview + assignment demo) | Manager audience; tenant RLS | P2_data_quality | PR11.1 |
| İK Yönetimi | `/kariyer` | Kariyer | `demo_fallback` | `fetchCareerOverview` | `puls_core.employees`, `puls_performance.career_profiles`, `training_needs` | — | `none` | Yes | Tenant joins when real | P2_data_quality | PR11.5 |
| İK Yönetimi | `/egitim` | Eğitim | `demo_fallback` | `fetchTrainingOverview` | `puls_performance.training_needs` | — | `none` | Yes | Tenant-scoped when real | P2_data_quality | PR11.5 |
| İK Yönetimi | `/is-degerleme` | İş Değerleme | `placeholder` | `fetchJobEvaluationOverview` | None on real path | — | `none` | Yes | N/A (static real) | P3_polish | PR11.5 |
| Çalışan Süreçleri | `/izin` | İzin | `production_real` | `fetchLeaveOverview`, `createLeaveRequest`, `fetchRequestCreationReadiness`, `decideApprovalRequest` | `puls_calc.leave_overview`, `puls_workflow.leave_*`, `approval_requests` | `create_leave_request`, `decide_approval_request` | `mixed` | Yes (overview/readiness) | JWT + tenant; PR10.16 hardened | P0_security | PR11.4 |
| Çalışan Süreçleri | `/masraf` | Masraf | `production_real` | `fetchExpenseOverview`, `createExpenseClaim`, `fetchRequestCreationReadiness`, `decideApprovalRequest` | `puls_calc.expense_overview`, `puls_workflow.expense_*`, `approval_requests` | `create_expense_claim`, `decide_approval_request` | `mixed` | Yes (overview/readiness) | JWT + tenant; PR10.16 hardened | P0_security | — |
| Çalışan Süreçleri | `/sozlesmeler` | Sözleşmeler | `demo_fallback` | `fetchContractsOverview` | `puls_calc.dashboard_overview`, `puls_workflow.contracts` | — | `none` | Yes | Tenant when real | P2_data_quality | PR11.6 |
| Yapay Zeka | `/ai-koc` | AI Koç | `placeholder` | `fetchAiCoachOverview` | None (static real constants) | — | `none` | Yes | N/A | P3_polish | PR12+ |
| Yönetici Ayarları | `/ayarlar` | Ayarlar | `demo_fallback` | `fetchSettingsOverview` | None (static section list on real path) | — | `none` | Yes | Tenant context only for audit metadata | P2_data_quality | PR11.8 |
| Hesap | `/profil` | Profil | `demo_fallback` | `fetchProfileOverview` | `puls_core.employees`, `departments`, `positions`; `puls_calc.*`; `puls_workflow.expense_claims` count | — | `none` | Yes | Real reads when employee row exists; demo when empty | P2_data_quality | PR11.8 |

**UI vs data note:** Routes with `common.soon` badges (`/ai-koc`, `/egitim`, `/kariyer`, `/sozlesmeler`) may still show demo/overview data — classify by adapter path, not UI polish alone.

---

## Setup-linked routes

Reached via `/ayarlar` hub (`adminSetupNavItems`); not in desktop sidebar.

| Route | Screen | Data status | Adapter(s) | Tables / views | RPCs | Mutations | Demo fallback | Tenant/RLS | Risk | Follow-up |
|-------|--------|-------------|------------|----------------|------|-----------|---------------|------------|------|-----------|
| `/sirket-kurulum` | Şirket Kurulum | `production_partial` | `fetchCompanySetupOverview`, `fetchSetupReadinessDashboard` | `puls_core.tenants`, `puls_calc.setup_readiness_summary`, composed readiness | — | `read_only` | Yes (partial via child adapters) | Tenant-scoped | P1_runtime | PR11.2 |
| `/masraf-kategorileri` | Masraf Kategorileri | `production_real` | `fetchExpenseCategoriesOverview`, `fetchCostCenterReadinessOverview`, category CRUD, lifecycle | `puls_workflow.expense_categories`, lifecycle events; `puls_core.cost_centers`; integration maps | `deactivate_expense_category`, `restore_expense_category` | `mixed` | Yes (overview/CC) | Admin setup; tenant RLS | P1_runtime | — |
| `/izin-tanimlari` | İzin Tanımları | `production_real` | `fetchLeaveTypesOverview`, `fetchApprovalPoliciesOverview`, leave type CRUD, lifecycle | `puls_workflow.leave_types`, lifecycle events, `approval_policies` | `deactivate_leave_type`, `restore_leave_type` | `mixed` | Yes | Admin setup; tenant RLS | P1_runtime | PR11.3 |
| `/departmanlar` | Departmanlar | `production_readonly` | `fetchDepartmentsOverview` | `puls_calc.organization_overview`, `puls_core.departments` | — | `read_only` | Yes | Tenant RLS SELECT | P1_runtime | PR11.2 |
| `/pozisyonlar` | Pozisyonlar | `production_readonly` | `fetchPositionsOverview` | `puls_calc.organization_overview`, `puls_core.positions` | — | `read_only` | Yes | Tenant RLS SELECT | P1_runtime | PR11.2 |
| `/erp` | ERP | `demo_fallback` | `fetchErpOverview` | `puls_integration.erp_connections`, `erp_field_mappings`, `erp_sync_batches` | — | `read_only` | Yes | Read-only integration metadata | P3_polish | PR12+ |
| `/performans-parametreleri` | Performans Parametreleri | `demo_fallback` | `fetchPerformanceParametersOverview` | `puls_performance.competency_templates`, `kpi_category_weights`, `score_bands`, `performance_cycles` | — | `read_only` | Yes | Tenant-scoped reads | P2_data_quality | PR11.5 |

### Non-sidebar shell

| Route | Role | Adapter | Notes |
|-------|------|---------|-------|
| `/menu` | Mobile navigation shell | `fetchMenuOverview` | Reuses `sidebarGroups`; `fetchDemoMenuTenantFallback` when empty |

---

## Data/API matrix by domain

### Expense domain (post-PR10)

| Concern | Source | Route(s) | Status |
|---------|--------|----------|--------|
| Claims list/create | `expense/overview.ts`, `expense/claims.ts` | `/masraf` | `production_real` create via RPC |
| Categories setup | `setup/expense-categories.ts` | `/masraf-kategorileri` | CRUD + lifecycle RPCs |
| Cost center export readiness | `setup/cost-center-readiness.ts` | `/masraf-kategorileri`, dashboard | Read-only mapping signals |
| Request creation preflight | `setup/request-creation-readiness.ts` | `/masraf`, `/izin` | Composed; policy warnings only |
| Setup dashboard section | `setup/setup-readiness-dashboard.ts` | `/sirket-kurulum` | Read-only aggregator |

**Tables:** `puls_workflow.expense_claims`, `expense_categories`, `expense_category_lifecycle_events`, `approval_requests`; `puls_calc.expense_overview`.

**RPCs:** `create_expense_claim`, `deactivate_expense_category`, `restore_expense_category`.

**Gaps:** Policy editor UI absent; import apply not app-exposed.

### Leave domain (post-PR10)

| Concern | Source | Route(s) | Status |
|---------|--------|----------|--------|
| Leave page | `leave/overview.ts`, `leave/requests.ts` | `/izin` | `production_real` |
| Leave types setup | `setup/leave-types.ts` | `/izin-tanimlari` | CRUD + lifecycle RPCs |

**Tables:** `puls_workflow.leave_requests`, `leave_types`, `leave_balances`, lifecycle events; `puls_calc.leave_overview`.

**RPCs:** `create_leave_request`, `deactivate_leave_type`, `restore_leave_type`.

### Approval / policy domain

| Concern | Source | Notes |
|---------|--------|-------|
| Policy list | `workflow/policies.ts` | `/izin-tanimlari` policy picker |
| Policy binding readiness | `workflow/policy-binding-readiness.ts` | Pure; used in setup + request creation |
| Approval decisions | `workflow/approvals.ts` | `decide_approval_request` on `/izin`, `/masraf` |
| Resolver/decide internals | Migrations / RPC | Document only; no app import apply adapter |

**Risk:** Policy step editor and Swagger documentation deferred to PR12+.

### Org / employee domain

| Concern | Source | Route(s) | CRUD |
|---------|--------|----------|------|
| Employees overview | `core/employees.ts` | `/calisanlar` | Read |
| Assignment readiness | `setup/employee-assignment-readiness.ts` | `/calisanlar`, readiness | Read |
| Departments / positions | `core/organization.ts` | `/departmanlar`, `/pozisyonlar` | Read-only UI |
| Org setup summary | `setup/org-setup-readiness.ts` | Composed | Read |
| Company setup | `setup/company.ts` | `/sirket-kurulum` | Read |

**Tables:** `puls_core.employees`, `departments`, `positions`, `cost_centers`, `employee_cost_center_assignments`, `employee_reporting_lines`; `puls_integration.entity_identity_map`.

**Follow-up:** PR11.1 (employees), PR11.2 (org CRUD), PR11.8 (profile ↔ employee mapping).

### Performance / HR modules

| Domain | Adapter | Real data? | Route |
|--------|---------|------------|-------|
| Performance overview | `performance/overview.ts` | Calc + performance schema when populated | `/performans` |
| Performance cycles | `performance/cycles.ts` | Real CRUD; demo list stub | `/performans` |
| Performance parameters | `setup/performance-parameters.ts` | Read setup | `/performans-parametreleri` |
| Career | `career/overview.ts` | Joins when real | `/kariyer` |
| Training | `training/overview.ts` | `training_needs` when real | `/egitim` |
| Job evaluation | `job-evaluation/overview.ts` | **No Supabase on real path** | `/is-degerleme` |
| Contracts | `contracts/overview.ts` | `contracts` table when real | `/sozlesmeler` |

### Dashboard / profile / AI / settings

| Route | Real path behavior | Demo |
|-------|-------------------|------|
| `/dashboard` | Composes calc + integration reads | Full demo dashboard |
| `/profil` | Employee + calc summaries when row exists | Demo profile when empty |
| `/ayarlar` | Static section catalog (no DB) | Demo enriches sheets |
| `/ai-koc` | Static capability constants | Demo variant |

### Import apply (backend-only)

- Migrations/smoke: `09_import_apply_*` — **no app adapter** in `src/lib/data/**`.
- Document as future integration surface; not a current sidebar mutation.

---

## Demo fallback inventory

**Trigger:** `VITE_PULS_DEMO_MODE` + (`resolveAdapterData` / `resolveAdapterDataWithMeta` in `src/lib/data/result.ts`) when real fetch is empty or throws.

### Centralized demo sources (`src/lib/demo/puls-demo-data.ts`)

| Demo function | Consumer domain / adapter | Can write? |
|---------------|---------------------------|------------|
| `fetchDemoDashboardOverview` | Dashboard | No |
| `fetchDemoLeaveOverview` | Leave, dashboard, request creation | No |
| `fetchDemoExpenseOverview` | Expense, dashboard, request creation | No |
| `fetchDemoPerformanceOverview` | Performance | No |
| `fetchDemoEmployeesOverview` | Employees overview | No |
| `fetchDemoEmployeeAssignmentReadiness` | Assignment readiness, request creation | No |
| `fetchDemoCareerOverview` | Career | No |
| `fetchDemoTrainingOverview` | Training | No |
| `fetchDemoJobEvaluationOverview` | Job evaluation | No |
| `fetchDemoContractsOverview` | Contracts | No |
| `fetchDemoAiCoachOverview` | AI coach | No |
| `fetchDemoProfileOverview` | Profile | No |
| `fetchDemoSettingsOverview` | Settings | No |
| `fetchDemoCompanySetup` | Company setup | No |
| `fetchDemoErpOverview` | ERP setup | No |
| `fetchDemoDepartmentsOverview` | Organization | No |
| `fetchDemoPositionsOverview` | Organization | No |
| `fetchDemoLeaveTypesOverview` | Leave types setup | No |
| `fetchDemoExpenseCategoriesOverview` | Expense categories setup | No |
| `fetchDemoApprovalPoliciesOverview` | Policy list | No |
| `fetchDemoCostCenterReadinessOverview` | Cost center readiness | No |
| `fetchDemoPerformanceParametersOverview` | Performance parameters | No |
| `fetchDemoMenuTenantFallback` | Menu shell | No |

### Inline adapter stubs (not in `puls-demo-data.ts`)

Documented by **route/domain** for human review; identifiers may change across refactors.

| Route / domain | Behavior | Risk | Follow-up |
|----------------|----------|------|-----------|
| `/calisanlar` (employee list adapters) | Demo path returns empty list or hardcoded stats counts instead of centralized demo fixtures | Masks empty tenant employee directory | PR11.1 |
| `/performans` (performance cycles list) | Demo path returns empty cycle list while overview may still show demo metrics | Overview vs cycles mismatch | PR11.5 |
| Request creation readiness | Internal demo composer (not exported from demo module) | Can mask assignment/policy gaps in demo mode | PR11.9 |

### WithMeta readiness masking

Adapters exposing `source: 'real' | 'demo'` via `resolveAdapterDataWithMeta`:

- `fetchDepartmentsOverviewWithMeta`, `fetchPositionsOverviewWithMeta`
- `fetchCostCenterReadinessOverviewWithMeta`
- `fetchEmployeeAssignmentReadinessWithMeta`, `fetchCurrentEmployeeAssignmentReadinessWithMeta`
- `fetchRequestCreationReadinessWithMeta`

**Risk:** Demo source on setup/readiness screens can mask true tenant gaps — PR10.17 dashboard treats unknown separately but demo ≠ ready.

---

## Mutation/RPC inventory

App-exposed writes (from `src/lib/data/**` and route mutations).

| Operation | Adapter / route | Supabase table / RPC | Auth context | Error mapping | Smoke / verify | Swagger candidate |
|-----------|-----------------|----------------------|--------------|---------------|----------------|-------------------|
| Create expense claim | `createExpenseClaim` / `/masraf` | `puls_workflow.create_expense_claim` | `auth.uid()` via RPC | `errors.ts` PULS_* map | PR10.16 smoke | `supabase_rpc` — high |
| Create leave request | `createLeaveRequest` / `/izin` | `puls_workflow.create_leave_request` | JWT + employee context | PR10.16 smoke | PR10.16 smoke | `supabase_rpc` — high |
| Decide approval | `decideApprovalRequest` / `/izin`, `/masraf` | `puls_workflow.decide_approval_request` | RPC auth | `approval.error.*` | Partial | `supabase_rpc` — high |
| Create expense category | `createExpenseCategory` / `/masraf-kategorileri` | `expense_categories` INSERT | Tenant RLS + admin | Field validation map | PR10 lifecycle verifies | `supabase_table` — medium |
| Update expense category | `updateExpenseCategory` | `expense_categories` UPDATE | Tenant RLS | Field validation map | PR10 verifies | `supabase_table` — medium |
| Deactivate expense category | lifecycle RPC wrapper | `deactivate_expense_category` | Admin RPC | PULS_* lifecycle map | PR10 smoke | `supabase_rpc` — medium |
| Restore expense category | lifecycle RPC wrapper | `restore_expense_category` | Admin RPC | PULS_* lifecycle map | PR10 smoke | `supabase_rpc` — medium |
| Read expense lifecycle events | `fetchExpenseCategoryLifecycleEvents` | `expense_category_lifecycle_events` | Read | — | PR10 audit smoke | `supabase_table` — low |
| Create leave type | `createLeaveType` / `/izin-tanimlari` | `leave_types` INSERT | Tenant RLS | Validation map | PR10 leave verifies | `supabase_table` — medium |
| Update leave type | `updateLeaveType` | `leave_types` UPDATE | Tenant RLS | Validation map | PR10 verifies | `supabase_table` — medium |
| Deactivate leave type | lifecycle RPC wrapper | `deactivate_leave_type` | Admin RPC | PULS_* map | PR10 smoke | `supabase_rpc` — medium |
| Restore leave type | lifecycle RPC wrapper | `restore_leave_type` | Admin RPC | PULS_* map | PR10 smoke | `supabase_rpc` — medium |
| Read leave lifecycle events | `fetchLeaveTypeLifecycleEvents` | `leave_type_lifecycle_events` | Read | — | PR10 audit smoke | `supabase_table` — low |
| Create performance cycle | `createPerformanceCycle` / `/performans` | `puls_performance.performance_cycles` INSERT | Tenant context | Adapter errors | **Gap** — no PR10 smoke | `supabase_table` — medium |
| Update performance cycle | `updatePerformanceCycle` / `/performans` | `performance_cycles` UPDATE | Tenant context | Adapter errors | **Gap** | `supabase_table` — medium |
| Import batch apply | Migration-only | Integration RPC/SQL | Service role / backend | Smoke `09_*` | Not app-exposed | `supabase_rpc` — low (internal) |
| Setup readiness dashboard | `fetchSetupReadinessDashboard` | Composed reads | User JWT | — | PR10.17 verify | `internal_adapter` — low |

**Note:** Performance cycle CRUD exists in app but sits **outside PR10** verify/smoke coverage — mark as PR11.5 follow-up.

---

## Tenant/RLS/security notes

| Domain | Current tenant guard | RLS reliance | Risk | Follow-up |
|--------|---------------------|--------------|------|-----------|
| Core org (`employees`, `departments`, `positions`) | `resolveTenantContext` + `.eq('tenant_id', …)` | Postgres RLS on `puls_core.*` | P0 if unscoped query added | PR11.1, PR11.2 |
| Workflow (claims, requests, categories, types) | Tenant context + RPC `auth.uid()` | RLS + SECURITY DEFINER RPCs | P0_security | PR11.4 |
| Calc views (`puls_calc.*`) | Tenant filter on all reads | View definitions assume tenant_id | P1_runtime empty views | PR11.7 |
| Integration reads (`erp_*`, identity maps) | Tenant scoped | Read-only RLS | No ERP writes from app | PR12+ |
| Demo mode | `VITE_PULS_DEMO_MODE` env flag | Bypasses empty real — not auth bypass | P1_runtime masking | PR11.9 |
| Smoke / SQL editor | `service_role` | Full access | P0 if confused with user auth | Document JWT claim pattern |

**Locked callouts:**

- Direct Supabase table reads must remain tenant-scoped.
- RPCs rely on `auth.uid()` and employee resolution — smoke must set `request.jwt.claim.sub` for create paths (PR10.16.1).
- No ERP/external writes from current app adapters.
- Demo fallback is not production behavior (`docs/data/README.md` principle).

---

## Swagger/OpenAPI candidates

Inventory only — no generator in PR11.0.

| Candidate | Type | Source | Public / internal | Priority | Notes |
|-----------|------|--------|-------------------|----------|-------|
| `create_expense_claim` | `supabase_rpc` | `puls_workflow` | Internal (Supabase client) | High | Positional signature documented in PR10.16 smoke |
| `create_leave_request` | `supabase_rpc` | `puls_workflow` | Internal | High | Same |
| `decide_approval_request` | `supabase_rpc` | `puls_workflow` | Internal | High | Approval inbox actions |
| `deactivate_expense_category` / `restore_expense_category` | `supabase_rpc` | `puls_workflow` | Internal | Medium | Admin lifecycle |
| `deactivate_leave_type` / `restore_leave_type` | `supabase_rpc` | `puls_workflow` | Internal | Medium | Admin lifecycle |
| Expense category CRUD | `supabase_table` | `expense_categories` | Internal | Medium | REST via supabase-js |
| Leave type CRUD | `supabase_table` | `leave_types` | Internal | Medium | REST via supabase-js |
| Lifecycle event reads | `supabase_table` | lifecycle event tables | Internal | Low | Audit read surfaces |
| Import apply | `supabase_rpc` | `puls_integration` | Internal / backend | Low | Not app-exposed |
| Setup readiness dashboard model | `internal_adapter` | Composed TS types | Internal | Low | PR10.17 — documentation of internal DTO |
| Profile / settings | `internal_adapter` | Static + composed reads | Internal | Low | PR11.8 before public API |

---

## PR11 follow-up map

| PR | Scope | Inputs from this inventory | Expected output |
|----|-------|---------------------------|-----------------|
| PR11.1 | Employees foundation audit/fix | `/calisanlar`, `core/employees`, assignment readiness, inline list stubs | Real employee list/stats; RLS audit; profile mapping inputs |
| PR11.2 | Org setup CRUD readiness | `/departmanlar`, `/pozisyonlar`, `/sirket-kurulum` | Safe dept/pos CRUD or explicit read-only contract |
| PR11.3 | Leave setup parity | `/izin-tanimlari` vs expense category feature parity | Close remaining setup gaps |
| PR11.4 | Leave consumption hardening | `/izin`, create/decide RPCs, readiness | Remaining UX/API gaps post-PR10.16 |
| PR11.5 | Performance / Kariyer / Eğitim / İş Değerleme | `/performans`, `/kariyer`, `/egitim`, `/is-degerleme`, `/performans-parametreleri`, cycle CRUD | Real vs placeholder classification; cycle smoke |
| PR11.6 | Contracts data readiness | `/sozlesmeler`, `contracts/overview` | Contract adapter/RLS/API truth |
| PR11.7 | Dashboard readiness | `/dashboard`, `puls_calc.dashboard_overview` | Real metrics when tenant populated |
| PR11.8 | Profile / account readiness | `/profil`, `/ayarlar`, auth→employee | Honest real path; settings mutations decision |
| PR11.9 | App-wide demo fallback guard | All routes, `resolveAdapterData*`, inline stubs | Bounded demo; no silent masking |
| PR12.0+ | Swagger/OpenAPI | Mutation/RPC inventory above | Generated or hand-maintained API docs |

### Risk → PR ownership

| Risk | Owning PR |
|------|-----------|
| P1 demo masking (broad) | PR11.9 |
| P2 inline stubs on `/calisanlar` | PR11.1 |
| P2 HR soon vs demo data | PR11.5, PR11.6 |
| P1 org read-only vs setup CRUD split | PR11.2 |
| P0 JWT/smoke auth context | PR11.4 (+ test docs) |

---

## Verification notes

Re-run PR11.0 guard:

```bash
./scripts/verify-11-sidebar-data-api-inventory.sh HEAD
node scripts/check-sensitive-grep.mjs
pnpm check-i18n && pnpm test && pnpm build
```

Related PR10 smoke (post-merge manual SQL editor):

- `docs/data/10_request_creation_hardening_smoke.sql`
- `docs/data/10_setup_readiness_dashboard_smoke.sql`
- `docs/data/10_org_setup_readiness_smoke.sql`
- `docs/data/10_employee_assignment_readiness_smoke.sql`

Prior matrix docs (still valid for subdomains):

- `docs/data/10_org_setup_readiness_matrix.md`
- `docs/data/10_employee_assignment_readiness_matrix.md`

**PR11.0 does not require** Supabase db lint, db push, or new smoke SQL.
