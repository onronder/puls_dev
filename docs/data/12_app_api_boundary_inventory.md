# PR12.0 — App-wide API Boundary Inventory

Reference: [`11_sidebar_data_api_inventory.md`](./11_sidebar_data_api_inventory.md) · PR11 matrices/smokes under `docs/data/`

## 1. Executive summary

**Purpose:** Freeze the full app-wide API boundary before PR12.1 Swagger/OpenAPI generation. This document inventories every relevant surface — app-exposed writes, read models, internal backend SQL, auth/RLS assumptions, error contracts, and smoke coverage — and classifies each with an honest OpenAPI inclusion decision.

**Scope:** App-wide boundary inventory **yes**; app-wide public API promise **no**. Read models and internal helpers are documented but not promoted to public OpenAPI endpoints unless PR12.1 explicitly decides otherwise.

**Docs-only:** PR12.0 adds documentation and verify only. **No generated Swagger yet** — no `openapi.yaml`, `swagger.json`, or `openapi.json`.

**Exact counts:**

| Category | Count | Notes |
|----------|------:|-------|
| `app_exposed_mutation` adapters | **17** | 7 RPC-backed + 10 direct table-write adapters |
| Mutation contract groups | **12** | 7 RPC contracts + 5 direct table-write backend groups |
| Read-model route groups | **20** | 19 standard inventory routes + `/menu` shell exception |
| Internal backend-only groups | **6+** | Import batch (3 RPCs), resolver helpers (2+), trigger/guardrail functions |
| Not-app-exposed / future groups | **10+** | ERP write-back, employee editor, policy editor, contracts upload, profile/security writes, AI execution, external API, edge functions |

**Principle:** Classify boundaries before Swagger. PR12.1 generates OpenAPI from the inclusion map in §12.

---

## 2. Boundary taxonomy

### Boundary classes

| Class | Meaning |
|-------|---------|
| `app_exposed_mutation` | UI-triggered write/RPC/table mutation with a `src/lib/data` adapter and route handler |
| `app_read_model` | UI-read adapter/view/table surface; may use `fetch*OverviewWithMeta` for source honesty |
| `internal_backend_only` | SQL/RPC/helper used by backend/migrations/resolver chain; no app adapter or route |
| `not_app_exposed` | Exists in schema or infra but no current app path |
| `future_candidate` | Product/API candidate; UI may hint but no working adapter |

### OpenAPI inclusion decisions

| Decision | Meaning |
|----------|---------|
| `include_in_openapi: yes` | PR12.1 public mutation contract |
| `include_in_openapi: read_model_appendix` | Document as read model appendix or `x-internal-read-model`; not a public write API |
| `include_in_openapi: internal_appendix` | Internal appendix only; not public OpenAPI |
| `include_in_openapi: no` | Exclude from generated spec |
| `include_in_openapi: future` | Deferred until implemented |

---

## 3. App-exposed mutation catalog

