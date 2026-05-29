# PR11.3 — Leave Setup Parity Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

Leave setup on `/izin-tanimlari` is **production-real** after PR10.11–PR10.13 (guardrails, lifecycle, audit). PR11.3 does not add schema or new business scope. It documents leave-vs-expense setup parity, adds `fetchLeaveTypesOverviewWithMeta` + demo source honesty on the route, and locks the boundary with matrix/smoke/verify/tests.

**Quality bar:** Audit first; close only narrow parity/honesty gaps.

**No migration expected in PR11.3.**

## Leave-vs-expense feature parity

| Capability | Expense setup (`/masraf-kategorileri`) | Leave setup (`/izin-tanimlari`) | PR11.3 status |
|------------|----------------------------------------|----------------------------------|---------------|
| Create/edit setup row | Category CRUD | Leave type CRUD | parity |
| DB guardrails | `validate_expense_category_guardrails` | `validate_leave_type_guardrails` | parity |
| Unique code | `(tenant_id, code)` | `(tenant_id, code)` | parity |
| Lifecycle deactivate/restore | yes | yes, date-aware approved-leave guard | parity / leave-specific stronger |
| Lifecycle audit | event table + reason/timeline | `leave_type_lifecycle_events` + timeline | parity |
| Policy binding preview | `ApprovalPolicyBindingSection` | `ApprovalPolicyBindingSection` + editable policy select | parity (leave richer on edit) |
| Active-only creation picker | expense create uses active categories | leave create uses active types | parity |
| Historical inactive badge | `/masraf` | `/izin` | parity |
| Demo source indicator | not yet (PR11.9 broader) | **added in PR11.3** | honesty gap closed on leave route |
| WithMeta overview read | not yet | **added in PR11.3** | honesty gap closed on leave route |

## Intentional domain differences

| Topic | Expense | Leave | Notes |
|-------|---------|-------|-------|
| Source ownership | ERP/account fields; no imported category source model | No `external_source`; all rows PULS-owned | intentional difference |
| Cost center readiness | CC mapping section on expense setup | not applicable | expense-specific |
| Entitlement / carry-over / document | not applicable | leave-specific fields on form | intentional difference |
| Policy editing in setup | read-only binding on edit | editable policy `<select>` on create/edit | leave ahead by design |

## DB guardrails / lifecycle / audit inventory

| Layer | Artifact | PR11.3 action |
|-------|----------|---------------|
| Guardrails | PR10.11 `puls_workflow_leave_types_validate_guardrails` | document; no migration |
| Lifecycle | PR10.12 `deactivate_leave_type`, `restore_leave_type` | preserve unchanged |
| Audit | PR10.13 `leave_type_lifecycle_events` | preserve unchanged |
| Full re-test | PR10.11–10.13 smoke SQL | not duplicated; parity smoke checks surfaces only |

## Route behavior and demo/source honesty

| Route | Overview adapter | Demo fallback | Source UI (PR11.3) |
|-------|------------------|---------------|---------------------|
| `/izin-tanimlari` | `fetchLeaveTypesOverviewWithMeta` | empty real tenant → demo when demo mode on | header `orgSetupReadiness.source.demo` pill when `source === 'demo'` |

Other consumers (e.g. setup readiness dashboard) keep `fetchLeaveTypesOverview` without WithMeta.

## Consumption boundary

| Route | Scope |
|-------|-------|
| `/izin` | active-only picker + inactive historical badge (PR10.12/10.16) — **no PR11.3 changes** |

## Security / RLS notes

- `leave_types`: tenant-scoped SELECT; admin INSERT/UPDATE; lifecycle via SECURITY DEFINER RPCs
- `leave_type_lifecycle_events`: admin SELECT; writes via lifecycle RPCs only
- Adapters use `resolveTenantContext` + `.eq('tenant_id', …)`
- No hard delete in PR11.3

## Out-of-scope and follow-up map

- Leave request creation, balance logic, policy editor UI
- Resolver/decide/import runtime changes, ERP writes
- New lifecycle/audit schema, hard delete
- Org CRUD, employee assignment editing
- `is_paid` form/mutation (display-only today)
- Demo lifecycle audit fixtures (PR11.9)
- Broader WithMeta rollout for expense setup and other routes (PR11.9)
- Policy editor remains future scope

## Surface matrix

| Surface | Canonical source | Adapter | PR11.3 change |
|---------|------------------|---------|---------------|
| `/izin-tanimlari` list | `puls_workflow.leave_types` | `fetchLeaveTypesOverviewWithMeta` | demo source pill |
| leave type CRUD | `leave_types` | `create/updateLeaveType` | unchanged |
| lifecycle | RPCs + events table | `deactivate/restoreLeaveType` | unchanged |
| policy picker | `approval_policies` | `fetchApprovalPoliciesOverview` | unchanged |
