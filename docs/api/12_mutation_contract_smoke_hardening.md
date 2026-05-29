# PR12.3 — Mutation Contract Smoke Hardening

PR12.3 closes or narrows PR12.2 partial-coverage flags for three OpenAPI mutation operations using focused, rollback-only SQL contract smokes. No app code, migrations, or public HTTP changes.

## Why PR12.3 exists

PR12.1 authored contract-path OpenAPI; PR12.2 added machine validation. Two mutation groups still had honest `x-puls-coverage: partial` metadata:

| Surface | Before PR12.3 | PR12.3 outcome |
|---------|---------------|----------------|
| `decideApprovalRequest` | PR11.4 `pg_proc` only | JWT + error-path smoke; success path conditional |
| `createPerformanceCycle` | PR11.5 generic HR smoke | Contract-branded DB insert smoke |
| `updatePerformanceCycle` | PR11.5 generic HR smoke | Contract-branded DB update + tenant guard smoke |

References: [`12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md), [`openapi.yaml`](./openapi.yaml), [`openapi-validation.md`](./openapi-validation.md).

## Coverage semantics

**`contract_smoke` means a behavioral success path is claimed in smoke**, not merely that a smoke file exists.

| OpenAPI value | Meaning |
|---------------|---------|
| `contract_smoke` | Success path exercised; `x-puls-coverage-doc` points to smoke SQL |
| `partial` | Residual gap; `x-puls-follow-up` names the reason |

`decideApprovalRequest` remains **`partial`** when the smoke emits `SKIP: decide success path — no safe pending approver fixture`. Error paths and JWT mapping are still hardened.

## Smoke files

### [`12_decide_approval_contract_smoke.sql`](../data/12_decide_approval_contract_smoke.sql)

Proves (rollback-only):

- JWT `request.jwt.claim.sub` → `puls_core.current_employee_id()` and `puls_core.current_tenant_id()`
- `PULS_INVALID_DECISION` for invalid decision values
- `PULS_APPROVAL_NOT_FOUND` for random approval UUID
- Non-approver JWT → `PULS_APPROVAL_FORBIDDEN` or `PULS_SELF_APPROVAL` (when pending fixture exists)
- Optional success: discover pending approval **or** `create_leave_request` rollback chain → approver `decide_approval_request`

**Hard ban:** no `INSERT`/`UPDATE` on `puls_workflow.approval_requests` for fixture fabrication. Success path is RPC-only.

### [`12_performance_cycle_contract_smoke.sql`](../data/12_performance_cycle_contract_smoke.sql)

Proves (rollback-only, contract fields `name`, `starts_at`, `ends_at`, `status`):

- Valid insert + update within tenant
- DB enum rejection for invalid `status`
- Wrong-tenant update affects 0 rows

## DB-backed vs adapter-backed guards (performance cycles)

| Rule | Layer | Smoke behavior |
|------|-------|----------------|
| Valid insert/update | DB | Asserted |
| Invalid enum `status` | DB | Asserted |
| Wrong-tenant update | DB | Asserted (0 rows) |
| Blank `name` | Adapter (`validatePerformanceCycleInput`) | NOTICE only |
| `ends_at <= starts_at` | Adapter (unless DB CHECK) | NOTICE only |

`contract_smoke` on performance cycles does **not** imply the database enforces all OpenAPI request validation rules.

## Service-role vs JWT caveat

- **Decide smoke:** `service_role` for discovery; `authenticated` + JWT sub for RPC calls under test
- **Performance smoke:** `service_role` for rollback table writes (matches PR11.5; RLS on authenticated path requires admin JWT in app)

Manual verification: run both SQL files in the Supabase SQL editor after merge. No `supabase db push`.

## Residual coverage

| Operation | Post-PR12.3 posture |
|-----------|---------------------|
| `decideApprovalRequest` | `partial` until success path runs in target environment |
| `createPerformanceCycle` | `contract_smoke` |
| `updatePerformanceCycle` | `contract_smoke` |

## Validation

```bash
./scripts/verify-12-mutation-contract-smoke.sh HEAD
./scripts/verify-12-openapi-draft.sh HEAD
node scripts/validate-openapi-contract.mjs
```