| Route | UI action | Adapter | Backend object | Transport | Boundary class | Auth context | Tenant guard | Output parser | Error mapping | Smoke/test coverage | OpenAPI decision |
|-------|-----------|---------|----------------|-----------|----------------|--------------|--------------|---------------|---------------|---------------------|------------------|
| `/masraf` | New expense claim | `createExpenseClaim` | `puls_workflow.create_expense_claim` | RPC | `app_exposed_mutation` | JWT → `auth.uid()` in RPC | `resolveTenantContext` + employee required | Inline cast | `fromRpcError`, PULS_* | PR10.16 smoke; adapter errors test | `include_in_openapi: yes` |
| `/izin` | New leave request | `createLeaveRequest` | `puls_workflow.create_leave_request` | RPC | `app_exposed_mutation` | JWT → RPC | tenant + employee | `parseCreateLeaveRequestResult` | `fromRpcError`, PULS_* | PR10.16, PR11.4 smoke; `requests.test.ts` | `include_in_openapi: yes` |
| `/masraf`, `/izin` | Approve/reject | `decideApprovalRequest` | `puls_workflow.decide_approval_request` | RPC | `app_exposed_mutation` | JWT → RPC | tenant + employee | Inline cast | `fromRpcError`, approval.* | **Gap:** `pg_proc` only in PR11.4 | `include_in_openapi: yes` |
| `/masraf-kategorileri` | Deactivate category | `deactivateExpenseCategory` | `puls_workflow.deactivate_expense_category` | RPC | `app_exposed_mutation` | JWT → RPC | tenant | `parseExpenseCategoryLifecycleRpcResult` | `mapExpenseCategoryLifecycleError` | PR10 lifecycle smokes | `include_in_openapi: yes` |
| `/masraf-kategorileri` | Restore category | `restoreExpenseCategory` | `puls_workflow.restore_expense_category` | RPC | `app_exposed_mutation` | JWT → RPC | tenant | lifecycle parser | lifecycle mapper | PR10 lifecycle smokes | `include_in_openapi: yes` |
| `/masraf-kategorileri` | Create category | `createExpenseCategory` | `puls_workflow.expense_categories` INSERT | table | `app_exposed_mutation` | JWT + RLS | `.eq('tenant_id', …)` | — | `mapExpenseCategoryMutationError` | PR10 guardrails smoke | `include_in_openapi: yes` |
| `/masraf-kategorileri` | Update category | `updateExpenseCategory` | `puls_workflow.expense_categories` UPDATE | table | `app_exposed_mutation` | JWT + RLS | tenant + id | — | mutation mapper | PR10 guardrails smoke | `include_in_openapi: yes` |
| `/izin-tanimlari` | Deactivate leave type | `deactivateLeaveType` | `puls_workflow.deactivate_leave_type` | RPC | `app_exposed_mutation` | JWT → RPC | tenant | `parseLeaveTypeLifecycleRpcResult` | `mapLeaveTypeLifecycleError` | PR10 lifecycle smokes | `include_in_openapi: yes` |
| `/izin-tanimlari` | Restore leave type | `restoreLeaveType` | `puls_workflow.restore_leave_type` | RPC | `app_exposed_mutation` | JWT → RPC | tenant | lifecycle parser | lifecycle mapper | PR10 lifecycle smokes | `include_in_openapi: yes` |
| `/izin-tanimlari` | Create leave type | `createLeaveType` | `puls_workflow.leave_types` INSERT | table | `app_exposed_mutation` | JWT + RLS | tenant | — | `mapLeaveTypeMutationError` | PR11.3 parity smoke | `include_in_openapi: yes` |
| `/izin-tanimlari` | Update leave type | `updateLeaveType` | `puls_workflow.leave_types` UPDATE | table | `app_exposed_mutation` | JWT + RLS | tenant + id | — | mutation mapper | PR11.3 parity smoke | `include_in_openapi: yes` |
| `/departmanlar` | Create department | `createDepartment` | `puls_core.departments` INSERT | table | `app_exposed_mutation` | JWT + RLS | tenant | — | `mapDepartmentMutationError` | PR11.2 org CRUD smoke | `include_in_openapi: yes` |
| `/departmanlar` | Update department | `updateDepartment` | `puls_core.departments` UPDATE | table | `app_exposed_mutation` | JWT + RLS | tenant; source guard on ERP rows | — | department mapper | PR11.2 smoke | `include_in_openapi: yes` |
| `/pozisyonlar` | Create position | `createPosition` | `puls_core.positions` INSERT | table | `app_exposed_mutation` | JWT + RLS | tenant | — | `mapPositionMutationError` | PR11.2 org CRUD smoke | `include_in_openapi: yes` |
| `/pozisyonlar` | Update position | `updatePosition` | `puls_core.positions` UPDATE | table | `app_exposed_mutation` | JWT + RLS | tenant; source guard | — | position mapper | PR11.2 smoke | `include_in_openapi: yes` |
| `/performans` | Create cycle | `createPerformanceCycle` | `puls_performance.performance_cycles` INSERT | table | `app_exposed_mutation` | JWT + RLS | tenant | `parsePerformanceCycleMutationResult` | result-object errors | PR11.5 HR smoke (direct SQL) | `include_in_openapi: yes` |
| `/performans` | Update cycle status | `updatePerformanceCycle` | `puls_performance.performance_cycles` UPDATE | table | `app_exposed_mutation` | JWT + RLS | tenant + id | cycle parser | adapter errors | PR11.5 smoke | `include_in_openapi: yes` |

