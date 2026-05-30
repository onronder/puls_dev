# PULS Error Catalog (PR12.4)

Reference catalog for mutation error codes surfaced by app adapters. This documents **codes**, not localized user strings. Current transport is **supabase-js** (Postgres RPC + table writes), **not public HTTP REST**.

Related: [`openapi.yaml`](./openapi.yaml) · [`openapi-examples.yaml`](./openapi-examples.yaml) · [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) (`knownErrorCodes`)

## Executive summary

- Mutations return errors as `DataAdapterError` (adapter/RPC) or field-level validation maps on setup routes.
- **`PULS_*` codes** originate from Postgres `RAISE EXCEPTION` messages and are parsed via `parseRpcErrorCode` in `src/lib/data/errors.ts`.
- **Adapter-only codes** (`invalid_input`, `no_tenant`, `invalid_rpc_result`, …) are raised in TypeScript before or after transport calls.
- **Postgres `23505`** (unique violation) is mapped in domain mappers for duplicate slug/code conflicts.
- OpenAPI examples and this catalog use machine codes only; **i18n copy is route/domain owned** via `i18nKey` on RPC paths.

## Error taxonomy

| Kind | Pattern | Typical source | Example |
|------|---------|----------------|---------|
| PULS domain | `PULS_*` | RPC/trigger/RLS guard message | `PULS_INVALID_DECISION` |
| Adapter validation | lowercase snake | TypeScript adapter pre-check | `invalid_input`, `no_tenant` |
| RPC shape | `invalid_rpc_result` | Parser rejects RPC JSON shape | leave create |
| Postgres | `23505` | Unique constraint | duplicate category code |
| Generic adapter | `adapter_error` | Fallback wrapper | read paths (not in mutation examples) |

## Common adapter errors

| Code | Where | Mapper | Notes |
|------|-------|--------|-------|
| `PULS_AUTH_REQUIRED` | create leave/expense/decide pre-check + RPC | `fromRpcError` / adapter throw | Operation-aware i18n |
| `invalid_rpc_result` | leave create parser | `parseCreateLeaveRequestResult` | Expense create lacks dedicated parser |
| `23505` | setup table writes | `map*MutationError` | Duplicate code / accounting code |

`PULS_TENANT_REQUIRED` is not a dedicated app adapter code today; tenant gaps surface as `no_tenant` (performance) or auth failures on workflow RPCs.

## Request / approval errors (workflow RPC)

### Leave create (`createLeaveRequest`)

| Code | i18n key (default) |
|------|-------------------|
| `PULS_INVALID_DATES` | `leave.error.invalidDates` |
| `PULS_CROSS_YEAR_LEAVE` | `leave.error.crossYear` |
| `PULS_HALF_DAY_INVALID` | `leave.error.halfDayInvalid` |
| `PULS_DOCUMENT_REQUIRED` | `leave.error.documentRequired` |
| `PULS_INSUFFICIENT_BALANCE` | `leave.error.insufficientBalance` |
| `PULS_INVALID_LEAVE_TYPE` | `leave.error.invalidLeaveType` / readiness variant on create |
| `PULS_INVALID_DELEGATE` | `leave.error.invalidDelegate` |
| `PULS_NO_APPROVER` | `requestCreationReadiness.common.policyNotReady` on create |
| `PULS_POLICY_*` / `PULS_APPROVAL_CHAIN_INVALID` | Shared policy map in `errors.ts` |
| `invalid_rpc_result` | `leave.error.submitFailed` |

### Expense create (`createExpenseClaim`)

| Code | i18n key |
|------|----------|
| `PULS_INVALID_EXPENSE_CATEGORY` | `expense.error.invalidCategory` |
| `PULS_INVALID_AMOUNT` | `expense.error.invalidAmount` |
| `PULS_INVALID_CURRENCY` | `expense.error.invalidCurrency` |
| `PULS_FUTURE_EXPENSE_DATE` | `expense.error.futureDate` |
| `PULS_NO_APPROVER` | readiness variant on create |

### Decide approval (`decideApprovalRequest`)

