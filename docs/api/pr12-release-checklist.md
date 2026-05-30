# PR12 Release Checklist (PR12.5)

Release-ready checklist for the PULS API contract pack. PR12 is **docs/tooling-only** — no app code, migrations, or generated HTTP clients.

## Executive summary

PR12 closes with a coherent, validated contract package:

- Boundary inventory (PR12.0) → OpenAPI draft (PR12.1) → machine validation (PR12.2) → contract smokes (PR12.3) → examples + error catalog (PR12.4) → consumer guide + this checklist (PR12.5)

Current transport: **supabase-js**. **Not live public REST.**

## Artifact inventory

| PR | Artifact | Path |
|----|----------|------|
| 12.0 | App API boundary inventory | [`../data/12_app_api_boundary_inventory.md`](../data/12_app_api_boundary_inventory.md) |
| 12.1 | OpenAPI contract draft | [`./openapi.yaml`](./openapi.yaml) |
| 12.2 | Contract allowlist + validator | [`./openapi-contract-allowlist.json`](./openapi-contract-allowlist.json) · [`./openapi-validation.md`](./openapi-validation.md) · [`../../scripts/validate-openapi-contract.mjs`](../../scripts/validate-openapi-contract.mjs) |
| 12.3 | Mutation contract smokes | [`../data/12_decide_approval_contract_smoke.sql`](../data/12_decide_approval_contract_smoke.sql) · [`../data/12_performance_cycle_contract_smoke.sql`](../data/12_performance_cycle_contract_smoke.sql) · [`./12_mutation_contract_smoke_hardening.md`](./12_mutation_contract_smoke_hardening.md) |
| 12.4 | Examples + error catalog | [`./openapi-examples.yaml`](./openapi-examples.yaml) · [`./puls-error-catalog.md`](./puls-error-catalog.md) |
| 12.5 | Consumer guide + release pack | [`./api-contract-consumer-guide.md`](./api-contract-consumer-guide.md) · this file · [`./README.md`](./README.md) |

Verify scripts: [`../../scripts/verify-12-app-api-boundary-inventory.sh`](../../scripts/verify-12-app-api-boundary-inventory.sh) through [`../../scripts/verify-12-api-contract-release-pack.sh`](../../scripts/verify-12-api-contract-release-pack.sh).

## Mutation coverage

| Metric | Status |
|--------|--------|
| App-exposed mutations | **17** operations in allowlist and OpenAPI `paths:` |
| Performance cycles | `contract_smoke` — [`../data/12_performance_cycle_contract_smoke.sql`](../data/12_performance_cycle_contract_smoke.sql) |
| Decide approval | `partial` — success-path residual when no pending approver fixture; JWT + error paths in [`../data/12_decide_approval_contract_smoke.sql`](../data/12_decide_approval_contract_smoke.sql) |
| Other mutations | Documented in OpenAPI + examples; legacy PR10/11 smokes where noted in inventory |

## Read / internal / future appendix status

| Appendix | Count / note |
|----------|--------------|
| `x-puls-read-models` | **20** read-model routes |
| `/menu` | `shellException: true` (shell route, not a data read model) |
| `x-puls-internal-backend-surfaces` | Internal backend only — not under `paths:` |
| `x-puls-not-exposed` | Future / intentionally non-exposed |

Read models are **appendix-only** — not mutation endpoints.

## Validation command map

### PR12.5 branch gate (required)

Run on PR12.5 branch with committed changes (`HEAD`):

```bash
./scripts/verify-12-api-contract-release-pack.sh HEAD
./scripts/verify-12-openapi-draft.sh HEAD
./scripts/verify-12-mutation-contract-smoke.sh HEAD
./scripts/verify-12-contract-examples-errors.sh HEAD
node scripts/validate-openapi-contract.mjs
node scripts/check-sensitive-grep.mjs
pnpm check-i18n && pnpm test && pnpm build
```

### Optional regression sanity

PR12.0 inventory verify is **PR12.0-scoped** (diff guard allows inventory files only). Do **not** run it with `HEAD` on a PR12.5 branch — it will fail on new `docs/api/*` files.

```bash
./scripts/verify-12-app-api-boundary-inventory.sh origin/main
```

Use a clean main ref or worktree when validating inventory unchanged.

## Manual smoke status

After merge, run PR12.3 SQL smokes manually in the Supabase SQL editor:

- [`../data/12_decide_approval_contract_smoke.sql`](../data/12_decide_approval_contract_smoke.sql)
- [`../data/12_performance_cycle_contract_smoke.sql`](../data/12_performance_cycle_contract_smoke.sql)

Expected result: **Success. No rows returned.** (rollback-only scripts)

No `supabase db push` required for PR12 contract pack validation.

## Public HTTP disclaimer

- **No live REST API** is defined or deployed by this contract pack.
- `x-puls-public-http: false` on OpenAPI and examples metadata.
- **No generated clients** (`openapi.json`, `swagger.json`) are part of the contract source of truth.

## Known residual gaps

| Gap | Posture |
|-----|---------|
| Decide success path | `partial` until pending approver fixture exists in target environment |
| Performance response parser | Documented in [`./openapi-validation.md`](./openapi-validation.md); not machine-validated against adapters |
| Public API / auth transport | **Not decided** — PR13 candidate |
| Expense claim RPC shape | No `invalid_rpc_result` parser (leave has one) — see [`./puls-error-catalog.md`](./puls-error-catalog.md) follow-ups |

## PR13 handoff map

| ID | Theme |
|----|-------|
| PR13.0 | Public transport decision / API productization plan |
| PR13.1 | OpenAPI CI lint / parser dependency decision |
| PR13.2 | Generated docs site (optional) |
| PR13.3 | Response parser parity tests (adapter ↔ OpenAPI) |
| PR13.4 | Auth examples / external integration guide |

## Release signoff checklist

- [ ] All PR12.5 branch verify scripts pass on `HEAD`
- [ ] `node scripts/validate-openapi-contract.mjs` passes
- [ ] `pnpm check-i18n && pnpm test && pnpm build` passes
- [ ] No changes under `src/**`
- [ ] No changes under `supabase/**`
- [ ] No `openapi.json` or `swagger.json` artifacts added
- [ ] No generated HTTP client packages added
- [ ] OpenAPI `paths:` and request schemas unchanged in PR12.5
- [ ] Public HTTP disclaimer present in consumer guide and README
- [ ] 17 mutations / 20 read-model routes documented
- [ ] Optional: `./scripts/verify-12-app-api-boundary-inventory.sh origin/main` on unchanged inventory