**Mutation contract groups (12):** 7 RPC (`create_expense_claim`, `create_leave_request`, `decide_approval_request`, `deactivate_expense_category`, `restore_expense_category`, `deactivate_leave_type`, `restore_leave_type`) + 5 table groups (`expense_categories`, `leave_types`, `departments`, `positions`, `performance_cycles`).

---

## 4. RPC contract details

### `puls_workflow.create_expense_claim`

| Field | Detail |
|-------|--------|
| App adapter | `createExpenseClaim` (`src/lib/data/expense/claims.ts`) |
| Route | `/masraf` |
| Signature | `(p_category_id uuid, p_title text, p_amount numeric, p_currency text, p_vat_rate numeric, p_vat_included boolean, p_expense_date date, p_description text)` |
| Named params | `p_category_id`, `p_title`, `p_amount`, `p_currency`, `p_vat_rate`, `p_vat_included`, `p_expense_date`, `p_description` |
| Return shape | `{ expenseClaimId, approvalRequestId, policyStatus, status, title }` |
| Parser | Inline cast (no dedicated parser export) |
| Auth/RLS | `GRANT EXECUTE TO authenticated`; SECURITY DEFINER; uses `auth.uid()` / tenant context inside RPC |
| PULS_* errors | Policy/validation codes via `fromRpcError` → `errors.ts` operation map |
| Smoke/test | `10_request_creation_hardening_smoke.sql`; `errors.test.ts` |
| OpenAPI | `include_in_openapi: yes` |

### `puls_workflow.create_leave_request`

| Field | Detail |
|-------|--------|
| App adapter | `createLeaveRequest` (`src/lib/data/leave/requests.ts`) |
| Route | `/izin` |
| Signature | `(p_leave_type_id uuid, p_start_date date, p_end_date date, p_half_day boolean, p_delegate_employee_id uuid, p_description text)` |
| Named params | As above |
| Return shape | `{ leaveRequestId, approvalRequestId, businessDays, status, approverEmployeeId, approverName }` |
| Parser | `parseCreateLeaveRequestResult` (exported) |
| Auth/RLS | `authenticated` grant; tenant + employee guards in RPC |
| PULS_* errors | Mapped via `fromRpcError`; invalid shape → `invalid_rpc_result` |
| Smoke/test | PR10.16, PR11.4, lifecycle consumption smokes; `requests.test.ts` |
| OpenAPI | `include_in_openapi: yes` |

### `puls_workflow.decide_approval_request`

| Field | Detail |
|-------|--------|
| App adapter | `decideApprovalRequest` (`src/lib/data/workflow/approvals.ts`) |
| Routes | `/masraf`, `/izin` |
| Signature | `(p_approval_request_id uuid, p_decision text, p_note text)` |
| Named params | `p_approval_request_id`, `p_decision` (`approved`/`rejected`), `p_note` (optional; routes often omit) |
| Return shape | `{ module, parentId, status, approvalRequestId, final, nextApprovalRequestId, currentStepOrder }` |
| Parser | Inline cast |
| Auth/RLS | Approver must match policy chain; `authenticated` only |
| PULS_* errors | `approval.error.*` via central map |
| Smoke/test | **Gap:** PR11.4 checks `pg_proc` existence only — no behavioral decide smoke |
| OpenAPI | `include_in_openapi: yes` — high priority follow-up for contract smoke |

### `puls_workflow.deactivate_expense_category`

| Field | Detail |
|-------|--------|
| App adapter | `deactivateExpenseCategory` |
| Route | `/masraf-kategorileri` |
| Params | `p_category_id`, `p_reason` (optional, max 500) |
| Return | `{ status, category_id, has_history?, event_id }` via `parseExpenseCategoryLifecycleRpcResult` |
| PULS_* | `PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS`, `NOT_FOUND`, `FORBIDDEN`, `LIFECYCLE_REASON_TOO_LONG` |
| Smoke | `10_expense_category_lifecycle_smoke.sql`, audit, consumption |
| OpenAPI | `include_in_openapi: yes` |