| Code | i18n key |
|------|----------|
| `PULS_APPROVAL_NOT_FOUND` | `approval.error.notFound` |
| `PULS_APPROVAL_ALREADY_DECIDED` | `approval.error.alreadyDecided` |
| `PULS_APPROVAL_FORBIDDEN` | `approval.error.forbidden` |
| `PULS_SELF_APPROVAL` | `approval.error.selfApproval` |
| `PULS_INVALID_DECISION` | `approval.error.invalidDecision` |
| `PULS_POLICY_STEP_UNRESOLVED` | `approval.error.policyStepUnresolved` |
| `PULS_POLICY_NOT_FOUND` | `approval.error.policyNotFound` |
| `PULS_POLICY_STEP_NOT_FOUND` | `approval.error.policyChainInvalid` |
| `PULS_APPROVAL_CHAIN_INVALID` | `approval.error.policyChainInvalid` |

PR12.3 contract smoke exercises `PULS_INVALID_DECISION`, `PULS_APPROVAL_NOT_FOUND`, forbidden/self-approval paths.

## Setup mutation errors

### Expense categories

**CRUD** — `mapExpenseCategoryMutationError` in `src/lib/data/setup/expense-categories.ts`:

| Code | Field |
|------|-------|
| `PULS_EXPENSE_CATEGORY_NAME_REQUIRED` | name |
| `PULS_EXPENSE_CATEGORY_CODE_REQUIRED` | code |
| `PULS_EXPENSE_CATEGORY_CODE_INVALID` | code |
| `PULS_EXPENSE_CATEGORY_MONTHLY_LIMIT_INVALID` | monthlyLimit |
| `PULS_EXPENSE_CATEGORY_RECEIPT_THRESHOLD_INVALID` | receiptRequiredOver |
| `PULS_EXPENSE_CATEGORY_ACCOUNT_CODE_INVALID` | erpAccountCode |

**Lifecycle** — `mapExpenseCategoryLifecycleError`:

| Code | Meaning |
|------|---------|
| `PULS_EXPENSE_CATEGORY_IN_USE_ACTIVE_CLAIMS` | Deactivate blocked |
| `PULS_EXPENSE_CATEGORY_NOT_FOUND` | Unknown category |
| `PULS_EXPENSE_CATEGORY_FORBIDDEN` | Auth/tenant |
| `PULS_EXPENSE_CATEGORY_LIFECYCLE_REASON_TOO_LONG` | reason > 500 chars |

### Leave types

**CRUD** — `mapLeaveTypeMutationError` in `src/lib/data/setup/leave-types.ts`:

| Code | Field |
|------|-------|
| `PULS_LEAVE_TYPE_NAME_REQUIRED` | name |
| `PULS_LEAVE_TYPE_CODE_REQUIRED` | code |
| `PULS_LEAVE_TYPE_CODE_INVALID` | code |
| `PULS_LEAVE_TYPE_ENTITLEMENT_INVALID` | defaultEntitlementDays |
| `PULS_LEAVE_TYPE_CARRY_OVER_INVALID` | maxCarryOverDays |
| `PULS_LEAVE_TYPE_POLICY_INVALID` | approvalPolicyId |
| `PULS_LEAVE_TYPE_POLICY_MODULE_INVALID` | approvalPolicyId |

**Lifecycle** — `mapLeaveTypeLifecycleError`:

| Code | Meaning |
|------|---------|
| `PULS_LEAVE_TYPE_IN_USE_ACTIVE_REQUESTS` | Deactivate blocked |
| `PULS_LEAVE_TYPE_NOT_FOUND` | Unknown type |
| `PULS_LEAVE_TYPE_FORBIDDEN` | Auth/tenant |
| `PULS_LEAVE_TYPE_LIFECYCLE_REASON_TOO_LONG` | reason > 500 chars |

### Org departments / positions

**Departments** — `mapDepartmentMutationError` in `src/lib/data/core/organization.ts`:

| Code | Notes |
|------|-------|
| `PULS_ORG_DEPARTMENT_NAME_REQUIRED` | |
| `PULS_ORG_DEPARTMENT_CODE_REQUIRED` | |
| `PULS_ORG_DEPARTMENT_CODE_INVALID` | |
| `PULS_ORG_DEPARTMENT_MANAGER_INVALID` | generic field error |
| `PULS_ORG_DEPARTMENT_COST_CENTER_INVALID` | generic field error |
| `PULS_ORG_DEPARTMENT_SOURCE_READ_ONLY` | ERP/import source guard |

**Positions** — `mapPositionMutationError`:

| Code | Notes |
|------|-------|
| `PULS_ORG_POSITION_NAME_REQUIRED` | |
| `PULS_ORG_POSITION_CODE_REQUIRED` | |
| `PULS_ORG_POSITION_CODE_INVALID` | |
| `PULS_ORG_POSITION_DEPARTMENT_INVALID` | |
| `PULS_ORG_POSITION_NORM_INVALID` | |
| `PULS_ORG_POSITION_SOURCE_READ_ONLY` | ERP/import source guard |

## Performance cycle validation errors

Performance mutations (`src/lib/data/performance/cycles.ts`) use **adapter codes only** — no `PULS_*` in src:

| Code | When |
|------|------|
| `invalid_input` | Client-side validation (name, dates) |
| `no_tenant` | Missing tenant context |
| `empty_patch` | Update with no fields |
| `invalid_row` | Row parse failure |

PostgREST errors pass through `fromSupabaseError` without dedicated i18n mapping; UI uses hardcoded Turkish via `toUserMessage()` today.

## Demo / source honesty

| Topic | Posture |
|-------|---------|
| Demo mode | `VITE_PULS_DEMO_MODE` affects read fallback only — **not** an auth bypass for mutations |
| ERP source rows | `PULS_ORG_*_SOURCE_READ_ONLY` on dept/position update |
| Migration-only codes | `PULS_EXPENSE_CATEGORY_VAT_INVALID` exists in DB guardrails but **is not mapped in src** — listed here for honesty, **not** in `knownErrorCodes` or examples |

Non-errors: lifecycle `already_inactive` / `already_active` statuses are success idempotency shapes, not error codes.

## Error mapper inventory

| Function | File | Used by |
|----------|------|---------|
| `fromRpcError` | `src/lib/data/errors.ts` | Workflow RPC mutations |
| `fromSupabaseError` | `src/lib/data/errors.ts` | Table writes, lifecycle RPCs |
| `mapRpcErrorToI18nKey` | `src/lib/data/errors.ts` | Central PULS → i18n |
| `mapExpenseCategoryMutationError` | `setup/expense-categories.ts` | Category CRUD |
| `mapExpenseCategoryLifecycleError` | `setup/expense-categories.ts` | Category deactivate/restore |
| `mapLeaveTypeMutationError` | `setup/leave-types.ts` | Leave type CRUD |
| `mapLeaveTypeLifecycleError` | `setup/leave-types.ts` | Leave type deactivate/restore |
| `mapDepartmentMutationError` | `core/organization.ts` | Department CRUD |
| `mapPositionMutationError` | `core/organization.ts` | Position CRUD |

Setup lifecycle RPCs use `fromSupabaseError` + domain mapper (raw message preserved until mapper re-parses `PULS_*` prefix).

## i18n posture

- **RPC workflow routes** (`/izin`, `/masraf`): toast via `error.i18nKey` when present.
- **Setup routes**: domain mappers return field keys or toast keys; routes apply to form/toast.
- **OpenAPI / examples**: expose codes only; localized strings live in `src/i18n/locales/*.json`.
- **Performance**: weakest integration — adapter returns plain strings; locale keys exist but are not wired through adapter errors.

## Smoke / test coverage matrix

| Surface | Automated coverage |
|---------|-------------------|
| Decide approval errors | PR12.3 `12_decide_approval_contract_smoke.sql` |
| Performance cycles | PR12.3 `12_performance_cycle_contract_smoke.sql` (DB guards; adapter codes documented only) |
| Leave/expense RPC | PR10.16 smokes; `errors.test.ts`, `requests.test.ts` |
| Expense categories | PR10 smokes; `expense-categories.test.ts` |
| Leave types | PR11 parity smoke; `leave-types.test.ts` |
| Org CRUD | PR11.2 smoke; `organization.test.ts` |
| Examples in this PR | All 17 ops in `openapi-examples.yaml`; codes gated by `knownErrorCodes` |

## Follow-ups

- Add `invalid_rpc_result` parser for expense claim RPC shape (parity with leave).
- Align decide auth pre-check i18n with leave/expense (`approval.error.authRequired` vs `forbidden`).
- Wire performance adapter errors through i18n keys already in locales.
- Map `PULS_EXPENSE_CATEGORY_VAT_INVALID` in src if product needs user-facing VAT validation errors.
