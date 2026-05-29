# PR11.4 — Leave Consumption Hardening Matrix

Reference: [11_sidebar_data_api_inventory.md](./11_sidebar_data_api_inventory.md)

## Executive summary

Leave consumption on `/izin` is **production-real** after PR10.12 (inactive historical readability) and PR10.16 (request creation hardening). PR11.4 does not add schema or change create/decide business logic. It regression-proofs auth mapping, active-only picker vs inactive history boundaries, RPC result contract for `create_leave_request`, and demo source honesty on the consumption route.

**Quality bar:** Auth/readiness/source honesty + RPC result contract hardening on consumption only.

**No migration in PR11.4.**

## Data / RPC dependency table

| Surface | Canonical source | Adapter | RPC / view | PR11.4 change |
|---------|------------------|---------|------------|---------------|
| Overview | `puls_calc.leave_overview`, `puls_workflow.leave_*`, `approval_requests` | `fetchLeaveOverview` / **`fetchLeaveOverviewWithMeta`** | reads only | WithMeta + demo pill |
| Active picker | `puls_workflow.leave_types` `.eq('is_active', true)` | `fetchRealLeaveOverview` | — | preserve |
| Historical labels | `leave_types` lookup by id (no active filter) | `mapLeaveTypeFromLookup` | — | preserve |
| Create | `puls_workflow.create_leave_request` | `createLeaveRequest` + **`parseCreateLeaveRequestResult`** | `(uuid, date, date, boolean, uuid, text)` | parser hardening |
| Readiness | setup + policy binding | `fetchRequestCreationReadiness('leave')` | — | preserve (PR10.16) |
| Decide | `puls_workflow.decide_approval_request` | `decideApprovalRequest` | `(uuid, text, text)` per migration grant | smoke surface only; **no adapter change** |

## Create block / warn rules (PR10.16 preserved)

| Rule | Layer | PR11.4 |
|------|-------|--------|
| No active leave types | readiness block | unchanged |
| Missing assignment / policy | readiness block/warn | unchanged |
| Inactive leave type on create | RPC `PULS_INVALID_LEAVE_TYPE` | unchanged; smoke asserts |
| Insufficient balance | RPC warn-only in UI | unchanged |
| Cross-year / half-day invalid | client + RPC | unchanged |
| Document-required types | UI disabled + RPC | unchanged |

## Active-only picker vs inactive historical readability

| Concern | Picker (create form) | History / approvals |
|---------|----------------------|---------------------|
| Query filter | `.eq('is_active', true)` on `leave_types` | `.in('id', leaveTypeIds)` — **no** active filter |
| UI | only active types selectable | `leaveSetup.typeLifecycle.inactiveTypeBadge` when `typeIsActive === false` |
| PR11.4 | preserve | preserve; positive verify needles |

## Auth / RLS notes

- RPCs use `auth.uid()` → `puls_core.current_employee_id()` for requester context.
- PR11.4 smoke sets `request.jwt.claim.role = authenticated` and `request.jwt.claim.sub` to a linked employee's `user_id`, then asserts `puls_core.current_employee_id()` matches.
- Do **not** rely on `service_role` alone for create RPC smoke calls.

## Demo / source behavior

| Route | Adapter | Demo fallback | Source UI (PR11.4) |
|-------|---------|---------------|----------------------|
| `/izin` | `fetchLeaveOverviewWithMeta` | empty real tenant → demo when demo mode on | header `orgSetupReadiness.source.demo` pill when `source === 'demo'` |

Other consumers (dashboard, readiness) keep `fetchLeaveOverview` without WithMeta.

Demo mapping uses the same helper as the existing `fetchLeaveOverview` demo branch (`mapDemoLeaveOverviewToOverview`).

## Approval decision boundary

- Inventory marks decide smoke **Partial**; PR11.4 documents and smoke-checks RPC **existence** only (`pg_proc` + `proname = 'decide_approval_request'`).
- Migration signature: `decide_approval_request(uuid, text, text)` — adapter uses named params; no decide mutation in PR11.4 smoke.
- **`decideApprovalRequest` adapter wiring unchanged.**

## Setup boundary (explicit)

| Route | PR11.4 |
|-------|--------|
| `/izin-tanimlari` | **no changes** (PR11.3 completed) |
| `leave-types.ts` setup CRUD | **no changes** |

Create remains RPC-authoritative; no new RPCs.

## Out-of-scope and follow-ups

- Policy editor UI, document upload UI, calendar tab
- Balance engine changes, resolver/decide/import **logic**
- ERP writes, delegate/approver real wiring
- Broader demo guard rollout (PR11.9)
- Optional decide mutation smoke (future)

## Surface matrix (minimum)

| Surface | Source | Adapter | Demo | PR11.4 |
|---------|--------|---------|------|--------|
| Overview | calc + workflow reads | `fetchLeaveOverviewWithMeta` | fallback | WithMeta + pill |
| Picker | active `leave_types` | overview real fetch | demo types | preserve |
| Historical labels | id lookup | `mapLeaveTypeFromLookup` | demo data | preserve |
| Create | `create_leave_request` | `parseCreateLeaveRequestResult` | — | parser |
| Readiness | setup reads | `fetchRequestCreationReadiness` | — | preserve |
| Decide | `decide_approval_request` | `decideApprovalRequest` | — | smoke only |
| Demo honesty | `resolveAdapterDataWithMeta` | route pill | demo mode | added |