### `puls_workflow.restore_expense_category`

| App adapter | `restoreExpenseCategory` | Route | `/masraf-kategorileri` |
| Params | `p_category_id` | Return | lifecycle RPC result |
| PULS_* / 23505 | Duplicate accounting code on restore | Smoke | PR10 lifecycle smokes |
| OpenAPI | `include_in_openapi: yes` |

### `puls_workflow.deactivate_leave_type`

| App adapter | `deactivateLeaveType` | Route | `/izin-tanimlari` |
| Params | `p_leave_type_id`, `p_reason` | Parser | `parseLeaveTypeLifecycleRpcResult` |
| PULS_* | `PULS_LEAVE_TYPE_IN_USE_*`, `NOT_FOUND`, `FORBIDDEN`, `LIFECYCLE_REASON_TOO_LONG` |
| Smoke | PR10 leave type lifecycle smokes | OpenAPI | `include_in_openapi: yes` |

### `puls_workflow.restore_leave_type`

| App adapter | `restoreLeaveType` | Route | `/izin-tanimlari` |
| Params | `p_leave_type_id` | OpenAPI | `include_in_openapi: yes` |

---

## 5. Direct table-write contract details

### `puls_workflow.expense_categories`

| Field | Detail |
|-------|--------|
| Create adapter | `createExpenseCategory` |
| Update adapter | `updateExpenseCategory` |
| Route | `/masraf-kategorileri` |
| Writable fields | `name`, `code`, `monthly_limit`, `receipt_required_over`, `erp_account_code`, `is_active` (create default true) |
| Forbidden fields | `tenant_id` set by adapter only; no direct lifecycle flags |
| Tenant guard | `resolveTenantContext` + `.eq('tenant_id', ctx.tenantId)` on update |
| RLS/trigger | Category guardrails migration; inactive category blocks new claims |
| Duplicate behavior | `23505` on `(tenant_id, code)` or active accounting code → `mapExpenseCategoryMutationError` |
| Smoke | `10_expense_category_guardrails_smoke.sql` |
| OpenAPI | `include_in_openapi: yes` |

### `puls_workflow.leave_types`

| Create/update | `createLeaveType`, `updateLeaveType` | Route | `/izin-tanimlari` |
| Writable | `name`, `code`, `default_entitlement_days`, `requires_document`, `carry_over_allowed`, `max_carry_over_days`, `approval_policy_id` |
| Tenant guard | Same pattern as expense categories |
| Smoke | PR11.3 leave setup parity | OpenAPI | `include_in_openapi: yes` |

### `puls_core.departments`

| Create/update | `createDepartment`, `updateDepartment` | Route | `/departmanlar` |
| Writable | `name`, `code`, `is_active` (create) |
| Source guard | ERP/import rows with `external_source` read-only unless import apply context |
| Smoke | PR11.2 org CRUD smoke | OpenAPI | `include_in_openapi: yes` |

### `puls_core.positions`

| Create/update | `createPosition`, `updatePosition` | Route | `/pozisyonlar` |
| Writable | `name`, `code`, `department_id`, `norm_headcount`, `is_active` (create) |
| Source guard | Same as departments |
| Smoke | PR11.2 org CRUD smoke | OpenAPI | `include_in_openapi: yes` |

### `puls_performance.performance_cycles`

| Create/update | `createPerformanceCycle`, `updatePerformanceCycle` | Route | `/performans` |
| Writable | `name`, `starts_at`, `ends_at`, `status` |
| Error pattern | Result-object `{ data, error }` unlike throw-based mutations |
| Smoke | PR11.5 direct SQL insert/update — **no adapter-named contract smoke** |
| OpenAPI | `include_in_openapi: yes` |

---

## 6. App read-model inventory

Read models are app-wide boundary surfaces but **not** public mutation APIs. Default OpenAPI posture: `include_in_openapi: read_model_appendix`.

