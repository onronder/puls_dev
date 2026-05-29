# OpenAPI Contract Validation (PR12.2)

PR12.2 adds contract-grade validation on top of the PR12.1 OpenAPI draft. It does **not** change app behavior, request/response semantics, or live transport.

## Why PR12.2 exists

PR12.1 authored an honest contract-path OpenAPI draft from the PR12.0 boundary inventory. PR12.2 makes semantic drift and accidental overexposure hard to miss through:

- A machine-readable **allowlist** with per-operation backend/transport/requestSchema mapping
- A **Node validator** (`scripts/validate-openapi-contract.mjs`) — no npm YAML dependency
- Integration into [`scripts/verify-12-openapi-draft.sh`](../../scripts/verify-12-openapi-draft.sh)

## What is validated

| Area | Rule |
|------|------|
| Operations (17) | IDs match allowlist; vendor extensions + `security: SupabaseJwt` on every operation |
| **Per-operation map** | Each operation’s `x-puls-backend`, `x-puls-transport`, and request `$ref` match [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) `operations` |
| Restore ops | No `requestBody`; `requestSchema: null` in allowlist |
| Direct table writes | `x-puls-tenant-guard` present |
| Org dept/position writes | `x-puls-source-ownership` present |
| Partial coverage | `x-puls-coverage: partial` on `decideApprovalRequest` only (performance cycles are `contract_smoke` since PR12.3) |
| Paths | No internal-only backend needles under `paths:` |
| Appendices | `x-puls-read-models`, `x-puls-internal-backend-surfaces`, `x-puls-not-exposed` |
| Read models | All 20 PR12.0 routes; `/menu` includes `shellException: true` |
| Request schemas | **Exact** property-set match to allowlist; forbidden adapter-set fields absent |
| Adapter drift | Each mutation adapter: exactly once as `operationId` in OpenAPI; present in inventory |
| Backend drift | Each backend object: in inventory + **at least once** in OpenAPI (shared backends intentional) |
| **PR12.4 examples** | All 17 ops in [`openapi-examples.yaml`](./openapi-examples.yaml); strict two-space op block parsing |
| **PR12.4 request examples** | Example request keys ⊆ `requestSchemaAllowlist`; forbidden fields absent |
| **PR12.4 error codes** | Example `code:` values ∈ `knownErrorCodes` in allowlist |
| **PR12.4 accepted shape** | Setup table CRUD `accepted:` blocks must include `ok: true` |
| **PR12.4 metadata** | OpenAPI `x-puls-examples-doc` + `x-puls-error-catalog` present and files exist |

Run validation:

```bash
node scripts/validate-openapi-contract.mjs
./scripts/verify-12-openapi-draft.sh HEAD
./scripts/verify-12-contract-examples-errors.sh HEAD
```

## What is intentionally not validated

Without a full YAML/OpenAPI parser we do **not** enforce:

- Complete OpenAPI 3.1 schema validity
- `$ref` resolution graph correctness
- Duplicate YAML keys
- Automated response field parity with adapter parsers in `src/lib/data/**`

Response shapes are documented below for human review only.

## Request schema allowlist policy

OpenAPI `*Request` schemas expose **client-writable fields only**. Adapter-set fields (`tenant_id`, `is_active`, timestamps, `external_source`) must never appear as request properties.

The allowlist JSON defines the exact property set per schema. The validator fails if properties are missing or extra.

### PR12.1 schema preservation — `PerformanceCycleMutationRequest.status`

PR12.1’s written prompt emphasized `name`, `startsAt`, and `endsAt`. The **shipped** [`openapi.yaml`](./openapi.yaml) also includes optional `status` (enum `draft` / `active` / `closed`, default `draft`).

**PR12.2 preserves that existing PR12.1 schema.** The validator records `status` as client-writable because the current adapter contract accepts it (`CreateCycleInput.status` in `src/lib/data/performance/cycles.ts`). PR12.2 does not add or remove OpenAPI fields.

## Public HTTP disclaimer

This spec describes **contract paths**, not live public REST endpoints.

- Server: `supabase-js://local`
- Transport: supabase-js (Postgres RPC + table writes)
- Every mutation: `x-puls-public-http: false`

Read models live under `x-puls-read-models`, not under `paths:` as write APIs.

## Drift model vs PR12.0 inventory

Three-way contract:

1. [`12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md) — source of truth for boundaries
2. [`openapi.yaml`](./openapi.yaml) — contract-path draft
3. [`openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) — expected wiring

**Primary drift guard:** the `operations` map validates each operation’s backend, transport, and request schema independently. Shared backends (e.g. `puls_workflow.expense_categories` on create/update) are expected.

**Backend objects:** deduplicated list checked for inventory presence + ≥1 OpenAPI reference (not exactly-once).

## Response parser alignment notes (manual)

| Response schema | Adapter reference |
|-----------------|---------------------|
| `CreateExpenseClaimResponse` | `CreateExpenseClaimResult` — `src/lib/data/expense/claims.ts` |
| `CreateLeaveRequestResponse` | `CreateLeaveRequestResult` — `src/lib/data/leave/requests.ts` |
| `DecideApprovalRequestResponse` | `DecideApprovalRequestResult` — `src/lib/data/workflow/approvals.ts` |
| `ExpenseCategoryLifecycleResponse` | `parseExpenseCategoryLifecycleRpcResult` — `src/lib/data/setup/expense-categories.ts` |
| `LeaveTypeLifecycleResponse` | `parseLeaveTypeLifecycleRpcResult` — `src/lib/data/setup/leave-types.ts` |
| `PerformanceCycleMutationResponse` | `parsePerformanceCycleMutationResult` — `src/lib/data/performance/cycles.ts` (camelCase external contract) |
| `MutationAcceptedResponse` | Void table mutations — adapters return `Promise<void>` |

Not enforced by PR12.2 validator.

## Known gaps

| Operation | Gap |
|-----------|-----|
| `decideApprovalRequest` | `partial` — JWT/error-path contract smoke; success path skipped when no pending approver fixture |
| Read models (20 routes) | Appendix-only — not public mutation paths |

Performance cycle mutations (`createPerformanceCycle`, `updatePerformanceCycle`) moved to `contract_smoke` in PR12.3. See [`12_mutation_contract_smoke_hardening.md`](./12_mutation_contract_smoke_hardening.md).

## PR12.4 handoff

PR12.4 adds illustrative mutation examples and an error catalog:

- [`openapi-examples.yaml`](./openapi-examples.yaml) — request/response/error examples for all 17 operations
- [`puls-error-catalog.md`](./puls-error-catalog.md) — PULS and adapter error codes, mapper inventory, i18n posture
- [`scripts/verify-12-contract-examples-errors.sh`](../../scripts/verify-12-contract-examples-errors.sh)

Example request fields are client-writable only (allowlist-guarded). Error codes in examples must appear in `knownErrorCodes`. Examples are reference material for supabase-js transport, not a live HTTP API.

## PR12.3 handoff

PR12.3 added contract smokes documented in [`12_mutation_contract_smoke_hardening.md`](./12_mutation_contract_smoke_hardening.md). Residual decide success-path coverage depends on environment fixtures.