| Route | Adapter(s) | Tables/views/RPCs read | Demo/WithMeta status | Mutation? | Boundary class | OpenAPI decision |
|-------|------------|------------------------|----------------------|-----------|----------------|------------------|
| `/dashboard` | `fetchDashboardOverviewWithMeta` | `puls_calc.dashboard_overview`, `leave_overview`, `expense_overview`; `puls_integration.erp_*` | WithMeta + pill | No | `app_read_model` | `read_model_appendix` |
| `/profil` | `fetchProfileOverviewWithMeta` | `puls_core.employees`, `puls_calc.*` overviews, activity joins | WithMeta + pill | No | `app_read_model` | `read_model_appendix` |
| `/calisanlar` | `fetchEmployeesOverview`, `fetchEmployeeAssignmentReadiness` (plain) | `puls_core.employees`, assignments, reporting lines | Plain; `*WithMeta` exists unused | No | `app_read_model` | `read_model_appendix` |
| `/sirket-kurulum` | `fetchCompanySetupOverviewWithMeta`, `fetchSetupReadinessDashboard` | `puls_core.tenants`, `puls_calc.setup_readiness_summary`; composite orchestrator | Mixed; company pill only | No | `app_read_model` | `read_model_appendix` |
| `/departmanlar` | `fetchDepartmentsOverviewWithMeta` | `puls_calc.organization_overview`, `puls_core.departments` | WithMeta + DemoSourcePill | Yes (separate §3) | `app_read_model` | `read_model_appendix` |
| `/pozisyonlar` | `fetchPositionsOverviewWithMeta`, `fetchDepartmentsOverviewWithMeta` | org overview, positions, departments | WithMeta | Yes | `app_read_model` | `read_model_appendix` |
| `/izin` | `fetchLeaveOverviewWithMeta`, `fetchRequestCreationReadiness` | `puls_calc.leave_overview`, workflow tables | Mixed | Yes | `app_read_model` | `read_model_appendix` |
| `/izin-tanimlari` | `fetchLeaveTypesOverviewWithMeta`, policies plain | `leave_types`, approval policies/steps | Mixed | Yes | `app_read_model` | `read_model_appendix` |
| `/masraf` | `fetchExpenseOverviewWithMeta`, readiness plain | `puls_calc.expense_overview`, workflow tables | Mixed | Yes | `app_read_model` | `read_model_appendix` |
| `/masraf-kategorileri` | categories + cost-center WithMeta | `expense_categories`, cost centers, identity maps | WithMeta | Yes | `app_read_model` | `read_model_appendix` |
| `/performans` | overview + cycles WithMeta, templates plain | `puls_performance.*`, `puls_calc.dashboard_overview` | Mixed | Yes | `app_read_model` | `read_model_appendix` |
| `/kariyer` | `fetchCareerOverviewWithMeta` | employees, career profiles, training needs | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/egitim` | `fetchTrainingOverviewWithMeta` | training needs | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/is-degerleme` | `fetchJobEvaluationOverviewWithMeta` | empty scaffold (no real DB on real path) | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/sozlesmeler` | `fetchContractsOverviewWithMeta` | `puls_workflow.contracts`, dashboard overview | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/erp` | `fetchErpOverviewWithMeta` | `puls_integration.erp_*`, setup readiness | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/ayarlar` | `fetchSettingsOverviewWithMeta` | static sections (no DB reads in real mode) | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/ai-koc` | `fetchAiCoachOverviewWithMeta` | static placeholder payload | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/performans-parametreleri` | `fetchPerformanceParametersOverviewWithMeta` | competency templates, KPI weights, score bands | WithMeta | No | `app_read_model` | `read_model_appendix` |
| `/menu` | `fetchMenuOverview` only | `puls_calc.menu_overview` | **Exception:** no WithMeta, no demo pill | No | `app_read_model` | `read_model_appendix` (shell) |

---

## 7. Internal backend-only inventory

| Function/surface | Schema | Used by | App route? | Boundary class | OpenAPI decision | Notes |
|------------------|--------|---------|------------|----------------|------------------|-------|
| `puls_integration.apply_import_batch` | `puls_integration` | Import pipeline, migrations | **No** adapter | `internal_backend_only` | `internal_appendix` | DB may grant `authenticated`; app never calls |
| `puls_integration.validate_import_batch` | `puls_integration` | Import pre-check | No | `internal_backend_only` | `internal_appendix` | Smoke: `09_import_apply_smoke.sql` |
| `puls_integration.preview_import_diff` | `puls_integration` | Import preview | No | `internal_backend_only` | `internal_appendix` | Smoke: `09_import_apply_smoke.sql` |
| `puls_workflow.resolve_approver` | `puls_workflow` | Policy engine inside create/decide RPCs | No direct call | `internal_backend_only` | `internal_appendix` | REVOKED from `authenticated` |
| `puls_workflow.resolve_policy_step_approver` | `puls_workflow` | Resolver v3 chain | No | `internal_backend_only` | `internal_appendix` | Service-role smokes only |
| Import helpers (`_import_*`) | `puls_integration` | Batch apply | No | `internal_backend_only` | `internal_appendix` | `service_role` only |
| Org guardrail triggers | `puls_core` | Department/position UPDATE | No | `internal_backend_only` | `internal_appendix` | Blocks ERP source overwrite |
| Lifecycle guard triggers | `puls_workflow` | Category/leave type consumption | No | `internal_backend_only` | `internal_appendix` | PR10 guard migrations |

---

## 8. Not app-exposed / future API inventory

| Surface | Evidence | Boundary class | OpenAPI decision |
|---------|----------|----------------|------------------|
| ERP sync/write | `src/lib/data/setup/erp.ts` read-only; no `puls_integration` writes in `src/` | `not_app_exposed` | `include_in_openapi: no` |
| Edge functions | **Zero** `supabase.functions.invoke` in `src/` — no app edge-function invoke path | `not_app_exposed` | `include_in_openapi: no` |
| Employee CRUD/editor | `/calisanlar` read-only; no create/update employee adapter | `future_candidate` | `include_in_openapi: future` |
| Assignment editor | Readiness banners only | `future_candidate` | `future` |
| Manager hierarchy editor | Not implemented | `future_candidate` | `future` |
| Policy step editor | Policies read-only in UI | `future_candidate` | `future` |
| Contract upload/storage/e-sign | Contracts read-only | `future_candidate` | `future` |
| Profile edit | Disabled UI on `/profil` | `future_candidate` | `future` |
| Password/security settings | Disabled on `/ayarlar` | `future_candidate` | `future` |
| Notification preferences | Settings sections read-only | `future_candidate` | `future` |
| AI coach execution API | Static placeholder on `/ai-koc` | `future_candidate` | `future` |
| External public API | No public REST layer | `not_app_exposed` | `no` |

---

## 9. Auth/RLS/security model

| Mechanism | Role |
|-----------|------|
| `auth.uid()` | Postgres auth identity inside SECURITY DEFINER RPCs |
| `request.jwt.claim.sub` | JWT subject in smoke scripts; mirrors Supabase session user |
| `puls_core.current_employee_id()` | Tenant-scoped employee context helper |
| `puls_core.current_tenant_id()` | Tenant scope helper |
| `puls_core.is_admin()` | Admin/setup route guard assumptions |
| Setup/admin routes | `SetupRouteGuard` + persona checks on org/setup screens |
| Direct writes | Adapters use `resolveTenantContext(userId)` then `.eq('tenant_id', ctx.tenantId)` |
| Source ownership | Departments/positions with `external_source` blocked on UPDATE unless import apply context |
| Demo mode | `VITE_PULS_DEMO_MODE` affects read fallback only — **not an auth bypass** |
| Service-role smoke caveat | Many smokes run as `service_role`; behavioral confidence for JWT app path requires separate JWT-scoped smokes (PR11.6+ pattern) |

---

## 10. Error contract inventory

| Layer | Mechanism |
|-------|-----------|
| PULS_* RPC/trigger errors | Parsed via `parseRpcErrorCode`; mapped in adapter or `errors.ts` |
| PostgreSQL `23505` | Unique violations → domain mappers (duplicate code, accounting code) |
| `invalid_rpc_result` | Thrown when RPC return shape does not match parser expectations |
| `fromRpcError` | RPC errors → `DataAdapterError` with optional `i18nKey` |
| `fromSupabaseError` | PostgREST errors on direct table writes |
| Domain mappers | `mapDepartmentMutationError`, `mapPositionMutationError`, expense/leave lifecycle and mutation mappers |
| Performance cycles | Result-object pattern with string `error` field (no dedicated i18n mapper) |
| i18n posture | Frontend uses `toastAdapterError` / `t(error.i18nKey)` when present; fallback keys per domain |

---

## 11. Smoke and test coverage matrix

| Mutation contract | Smoke | Adapter unit test | Gap |
|-------------------|-------|-------------------|-----|
| `create_expense_claim` | PR10.16, lifecycle consumption | `errors.test.ts` | — |
| `create_leave_request` | PR10.16, PR11.4, lifecycle | `requests.test.ts` | — |
| `decide_approval_request` | PR11.4 `pg_proc` only | indirect | **High:** behavioral decide smoke missing |
| Expense category CRUD/lifecycle | PR10 guardrails + lifecycle smokes | `expense-categories.test.ts` | — |
| Leave type CRUD/lifecycle | PR10 + PR11.3 smokes | `leave-types.test.ts` | — |
| Org dept/position CRUD | PR11.2 smoke (direct SQL) | `organization.test.ts` | Adapter-named smoke optional |
| Performance cycles | PR11.5 direct SQL | `cycles.test.ts` | **Medium:** no dedicated contract smoke |
| Import batch (internal) | `09_import_apply_smoke.sql` | — | Not app-exposed |
| Resolver helpers (internal) | `09_resolver_v3_smoke.sql`, policy smokes | — | Service-role only |

**Read-model smokes (PR11):** dashboard, profile, contracts, HR growth, employees, org setup, leave setup/consumption — cross-ref `11_*_smoke.sql` files.

---

## 12. OpenAPI inclusion map

| Candidate | Boundary class | Include in PR12.1? | OpenAPI section | Priority | Notes |
|-----------|----------------|-------------------|-----------------|----------|-------|
| Workflow RPCs (7) | `app_exposed_mutation` | yes | `/mutations/workflow` | P0 | Include decide with coverage gap note |
| Table writes (5 groups) | `app_exposed_mutation` | yes | `/mutations/setup` | P1 | Separate INSERT vs UPDATE schemas |
| Read models (20 routes) | `app_read_model` | read_model_appendix | `x-internal-read-model` | P2 | Not public write endpoints |
| Import batch RPCs | `internal_backend_only` | internal_appendix | `x-internal-backend` | P3 | Not public |
| Resolver helpers | `internal_backend_only` | internal_appendix | `x-internal-backend` | P3 | |
| ERP / edge functions | `not_app_exposed` | no | — | — | Zero `supabase.functions.invoke` |
| Profile/security/AI writes | `future_candidate` | future | — | P4 | |

---

## 13. PR12 follow-up map

| PR | Scope |
|----|-------|
| PR12.1 | Generate/author OpenAPI draft from §12 inclusion map |
| PR12.2 | Contract tests for high-priority RPC result parsers |
| PR12.3 | Decide approval smoke hardening |
| PR12.4 | Admin setup API docs/details |
| PR12.5 | Internal backend/import API appendix if exposed later |

---

## 14. Verification notes

```bash
./scripts/verify-12-app-api-boundary-inventory.sh HEAD
node scripts/check-sensitive-grep.mjs
pnpm check-i18n && pnpm test && pnpm build
```

- **Docs-only guard:** PR12.0 must not change `src/**`, migrations, smoke SQL, or generate OpenAPI artifacts.
- **No SQL smoke / db push / db lint** expected for this PR.
- **Reference:** PR11.0 sidebar inventory for route history; PR11.9 demo fallback guard for read-model source honesty.
